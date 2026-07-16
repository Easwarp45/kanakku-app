/// Canonical column allowlists and enum values matching the live Supabase schema.
///
/// Validated against the production PostgreSQL enums:
///   expense_category, payment_method, income_source
library;

/// Columns Flutter may write on each table (excludes server-managed timestamps
/// unless an update explicitly refreshes `updated_at`).
class SchemaColumns {
  static const profilesWritable = {
    'display_name',
    'phone_number',
    'avatar_url',
    'language',
    'currency',
  };

  static const expensesWritable = {
    'user_id',
    'amount',
    'category',
    'description',
    'payment_method',
    'expense_date',
    'receipt_url',
  };

  static const incomeWritable = {
    'user_id',
    'amount',
    'source',
    'description',
    'income_date',
    'is_recurring',
  };

  static const budgetsWritable = {
    'user_id',
    'category',
    'amount',
    'period',
  };

  static const financialGoalsWritable = {
    'user_id',
    'target_amount',
    'current_saved',
    'deadline',
  };

  static const groupsWritable = {
    'name',
    'description',
    'image_url',
    'created_by',
    'invite_code',
  };

  static const groupMembersWritable = {
    'group_id',
    'user_id',
    'nickname',
    'is_admin',
  };

  static const groupExpensesWritable = {
    'group_id',
    'paid_by',
    'amount',
    'description',
    'category',
    'expense_date',
    'split_type',
  };

  static const expenseSplitsWritable = {
    'group_expense_id',
    'user_id',
    'amount',
    'is_settled',
    'settled_at',
  };

  static const settlementsWritable = {
    'group_id',
    'paid_by',
    'paid_to',
    'amount',
    'note',
  };

  static const groupChatsWritable = {
    'group_id',
    'user_id',
    'message',
    'client_id',
  };
}

/// Live `expense_category` enum values.
const expenseCategoryEnum = {
  'food',
  'transport',
  'entertainment',
  'health',
  'shopping',
  'education',
  'travel',
  'bills',
  'other',
};

/// Live `payment_method` enum values.
const paymentMethodEnum = {
  'upi',
  'cash',
  'card',
  'bank_transfer',
  'other',
};

/// Live `income_source` enum values.
const incomeSourceEnum = {
  'salary',
  'freelance',
  'business',
  'investment',
  'gift',
  'refund',
  'other',
};

/// Display-label → DB enum for personal expense forms.
const expenseCategoryToEnum = <String, String>{
  'Food & Dining': 'food',
  'Transportation': 'transport',
  'Housing': 'bills',
  'Entertainment': 'entertainment',
  'Health': 'health',
  'Shopping': 'shopping',
  'Utilities': 'bills',
  'Education': 'education',
  'Travel': 'travel',
  'Others': 'other',
  'Other': 'other',
};

/// DB enum → display label for personal expense forms.
const expenseEnumToCategory = <String, String>{
  'food': 'Food & Dining',
  'transport': 'Transportation',
  'bills': 'Utilities',
  'entertainment': 'Entertainment',
  'health': 'Health',
  'shopping': 'Shopping',
  'education': 'Education',
  'travel': 'Travel',
  'other': 'Others',
};

/// Normalize a date / timestamptz value to PostgreSQL `date` (`YYYY-MM-DD`).
String toDateOnly(dynamic value) {
  if (value == null) {
    return DateTime.now().toIso8601String().split('T').first;
  }
  return value.toString().split('T').first;
}

/// Keep only keys that belong to [allowed], dropping nulls.
Map<String, dynamic> filterPayload(
  Map<String, dynamic> data,
  Set<String> allowed,
) {
  return Map<String, dynamic>.fromEntries(
    data.entries.where((e) => allowed.contains(e.key) && e.value != null),
  );
}

/// Coerce an expense category to a valid DB enum value.
String sanitizeExpenseCategory(dynamic value) {
  final raw = value?.toString().trim().toLowerCase() ?? 'other';
  if (expenseCategoryEnum.contains(raw)) return raw;
  // Legacy / display-label fallbacks
  if (raw.contains('food') || raw.contains('dining')) return 'food';
  if (raw.contains('transport')) return 'transport';
  if (raw.contains('hous') || raw.contains('rent')) return 'bills';
  if (raw.contains('entertain')) return 'entertainment';
  if (raw.contains('health') || raw.contains('medical')) return 'health';
  if (raw.contains('shop')) return 'shopping';
  if (raw.contains('util') || raw.contains('bill')) return 'bills';
  if (raw.contains('educat')) return 'education';
  if (raw.contains('travel')) return 'travel';
  return 'other';
}

/// Coerce an income source to a valid DB enum value.
String sanitizeIncomeSource(dynamic value) {
  final raw = value?.toString().trim().toLowerCase() ?? 'other';
  if (incomeSourceEnum.contains(raw)) return raw;
  // Legacy Flutter keys that are not in the live enum
  switch (raw) {
    case 'rental':
    case 'bonus':
    case 'cashback':
    case 'passive':
      return 'other';
    default:
      return 'other';
  }
}

/// Coerce a payment method to a valid DB enum value.
String sanitizePaymentMethod(dynamic value) {
  final raw = value?.toString().trim().toLowerCase() ?? 'upi';
  if (paymentMethodEnum.contains(raw)) return raw;
  if (raw.contains('card') || raw.contains('credit') || raw.contains('debit')) {
    return 'card';
  }
  if (raw.contains('cash')) return 'cash';
  if (raw.contains('bank') || raw.contains('transfer') || raw.contains('net')) {
    return 'bank_transfer';
  }
  if (raw.contains('upi')) return 'upi';
  return 'other';
}
