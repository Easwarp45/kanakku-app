# Kanakku: Shared Group Expense & Personal Finance Tracker

**Kanakku** (meaning *Account* or *Calculation* in Tamil/Malayalam) is a high-performance, offline-first Flutter application designed for shared group expense management and personal finance tracking. Tailored specifically for Indian users, the application features native **₹ (INR) currency support**, **multi-currency conversion**, and default **UPI** payment workflow integration.

The application leverages a dark glassmorphic UI design, combining visually stunning aesthetics with a robust offline sync architecture powered by **Riverpod**, **Hive**, and **Supabase**.

---

## 🚀 Key Features

### 1. Shared Group Ledgers (`/groups`)
*   **Create or Join Groups**: Instantly create groups or join existing ones using a unique 6-character alphanumeric invite code.
*   **Group Expenses & Splits**: Log shared transactions with split types:
    *   `equal`: Splits the amount equally among all group members.
    *   `custom`: Splits the amount using custom-defined balances per member.
*   **Settlements**: Record settlements directly within the group to clear balances.
*   **Group Chat**: Reconciled real-time chat with other group members.

### 2. Personal Finance Ledger (`/dashboard`)
*   **Income & Expense Management**: Track personal expenses and income categories.
*   **Smart Auto-Replication**: Group expenses paid by the current user are replicated automatically into their personal transaction history.
*   **UPI Payment Accounts**: Manage and display bank accounts with dynamic UPI QR codes for quick payments.

### 3. Smart Financial Insights (`/insights`)
*   **Financial Health Score**: A dynamic score (10–100) combining savings rates, category budget overruns, and financial runway.
*   **Reserves & Runway**: Estimates how many months of typical expenses your current balance can support.
*   **Lifestyle Personas**: Gamified profiles (e.g., *Saver*, *Spender*) based on spending patterns.

### 4. Security & Preferences (`/settings`)
*   **App Lock**: Secure the app database with a 4-digit PIN passcode.
*   **Change Passcode**: Dynamically verify current PIN and update it within security settings.
*   **Local Cache & Sync**: Optimistic local state rendering with background synchronization.
*   **Export/Import Data**: Safe export and import of personal configuration databases as JSON files.

---

## 🛠 Architecture & Tech Stack

The codebase adheres to a clean, **feature-first directory layout**:

```
lib/
├── core/
│   ├── constants/       # App durations and configuration limits
│   ├── database/        # Hive cache, chat engine, sync manager, and Supabase client
│   ├── exceptions/      # Core exception handling schemas
│   ├── logging/         # Internal system logger
│   ├── providers/       # Riverpod Providers (preferences, auth status, session lock)
│   ├── routes/          # GoRouter routing declarations
│   ├── theme/           # App colors and typography
│   └── utils/           # Multi-currency helper and validators
├── features/            # Isolated business-logic modules
│   ├── auth/            # Splash, login, signup, and passcode verification UI
│   ├── budget/          # Personal budget settings and category limit screen
│   ├── dashboard/       # Core dashboard home screen
│   ├── expenses/        # Personal transaction logic and entries
│   ├── groups/          # Group lists, settings, detail screens, splits, and service APIs
│   ├── income/          # Income source entries and trackers
│   ├── insights/        # Smart health score, graphs, and wrap analytics
│   ├── profile/         # Profile details and display setups
│   └── settings/        # App controls, backups, guides, and UPI links
└── shared/              # Reusable UI widgets (GlassCard, CustomTextField, BottomNav)
```

### 1. State Management (Riverpod)
- **Declarative Providers**: Features like `preferencesProvider`, `expensesStreamProvider`, and `incomeStreamProvider` stream data seamlessly into views.
- **Auto-Disposal**: Reconciles and releases resources automatically when navigating away from specific groups or chats.

### 2. Offline Synchronization Engine
- **Local Persistence**: Data is persisted in Hive boxes (`group_expenses_$groupId`, `expenses_$userId`, etc.) for instant, zero-latency startup.
- **Queueing**: Mutations made while offline are saved to a background queue (`kanakku_pending_queue_v4`).
- **Reconciliation**: Once an active connection is detected, `RealtimeSyncManager` executes pending operations sequentially.

### 3. Database Schema (Supabase PostgreSQL)
- **Profiles**: Link authentication records to display names and currencies.
- **Cascade Deletes**: Deleting a group expense cascades and deletes related member splits.
- **Check Constraints**: Enforces split types (`'equal'` and `'custom'`) at the database level to maintain data integrity.

---

## 🔧 Installation & Setup

### Prerequisites
- Flutter SDK (v3.19+ recommended)
- Dart SDK
- Android SDK (for mobile builds)

### 1. Clone the Repository
```bash
git clone https://github.com/<your-username>/kanakku_flutter.git
cd kanakku_flutter
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Setup Environment Variables
Create a `.env` file in the root directory:
```env
SUPABASE_URL=https://your-supabase-url.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
```

### 4. Running the Project
```bash
# Run in development mode
flutter run

# Run static analysis
flutter analyze

# Run tests
flutter test
```

---

## 📱 Emulator Stability Guidelines (Windows)
To prevent graphics driver crashes or debugger disconnects inside the Android Emulator on Windows:
1. **Disable Impeller Rendering**: Impeller is disabled by default in `AndroidManifest.xml` via:
   ```xml
   <meta-data
       android:name="io.flutter.embedding.android.EnableImpeller"
       android:value="false" />
   ```
2. **Graphics Configuration**: Set graphics rendering in the AVD Manager to `Software - GLES 2.0` if you experience GPU-related freezes.
3. **Emulator Images**: Use stable system images (**API 34** or **API 35**).
