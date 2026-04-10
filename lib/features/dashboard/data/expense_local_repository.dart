import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../../../core/services/change_log_service.dart';
import '../models/models.dart';
import 'expense_repository.dart';

class ExpenseLocalRepositoryException implements Exception {
  ExpenseLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExpenseLocalRepository implements ExpenseRepository {
  const ExpenseLocalRepository();

  static const int pageSize = 10;

  @override
  Future<void> initialize() async {
    await AppDatabase.instance;
  }

  @override
  Future<ExpensePageResult> fetchExpenses({
    required int page,
    String? searchQuery,
    String? categoryQuery,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final isar = await AppDatabase.instance;
    final allExpenses = await isar.expenseEntitys.where().findAll();
    final filtered = _filterExpenses(
      allExpenses,
      searchQuery: searchQuery,
      categoryQuery: categoryQuery,
      fromDate: fromDate,
      toDate: toDate,
    );

    final totalCount = filtered.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <ExpenseEntity>[]
        : filtered.sublist(start, end);

    final activeExpenses = allExpenses
        .where((expense) => expense.status == ExpenseEntityStatus.active)
        .toList();
    final rangeAmount = filtered.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return ExpensePageResult(
      expenses: pageItems.map(_mapEntityToRecord).toList(),
      summary: ExpenseSummary(
        totalExpenses: allExpenses.length,
        activeExpenses: activeExpenses.length,
        totalAmount: activeExpenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        ),
        rangeAmount: rangeAmount,
      ),
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<String>> fetchCategorySuggestions(String query) async {
    final isar = await AppDatabase.instance;
    final allExpenses = await isar.expenseEntitys.where().findAll();
    final normalized = query.trim().toLowerCase();
    return allExpenses
        .map((expense) => expense.category.trim())
        .where((category) => category.isNotEmpty)
        .where(
          (category) =>
              normalized.isEmpty || category.toLowerCase().contains(normalized),
        )
        .toSet()
        .take(6)
        .toList();
  }

  @override
  Future<ExpenseRecord?> fetchExpenseDetails(ExpenseRecord expense) async {
    final isar = await AppDatabase.instance;
    final expenseId = expense.id;
    final entity = expenseId == null
        ? null
        : await isar.expenseEntitys.get(expenseId);
    if (entity == null) {
      return null;
    }
    return _mapEntityToRecord(entity);
  }

  @override
  Future<ExpenseRecord> saveExpense(ExpenseRecord expense) async {
    final isar = await AppDatabase.instance;
    final expenseId = expense.id;
    final existing = expenseId == null
        ? null
        : await isar.expenseEntitys.get(expenseId);
    final now = DateTime.now();
    final entity = ExpenseEntity()
      ..id = expense.id ?? Isar.autoIncrement
      ..title = expense.title.trim()
      ..category = expense.category.trim()
      ..amount = expense.amount
      ..expenseDate = expense.date
      ..paymentMethod = expense.paymentMethod.trim()
      ..notes = expense.notes.trim()
      ..status = _mapStatusToEntity(expense.status)
      ..createdAt = existing?.createdAt ?? now
      ..updatedAt = existing == null ? null : now;

    late final int savedId;
    await isar.writeTxn(() async {
      savedId = await isar.expenseEntitys.put(entity);
    });

    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.expense,
      entityId: savedId.toString(),
      action: existing == null ? 'create' : 'update',
      title: existing == null ? 'Expense created' : 'Expense updated',
      details: <String, dynamic>{
        'title': entity.title,
        'category': entity.category,
        'amount': entity.amount,
        'date': entity.expenseDate.toIso8601String(),
      },
    );

    return expense.copyWith(
      id: savedId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: existing == null ? null : now,
    );
  }

  @override
  Future<void> deactivateExpense(ExpenseRecord expense) async {
    final isar = await AppDatabase.instance;
    final expenseId = expense.id;
    if (expenseId == null) {
      throw ExpenseLocalRepositoryException('Expense identifier is missing');
    }
    final entity = await isar.expenseEntitys.get(expenseId);
    if (entity == null) {
      return;
    }

    entity
      ..status = ExpenseEntityStatus.inactive
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.expenseEntitys.put(entity);
    });

    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.expense,
      entityId: expenseId.toString(),
      action: 'deactivate',
      title: 'Expense deactivated',
      details: <String, dynamic>{
        'title': entity.title,
        'amount': entity.amount,
      },
    );
  }

  @override
  Future<ExpenseReportData> fetchExpenseReport({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final isar = await AppDatabase.instance;
    final allExpenses = await isar.expenseEntitys.where().findAll();
    final filtered = _filterExpenses(
      allExpenses,
      fromDate: fromDate,
      toDate: toDate,
    ).where((expense) => expense.status == ExpenseEntityStatus.active).toList();

    return ExpenseReportData(
      expenses: filtered.map(_mapEntityToRecord).toList(),
      totalAmount: filtered.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      ),
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  List<ExpenseEntity> _filterExpenses(
    List<ExpenseEntity> expenses, {
    String? searchQuery,
    String? categoryQuery,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final normalizedSearch = searchQuery?.trim().toLowerCase() ?? '';
    final normalizedCategory = categoryQuery?.trim().toLowerCase() ?? '';
    final normalizedFrom = fromDate == null
        ? null
        : DateTime(fromDate.year, fromDate.month, fromDate.day);
    final normalizedTo = toDate == null
        ? null
        : DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999);

    final filtered =
        expenses.where((expense) {
          final matchesSearch =
              normalizedSearch.isEmpty ||
              expense.title.toLowerCase().contains(normalizedSearch) ||
              expense.notes.toLowerCase().contains(normalizedSearch) ||
              expense.paymentMethod.toLowerCase().contains(normalizedSearch);
          final matchesCategory =
              normalizedCategory.isEmpty ||
              expense.category.toLowerCase().contains(normalizedCategory);
          final matchesFrom =
              normalizedFrom == null ||
              !expense.expenseDate.isBefore(normalizedFrom);
          final matchesTo =
              normalizedTo == null ||
              !expense.expenseDate.isAfter(normalizedTo);
          return matchesSearch && matchesCategory && matchesFrom && matchesTo;
        }).toList()..sort(
          (left, right) => right.expenseDate.compareTo(left.expenseDate),
        );
    return filtered;
  }

  ExpenseRecord _mapEntityToRecord(ExpenseEntity entity) {
    return ExpenseRecord(
      id: entity.id,
      title: entity.title,
      category: entity.category,
      amount: entity.amount,
      date: entity.expenseDate,
      paymentMethod: entity.paymentMethod,
      notes: entity.notes,
      status: entity.status == ExpenseEntityStatus.active
          ? ExpenseStatus.active
          : ExpenseStatus.inactive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  ExpenseEntityStatus _mapStatusToEntity(ExpenseStatus status) {
    return status == ExpenseStatus.active
        ? ExpenseEntityStatus.active
        : ExpenseEntityStatus.inactive;
  }
}
