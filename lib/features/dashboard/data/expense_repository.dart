import '../models/models.dart';

abstract class ExpenseRepository {
  Future<void> initialize();

  Future<ExpensePageResult> fetchExpenses({
    required int page,
    String? searchQuery,
    String? categoryQuery,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<String>> fetchCategorySuggestions(String query);

  Future<ExpenseRecord?> fetchExpenseDetails(ExpenseRecord expense);

  Future<ExpenseRecord> saveExpense(ExpenseRecord expense);

  Future<void> deactivateExpense(ExpenseRecord expense);

  Future<ExpenseReportData> fetchExpenseReport({
    required DateTime fromDate,
    required DateTime toDate,
  });
}
