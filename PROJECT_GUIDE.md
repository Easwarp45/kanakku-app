# Kanakku App: Project Reference & Development Guide

Welcome to the **Kanakku** codebase. This document is a comprehensive guide detailing the application architecture, database schemas, current implementation status, recent bug fixes, and development blueprints for outstanding features. It is designed to get any AI coding agent or developer up to speed immediately.

---

## 1. Project Overview & Context

*   **App Name**: Kanakku (meaning *Account* or *Calculation* in Tamil/Malayalam)
*   **Purpose**: Shared group expense management and personal finance tracking.
*   **Target Audience**: Indian users, featuring **₹ (INR) currency** and default **UPI** payment options.
*   **Tech Stack**:
    *   **Frontend**: Flutter (Dart)
    *   **State Management**: Flutter Riverpod
    *   **Routing**: GoRouter
    *   **Backend**: Supabase (PostgreSQL with Row Level Security - RLS)
    *   **Local Caching & Offline State**: Hive (`LocalCacheService`)

---

## 2. Database Schema & Key Constraints

Supabase PostgreSQL is the source of truth. Below are the key tables and constraints:

### 2.1. `profiles`
Stores user profile information.
*   **Columns**: `id`, `user_id` (foreign key to auth.users), `display_name`, `phone_number`, `avatar_url`, `language`, `currency` (defaults to `'INR'`), `created_at`, `updated_at`.
*   > [!WARNING]
    > **RLS Policy Restriction**: Currently, the select policy on `profiles` is restricted to the authenticated user (`auth.uid() = user_id`). As a result, when a user queries profiles of other group members, the response returns empty. This causes other members' names to fall back to generic placeholders like `'Member'` or `'Unknown Member'` in the UI.

### 2.2. `groups`
Group metadata.
*   **Columns**: `id`, `name`, `description`, `image_url`, `created_by`, `invite_code` (8-character unique alphanumeric code), `created_at`, `updated_at`.

### 2.3. `group_members`
Links users to groups.
*   **Columns**: `id`, `group_id`, `user_id`, `nickname` (custom alias within group), `is_admin` (boolean), `joined_at`, `created_at`.
*   **Leaving**: Handled by deleting the membership row from this table.

### 2.4. `group_expenses`
Group-level expenses.
*   **Columns**: `id`, `group_id`, `paid_by` (user ID of the payer), `amount`, `description`, `category`, `split_type`, `expense_date`, `created_at`, `updated_at`.
*   > [!IMPORTANT]
    > **Split Type Constraint**: The table has a check constraint `group_expenses_split_type_check` which only permits values `'equal'` and `'custom'`. Using `'unequal'` will trigger a `400 Bad Request` database error. Any unequal splitting behavior must be saved as `'custom'`.

### 2.5. `expense_splits`
Individual breakdowns of group expenses.
*   **Columns**: `id`, `group_expense_id` (cascading delete on expense deletion), `user_id`, `amount`, `created_at`.

### 2.6. `expenses`
Personal (default) user expenses.
*   **Columns**: `id`, `user_id`, `amount`, `category`, `description`, `payment_method` (defaults to `'upi'`), `expense_date`, `receipt_url`, `created_at`, `updated_at`.

---

## 3. Current Implementation Progress

| Feature / Fix | Status | Description |
| :--- | :--- | :--- |
| **Clean Up Unrouted Icons** | **Completed** | Removed a static, non-functional settings icon from `GroupsListScreen`. |
| **Split Type Validation** | **Completed** | Mapped all unequal/custom splits to `'custom'` to satisfy DB constraints. |
| **Edit/Delete Group Expense** | **Completed** | Full CRUD supported, using cascading deletes for splits. |
| **Group Settings (Leave/Delete)** | **Completed** | Admins can delete groups; members can leave groups. |
| **Manual Refresh Option** | **Completed** | Pull-to-refresh and a manual refresh icon in `GroupDetailScreen` to bust cache. |
| **Payer Selection Fallback Fix** | **Completed** | Resolved a bug where selecting another member in the paid by dropdown defaulted to showing "You" because the fallback name resolved to `'You'`. It now correctly displays `'Member'`. |
| **Automatic Expense Replication** | **Pending** | Replicating group expenses paid by the current user into personal expenses. |

---

## 4. Key Files & Architecture

All group-related presentation files are located in `lib/features/groups/presentation/`:

*   `groups_list_screen.dart`: The dashboard displaying all joined/created groups.
*   `group_detail_screen.dart`: Displays group expenses list, member directory, balances, settings (Leave/Delete), and manual refresh.
*   `group_expense_entry_screen.dart`: Dialog/form to add new group expenses with split options.
*   `edit_group_expense_screen.dart`: Dialog/form to edit existing group expenses.
*   `group_service.dart` (`lib/features/groups/data/`): Orchestrates all remote Supabase queries, streams, caching, and local queueing.

---

## 5. Development Blueprints for Pending Features

Here are step-by-step logic blueprints for implementing the remaining requirements.

### 5.1. Blueprint: Automatic Group Expense Replication

**Goal**: When a user adds/edits/deletes a group expense where they are the payer (`paid_by == currentUserId`), replicate that transaction automatically to their personal `expenses` table.

#### A. Add Group Expense Replication
In `group_service.dart` -> `addGroupExpense`:
1.  Check if `actualPaidBy == _userId`.
2.  If true, replicate the expense in the `expenses` table.
3.  Because the `expenses` table has no `group_expense_id` column, **embed a unique marker inside the description** to link them (e.g. `[GroupExpense: <id>] <description>`).
4.  Use `LocalCacheService.queueAction` or direct database client insert to push it to the `expenses` table.

*Example Code Snippet*:
```dart
// After inserting the group expense successfully and obtaining the `expense` map
if (actualPaidBy == _userId) {
  final personalDesc = '[GroupExpense: ${expense['id']}] $description';
  // Insert personal expense
  await _client.from('expenses').insert({
    'user_id': _userId,
    'amount': amount,
    'description': personalDesc,
    'category': category,
    'expense_date': DateTime.now().toIso8601String().split('T')[0],
    'payment_method': 'upi',
  });
}
```

#### B. Update Group Expense Replication
In `group_service.dart` -> `updateGroupExpense`:
1.  If the group expense's payer is the current user:
    *   Find the corresponding personal expense by filtering `description` using `like` / contains `%[GroupExpense: <expenseId>]%`.
    *   Update the personal expense amount, category, and description.
    *   If the payer was changed from the current user to someone else, delete the replicated personal expense.
2.  If the payer was changed *to* the current user, create a new replicated personal expense.

#### C. Delete Group Expense Replication
In `group_service.dart` -> `deleteGroupExpense`:
1.  Query or delete from the `expenses` table where `description` contains `[GroupExpense: <expenseId>]`.

---

## 6. Offline Support & Cache Synchronization

The application implements optimistic offline caching via `LocalCacheService`:
*   **Caching**: Data is saved to Hive boxes (`group_expenses_$groupId`, `group_members_$groupId`, `expenses_$_userId`).
*   **Queueing**: Offline modifications are added to `kanakku_pending_queue_v4.hive` using `queueAction`.
*   **Reconciliation**: The `RealtimeSyncManager` background engine reconciles pending actions when connection is restored. When writing new database queries or mutations, always make sure to invalidate the corresponding local cache keys so the UI updates immediately.
