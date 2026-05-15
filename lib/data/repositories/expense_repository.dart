import '../../core/database/hive_service.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  Future<void> addExpense(Expense expense) async => HiveService.saveExpense(expense);

  Future<void> addExpenses(List<Expense> expenses) async => HiveService.saveExpenses(expenses);

  List<Expense> getAllExpenses() => HiveService.getAllExpenses();

  Expense? getExpenseById(String id) => HiveService.getExpense(id);

  Future<void> deleteExpense(String id) async => HiveService.deleteExpense(id);

  List<Expense> getExpensesByCategory(String category) => HiveService.getExpensesByCategory(category);

  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) => HiveService.getExpensesByDateRange(start, end);
}
