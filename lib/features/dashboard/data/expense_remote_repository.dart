import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/change_log_service.dart';
import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'expense_repository.dart';

class ExpenseRemoteRepositoryException implements Exception {
  ExpenseRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExpenseRemoteRepository implements ExpenseRepository {
  ExpenseRemoteRepository({required this.shopId});

  static const int pageSize = 10;

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('expenses');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw ExpenseRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<ExpensePageResult> fetchExpenses({
    required int page,
    String? searchQuery,
    String? categoryQuery,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final snapshot = await _expensesRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'expenses',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );

    final allExpenses = snapshot.docs.map(_mapDocumentToRecord).toList()
      ..sort((left, right) => right.date.compareTo(left.date));

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
        ? <ExpenseRecord>[]
        : filtered.sublist(start, end);

    final activeExpenses = allExpenses
        .where((expense) => expense.status == ExpenseStatus.active)
        .toList();

    return ExpensePageResult(
      expenses: pageItems,
      summary: ExpenseSummary(
        totalExpenses: allExpenses.length,
        activeExpenses: activeExpenses.length,
        totalAmount: activeExpenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        ),
        rangeAmount: filtered.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        ),
      ),
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<String>> fetchCategorySuggestions(String query) async {
    final snapshot = await _expensesRef.limit(100).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'expenses',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final normalized = query.trim().toLowerCase();
    return snapshot.docs
        .map((doc) => doc.data()['category']?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .where(
          (item) =>
              normalized.isEmpty || item.toLowerCase().contains(normalized),
        )
        .toSet()
        .take(6)
        .toList();
  }

  @override
  Future<ExpenseRecord?> fetchExpenseDetails(ExpenseRecord expense) async {
    final cloudId = expense.cloudId;
    if (cloudId == null || cloudId.isEmpty) {
      throw ExpenseRemoteRepositoryException('Expense identifier is missing');
    }
    final snapshot = await _expensesRef.doc(cloudId).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'expenses',
      documentCount: snapshot.exists ? 1 : 0,
      payload: snapshot.data(),
    );
    if (!snapshot.exists) {
      return null;
    }
    return _mapDocumentToRecord(snapshot);
  }

  @override
  Future<ExpenseRecord> saveExpense(ExpenseRecord expense) async {
    final trimmedTitle = expense.title.trim();
    final trimmedCategory = expense.category.trim();
    if (trimmedTitle.isEmpty) {
      throw ExpenseRemoteRepositoryException('Expense title is required');
    }
    if (trimmedCategory.isEmpty) {
      throw ExpenseRemoteRepositoryException('Expense category is required');
    }

    final now = DateTime.now();
    final docRef = expense.cloudId == null
        ? _expensesRef.doc()
        : _expensesRef.doc(expense.cloudId);
    final existing = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'expenses',
      documentCount: existing.exists ? 1 : 0,
      payload: existing.data(),
    );

    final payload = <String, dynamic>{
      'title': trimmedTitle,
      'titleLower': trimmedTitle.toLowerCase(),
      'category': trimmedCategory,
      'categoryLower': trimmedCategory.toLowerCase(),
      'amount': expense.amount,
      'expenseDate': Timestamp.fromDate(expense.date),
      'paymentMethod': expense.paymentMethod.trim(),
      'notes': expense.notes.trim(),
      'status': expense.status.name,
      'createdAt': existing.data()?['createdAt'] ?? Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    await docRef.set(payload, SetOptions(merge: true));
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'expenses',
      documentCount: 1,
      payload: payload,
    );

    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.expense,
      entityId: docRef.id,
      action: expense.cloudId == null ? 'create' : 'update',
      title: expense.cloudId == null ? 'Expense created' : 'Expense updated',
      details: <String, dynamic>{
        'title': trimmedTitle,
        'category': trimmedCategory,
        'amount': expense.amount,
        'date': expense.date.toIso8601String(),
      },
    );

    final refreshed = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'expenses',
      documentCount: refreshed.exists ? 1 : 0,
      payload: refreshed.data(),
    );
    return _mapDocumentToRecord(refreshed);
  }

  @override
  Future<void> deactivateExpense(ExpenseRecord expense) async {
    final cloudId = expense.cloudId;
    if (cloudId == null || cloudId.isEmpty) {
      throw ExpenseRemoteRepositoryException('Expense identifier is missing');
    }
    final payload = <String, dynamic>{
      'status': ExpenseStatus.inactive.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    await _expensesRef.doc(cloudId).set(payload, SetOptions(merge: true));
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'expenses',
      documentCount: 1,
      payload: payload,
    );
    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.expense,
      entityId: cloudId,
      action: 'deactivate',
      title: 'Expense deactivated',
      details: <String, dynamic>{
        'title': expense.title,
        'amount': expense.amount,
      },
    );
  }

  @override
  Future<ExpenseReportData> fetchExpenseReport({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final snapshot = await _expensesRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'expenses',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final allExpenses = snapshot.docs.map(_mapDocumentToRecord).toList();
    final activeExpenses = _filterExpenses(
      allExpenses,
      fromDate: fromDate,
      toDate: toDate,
    ).where((expense) => expense.status == ExpenseStatus.active).toList();
    return ExpenseReportData(
      expenses: activeExpenses,
      totalAmount: activeExpenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      ),
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  List<ExpenseRecord> _filterExpenses(
    List<ExpenseRecord> expenses, {
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

    return expenses.where((expense) {
      final matchesSearch =
          normalizedSearch.isEmpty ||
          expense.title.toLowerCase().contains(normalizedSearch) ||
          expense.notes.toLowerCase().contains(normalizedSearch) ||
          expense.paymentMethod.toLowerCase().contains(normalizedSearch);
      final matchesCategory =
          normalizedCategory.isEmpty ||
          expense.category.toLowerCase().contains(normalizedCategory);
      final matchesFrom =
          normalizedFrom == null || !expense.date.isBefore(normalizedFrom);
      final matchesTo =
          normalizedTo == null || !expense.date.isAfter(normalizedTo);
      return matchesSearch && matchesCategory && matchesFrom && matchesTo;
    }).toList();
  }

  ExpenseRecord _mapDocumentToRecord(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ExpenseRecord(
      cloudId: doc.id,
      title: data['title']?.toString().trim() ?? '',
      category: data['category']?.toString().trim() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: _readDate(data['expenseDate']) ?? DateTime.now(),
      paymentMethod: data['paymentMethod']?.toString().trim() ?? 'Cash',
      notes: data['notes']?.toString().trim() ?? '',
      status: (data['status']?.toString().trim() ?? 'active') == 'inactive'
          ? ExpenseStatus.inactive
          : ExpenseStatus.active,
      createdAt: _readDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
