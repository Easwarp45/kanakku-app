import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/models/expense_model.dart';

final expenseRepositoryProvider = Provider((ref) => ExpenseRepository());

class ExpenseState {
  final bool isLoading;
  final List<Expense> expenses;

  ExpenseState({this.isLoading = false, this.expenses = const []});

  ExpenseState copyWith({bool? isLoading, List<Expense>? expenses}) =>
      ExpenseState(isLoading: isLoading ?? this.isLoading, expenses: expenses ?? this.expenses);
}

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpenseRepository _repo;

  ExpenseNotifier(this._repo) : super(ExpenseState()) {
    loadAll();
  }

  ExpenseState get current => state;

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final list = _repo.getAllExpenses();
    state = state.copyWith(isLoading: false, expenses: list);
  }

  Future<void> addExpense(Expense expense) async {
    await _repo.addExpense(expense);
    await loadAll();
  }

  Future<void> deleteExpense(String id) async {
    await _repo.deleteExpense(id);
    await loadAll();
  }
}

final expenseNotifierProvider = Provider<ExpenseNotifier>((ref) {
  final repo = ref.read(expenseRepositoryProvider);
  final notifier = ExpenseNotifier(repo);
  ref.onDispose(() {
    try {
      notifier.dispose();
    } catch (_) {}
  });
  return notifier;
});

final expenseStateProvider = Provider<ExpenseState>((ref) {
  final notifier = ref.watch(expenseNotifierProvider);
  return notifier.current;
});
