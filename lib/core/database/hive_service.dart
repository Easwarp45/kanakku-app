import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/user_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';

/// Service for managing Hive database operations
class HiveService {
  static const String userBoxKey = 'users_box';
  static const String expenseBoxKey = 'expenses_box';
  static const String categoryBoxKey = 'categories_box';
  static const String transactionBoxKey = 'transactions_box';
  static const String settingsBoxKey = 'settings_box';

  // Boxes
  static late Box<User> _userBox;
  static late Box<Expense> _expenseBox;
  static late Box<Category> _categoryBox;
  static late Box<Transaction> _transactionBox;
  static late Box<String> _settingsBox;

  /// Initialize Hive and open all boxes
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters
    _registerAdapters();
    
    // Open boxes
    _userBox = await Hive.openBox<User>(userBoxKey);
    _expenseBox = await Hive.openBox<Expense>(expenseBoxKey);
    _categoryBox = await Hive.openBox<Category>(categoryBoxKey);
    _transactionBox = await Hive.openBox<Transaction>(transactionBoxKey);
    _settingsBox = await Hive.openBox<String>(settingsBoxKey);
  }

  /// Register Hive adapters for models
  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionTypeAdapter());
    }
  }

  /// Clear all data (use with caution)
  static Future<void> clearAll() async {
    await Future.wait([
      _userBox.clear(),
      _expenseBox.clear(),
      _categoryBox.clear(),
      _transactionBox.clear(),
      _settingsBox.clear(),
    ]);
  }

  // User operations
  static Future<void> saveUser(User user) async {
    await _userBox.put('current_user', user);
  }

  static User? getUser() {
    return _userBox.get('current_user');
  }

  static Future<void> deleteUser() async {
    await _userBox.delete('current_user');
  }

  // Expense operations
  static Future<void> saveExpense(Expense expense) async {
    await _expenseBox.put(expense.id, expense);
  }

  static Future<void> saveExpenses(List<Expense> expenses) async {
    final map = {for (var expense in expenses) expense.id: expense};
    await _expenseBox.putAll(map);
  }

  static Expense? getExpense(String id) {
    return _expenseBox.get(id);
  }

  static List<Expense> getAllExpenses() {
    return _expenseBox.values.toList();
  }

  static List<Expense> getExpensesByCategory(String category) {
    return _expenseBox.values
        .where((expense) => expense.category == category)
        .toList();
  }

  static List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    return _expenseBox.values
        .where((expense) =>
            expense.date.isAfter(start) && expense.date.isBefore(end))
        .toList();
  }

  static Future<void> deleteExpense(String id) async {
    await _expenseBox.delete(id);
  }

  static int getExpenseCount() {
    return _expenseBox.length;
  }

  // Category operations
  static Future<void> saveCategory(Category category) async {
    await _categoryBox.put(category.id, category);
  }

  static Future<void> saveCategories(List<Category> categories) async {
    final map = {for (var category in categories) category.id: category};
    await _categoryBox.putAll(map);
  }

  static Category? getCategory(String id) {
    return _categoryBox.get(id);
  }

  static List<Category> getAllCategories() {
    return _categoryBox.values.toList();
  }

  static Future<void> deleteCategory(String id) async {
    await _categoryBox.delete(id);
  }

  // Transaction operations
  static Future<void> saveTransaction(Transaction transaction) async {
    await _transactionBox.put(transaction.id, transaction);
  }

  static Future<void> saveTransactions(List<Transaction> transactions) async {
    final map = {for (var transaction in transactions) transaction.id: transaction};
    await _transactionBox.putAll(map);
  }

  static Transaction? getTransaction(String id) {
    return _transactionBox.get(id);
  }

  static List<Transaction> getAllTransactions() {
    return _transactionBox.values.toList();
  }

  static List<Transaction> getTransactionsByType(TransactionType type) {
    return _transactionBox.values
        .where((transaction) => transaction.type == type)
        .toList();
  }

  static List<Transaction> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) {
    return _transactionBox.values
        .where((transaction) =>
            transaction.date.isAfter(start) &&
            transaction.date.isBefore(end))
        .toList();
  }

  static Future<void> deleteTransaction(String id) async {
    await _transactionBox.delete(id);
  }

  static int getTransactionCount() {
    return _transactionBox.length;
  }

  // Settings operations
  static Future<void> setSetting(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  static String? getSetting(String key) {
    return _settingsBox.get(key);
  }

  static Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
  }

  // Helper methods
  static double getTotalExpenses() {
    return _expenseBox.values.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  static double getTotalIncome() {
    return _transactionBox.values
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  static double getTotalExpensesFromTransactions() {
    return _transactionBox.values
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  static double getBalance() {
    return getTotalIncome() - getTotalExpensesFromTransactions();
  }
}

/// Adapter for TransactionType enum
class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 1;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.income;
      case 1:
        return TransactionType.expense;
      default:
        return TransactionType.expense;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.income:
        writer.writeByte(0);
        break;
      case TransactionType.expense:
        writer.writeByte(1);
        break;
    }
  }
}
