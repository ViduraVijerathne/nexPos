import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/expense_repository.dart';
import '../data/invoice_repository.dart';
import '../models/models.dart';

class DrawerSessionState {
  const DrawerSessionState({
    required this.isActive,
    required this.startedAt,
    required this.openingCash,
    required this.cashierName,
  });

  const DrawerSessionState.inactive()
    : isActive = false,
      startedAt = null,
      openingCash = 0,
      cashierName = '';

  final bool isActive;
  final DateTime? startedAt;
  final double openingCash;
  final String cashierName;
}

class DrawerSessionSummary {
  const DrawerSessionSummary({
    required this.session,
    required this.invoiceCount,
    required this.cashSales,
    required this.cardSales,
    required this.totalSales,
    required this.drawerExpenseTotal,
    required this.expectedDrawerAmount,
  });

  final DrawerSessionState session;
  final int invoiceCount;
  final double cashSales;
  final double cardSales;
  final double totalSales;
  final double drawerExpenseTotal;
  final double expectedDrawerAmount;
}

class DaySessionService {
  DaySessionService._();

  static final DaySessionService instance = DaySessionService._();

  static const String _activeKey = 'day_session.active';
  static const String _startedAtKey = 'day_session.started_at';
  static const String _openingCashKey = 'day_session.opening_cash';
  static const String _cashierNameKey = 'day_session.cashier_name';

  final ValueNotifier<int> sessionVersionNotifier = ValueNotifier<int>(0);

  void _notifyChanged() {
    sessionVersionNotifier.value = sessionVersionNotifier.value + 1;
  }

  Future<DrawerSessionState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_activeKey) ?? false;
    if (!isActive) {
      return const DrawerSessionState.inactive();
    }

    final startedAtRaw = prefs.getString(_startedAtKey);
    final startedAt = startedAtRaw == null
        ? null
        : DateTime.tryParse(startedAtRaw);
    if (startedAt == null) {
      return const DrawerSessionState.inactive();
    }

    return DrawerSessionState(
      isActive: true,
      startedAt: startedAt,
      openingCash: prefs.getDouble(_openingCashKey) ?? 0,
      cashierName: prefs.getString(_cashierNameKey) ?? '',
    );
  }

  Future<void> startSession({
    required double openingCash,
    required String cashierName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, true);
    await prefs.setString(_startedAtKey, DateTime.now().toIso8601String());
    await prefs.setDouble(_openingCashKey, openingCash);
    await prefs.setString(_cashierNameKey, cashierName);
    _notifyChanged();
  }

  Future<void> endSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_startedAtKey);
    await prefs.remove(_openingCashKey);
    await prefs.remove(_cashierNameKey);
    _notifyChanged();
  }

  Future<DrawerSessionSummary> buildSummary({
    required InvoiceRepository repository,
    required ExpenseRepository expenseRepository,
    required DrawerSessionState session,
  }) async {
    final startedAt = session.startedAt;
    if (!session.isActive || startedAt == null) {
      return DrawerSessionSummary(
        session: session,
        invoiceCount: 0,
        cashSales: 0,
        cardSales: 0,
        totalSales: 0,
        drawerExpenseTotal: 0,
        expectedDrawerAmount: session.openingCash,
      );
    }

    final invoices = await _fetchInvoicesSince(
      repository: repository,
      startedAt: startedAt,
    );
    final expenseReport = await expenseRepository.fetchExpenseReport(
      fromDate: startedAt,
      toDate: DateTime.now(),
    );
    final drawerExpenseTotal = expenseReport.expenses
        .where(
          (expense) =>
              expense.paidFromDrawer &&
              expense.status == ExpenseStatus.active &&
              !expense.createdAt.isBefore(startedAt),
        )
        .fold<double>(0, (sum, expense) => sum + expense.amount);

    final cashSales = invoices.fold<double>(0, (sum, invoice) {
      // Stored cash is the tendered amount, including change returned.
      final change = (invoice.paidAmount - invoice.amount)
          .clamp(0, invoice.cashPaidAmount)
          .toDouble();
      return sum + invoice.cashPaidAmount - change;
    });
    final cardSales = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.cardPaidAmount,
    );
    final totalSales = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.amount,
    );

    return DrawerSessionSummary(
      session: session,
      invoiceCount: invoices.length,
      cashSales: cashSales,
      cardSales: cardSales,
      totalSales: totalSales,
      drawerExpenseTotal: drawerExpenseTotal,
      expectedDrawerAmount:
          session.openingCash + cashSales - drawerExpenseTotal,
    );
  }

  Future<List<InvoiceRecord>> _fetchInvoicesSince({
    required InvoiceRepository repository,
    required DateTime startedAt,
  }) async {
    final records = <InvoiceRecord>[];
    var page = 1;
    var totalPages = 1;

    do {
      final result = await repository.fetchInvoices(page: page);
      totalPages = result.totalPages;
      records.addAll(
        result.invoices.where((invoice) {
          final issuedAt = DateTime.tryParse(invoice.date);
          return issuedAt != null &&
              !issuedAt.isBefore(startedAt) &&
              invoice.status == InvoiceStatus.paid;
        }),
      );
      page += 1;
    } while (page <= totalPages);

    records.sort((left, right) => right.date.compareTo(left.date));
    return records;
  }
}
