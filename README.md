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

Kanakku uses a multi-layered, **offline-first Architecture** combining **Flutter UI**, **Riverpod State controllers**, **Hive local caching**, and the **Supabase cloud engine**.

```mermaid
graph TD
    UI[UI Presentation Layer<br>Flutter Widgets / Glassmorphic Views]
    PROV[State Controller Layer<br>Riverpod Notifiers & Providers]
    CACHE[Local Caching Layer<br>Hive Box Local Stores]
    QUEUE[Pending Queue Box<br>Hive Action Buffer]
    SYNC[Sync Service Layer<br>RealtimeSyncManager Runner]
    REMOTE[Cloud Database Layer<br>Supabase Postgres Service]

    UI -->|Read streams & states| PROV
    UI -->|Dispatch User actions| PROV
    PROV -->|Read/Write Cache| CACHE
    PROV -->|Queue mutations offline| QUEUE
    SYNC -->|Monitor network status| QUEUE
    SYNC -->|Push actions online| REMOTE
    REMOTE -->|Listen realtime streams| CACHE
```

### 1. Architectural Layers & Roles
- **Presentation Layer (`lib/shared` & `lib/features/*/presentation`)**: Renders the visual elements, charts, and transaction feeds. Listens directly to Riverpod StreamProviders.
- **State Controller Layer (`lib/core/providers` & `lib/features/*/data`)**: Riverpod Notifiers maintain in-memory states (theme index, currencies, wallet balances, budgets) and dispatch database actions.
- **Local Persistence Layer (`lib/core/database/local_cache_service.dart`)**: Uses Hive to cache list/map representations of tables. Enables zero-latency startup and complete offline usability.
- **Background Sync Layer (`lib/core/database/realtime_sync_manager.dart`)**: A connectivity-aware worker that monitors the network status and serializes pending local writes to the cloud DB.
- **Cloud Database Layer (Supabase)**: Serves as the source of truth, enforcing cascading schema relationships and Row-Level Security (RLS) policies.

---

## 🔄 Caching & Offline Sync Pipeline

Kanakku implements a strict **Optimistic Update** model. Below is the step-by-step transaction sync lifecycle:

```mermaid
sequenceDiagram
    autonumber
    actor User as User Action
    participant UI as Flutter View
    participant Prov as Riverpod State
    participant Hive as Hive Cache Box
    participant Queue as Sync Queue Box
    participant Sync as Sync Manager
    participant DB as Supabase DB

    User->>UI: Logs expense (e.g. ₹500 Pizza)
    UI->>Prov: Triggers addExpense()
    Prov->>Hive: Writes record optimistically
    Hive-->>UI: Instantly updates UI (No spinner)
    Prov->>Queue: Appends action payload (e.g. insert: Pizza)
    Note over Sync: Connection Restored (Online)
    Sync->>Queue: Dequeues next pending action
    Sync->>DB: Executes mutation (API request)
    DB-->>Sync: Confirms transaction written (200 OK)
    Sync->>Hive: Promotes state to synced (check icon)
    Sync->>Queue: Removes action from queue
```

### Flow Details
1. **Offline Write**: Transactions logged while offline update the local Hive cache immediately, creating a temporary ID (e.g. `temp_1700000000`).
2. **Queueing**: The mutation is saved as a JSON packet inside `kanakku_pending_queue_v4` describing the `actionType` (`insert`, `update`, `delete`), table `path`, and parameters.
3. **Reconciliation**: When connection status changes to online, `RealtimeSyncManager` executes the action queue sequentially. On success, it replaces temporary cached IDs with the confirmed Supabase database row.

---

## 📂 Codebase Directory Layout

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
