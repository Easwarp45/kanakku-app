# Kanakku: Architecture Decisions & Tech Stack Rationales

This document details the core architectural decisions behind the Kanakku financial application, comparing chosen technologies against alternatives and explaining the trade-offs.

---

## 1. Backend, Auth, and Database: Supabase
Kanakku uses **Supabase** for user authentication, PostgreSQL database storage, and realtime WebSocket-based event streaming.

### Alternatives Considered
- **Firebase (Auth & Firestore)**
- **Custom Backend (Go / PostgreSQL / WebSockets)**

### Reason for Selection
1. **Relational Ledger Integrity**: Expense tracking is inherently relational. Transactions, settlements, group memberships, and balance splits require strict foreign key constraints, joins, and acid transactions. PostgreSQL (Supabase's core database) ensures ledger rows never mismatch.
2. **Realtime Group Syncing**: Supabase's Realtime engine allows the app to listen to Postgres changes via WebSockets. When a roommate adds an expense in a group, other members' screens update instantly without manual refreshing.
3. **Speed of Delivery**: Out-of-the-box JWT authentication, row-level security (RLS), and database hosting allowed us to build a secure app without maintaining server infrastructure.

### Why Alternatives Were Rejected
- **Firebase**: Firestore is a NoSQL document database. Performing complex ledger queries (such as calculating net balances between group members by joining expenses and settlements) in NoSQL requires heavy client-side computation or duplicate denormalized entries, which leads to consistency bugs.
- **Custom Go/Postgres Backend**: While ideal for ultimate customizability, writing a custom backend requires building authentication, session management, WebSockets, and migrations from scratch. This would have tripled the development time without providing immediate performance benefits over Supabase.

---

## 2. State Management: Riverpod (v2)
Kanakku uses **Riverpod** to bind backend data streams to the Flutter UI and cache derived state computations.

### Alternatives Considered
- **BLoC (Business Logic Component)**
- **Provider**

### Reason for Selection
1. **Compile-Safe Dependency Injection**: Riverpod operates independently of the Flutter Widget tree, resolving Provider's classic `ProviderNotFoundException` issues.
2. **Automatic Stream & Memory Management**: Using `StreamProvider.autoDispose`, data streams (such as database connections or group channels) are automatically closed and garbage-collected when the user navigates away, preventing memory leaks.
3. **Derived Cache Computations**: Providers like `recentCombinedTransactionsProvider` cache sorted, mapped, and filtered calculations. Rebuilds of the UI read the cached results instantly, rather than re-sorting arrays on every frame.

### Why Alternatives Were Rejected
- **Provider**: Provider is bound to the widget tree and context. It is hard to read providers outside of widgets (e.g. in services or routing configs) and forces layout rebuilds on unrelated context changes.
- **BLoC**: BLoC is extremely robust but requires massive amounts of boilerplate code (Events, States, and BLoC classes) for every single stream. For a data-heavy app with many minor streams, BLoC would double the codebase size, slowing down maintenance.

---

## 3. Routing: GoRouter with Stateful Nested Navigation
Kanakku uses **GoRouter** with `StatefulShellRoute` to organize pages and manage deep linking.

### Alternatives Considered
- **Vanilla Navigator 2.0**
- **Standard Flat GoRouter Routing**

### Reason for Selection
1. **Stateful Tab Preservation**: By configuring `StatefulShellRoute.indexedStack`, the app keeps each tab's viewport (scroll offsets, search text fields, local tab indexes) alive in memory under an `IndexedStack`.
2. **0ms Transition Delay**: Tapping the bottom bar swaps the visibility of pre-instantiated tabs instantly, rather than re-instantiating the screen and triggering new build phases.
3. **Static Bottom Bar**: The bottom navigation bar is declared on the parent shell. It remains perfectly static on screen, preventing the bar from animating out and back in during tab switches.

### Why Alternatives Were Rejected
- **Standard Flat GoRouter**: Flat routes destroy the active page when switching. Swapping tabs causes the screen to flash, forces the bottom bar to perform slide/fade transitions alongside the body, and triggers redundant init phases.
- **Vanilla Navigator 2.0**: The declarative API of Navigator 2.0 is notoriously verbose, error-prone, and hard to integrate with Riverpod-driven authentication guards.
