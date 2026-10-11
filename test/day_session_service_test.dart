import 'package:flutter_test/flutter_test.dart';
import 'package:nex_pos_desktop/features/dashboard/data/expense_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/invoice_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/models/models.dart';
import 'package:nex_pos_desktop/features/dashboard/services/day_session_service.dart';

class _Invoices implements InvoiceRepository {
  _Invoices(this.records);
  final List<InvoiceRecord> records;

  @override
  Future<InvoicePageResult> fetchInvoices({
    required int page,
    String? invoiceIdQuery,
    String? customerQuery,
    String? dateFrom,
    String? dateTo,
    double? amountLessThan,
    double? amountGreaterThan,
    String? statusFilter,
  }) async => InvoicePageResult(
    invoices: [records[page - 1]],
    summary: InvoiceSummary.fromInvoices(records),
    totalCount: records.length,
    currentPage: page,
    pageSize: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Expenses implements ExpenseRepository {
  _Expenses(this.records);
  final List<ExpenseRecord> records;

  @override
  Future<ExpenseReportData> fetchExpenseReport({
    required DateTime fromDate,
    required DateTime toDate,
  }) async => ExpenseReportData(
    expenses: records,
    totalAmount: records.fold<double>(0, (sum, item) => sum + item.amount),
    fromDate: fromDate,
    toDate: toDate,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

InvoiceRecord _invoice(DateTime date, double cash, double card) =>
    InvoiceRecord(
      invoiceId: '$cash-$card',
      customerName: 'Walk-in',
      customerCode: 'walk-in',
      date: date.toIso8601String(),
      amount: 100,
      subtotal: 100,
      discount: 0,
      tax: 0,
      status: InvoiceStatus.paid,
      items: const [],
      paymentMethod: 'Cash',
      cashPaidAmount: cash,
      cardPaidAmount: card,
      cashierName: 'Cashier',
    );

ExpenseRecord _expense(DateTime createdAt, {bool drawer = true}) =>
    ExpenseRecord(
      title: 'Expense',
      category: 'Other',
      amount: 10,
      date: DateTime(createdAt.year, createdAt.month, createdAt.day),
      paymentMethod: 'Cash',
      paidFromDrawer: drawer,
      notes: '',
      status: ExpenseStatus.active,
      createdAt: createdAt,
    );

void main() {
  test('drawer deducts change and excludes previous shift expenses', () async {
    final start = DateTime(2026, 1, 1, 12);
    final summary = await DaySessionService.instance.buildSummary(
      repository: _Invoices([
        _invoice(start, 150, 0),
        _invoice(start, 80, 40),
        _invoice(start, 0, 100),
        _invoice(start.subtract(const Duration(hours: 1)), 100, 0),
      ]),
      expenseRepository: _Expenses([
        _expense(start.subtract(const Duration(hours: 1))),
        _expense(start),
        _expense(start, drawer: false),
        _expense(start).copyWith(status: ExpenseStatus.inactive),
      ]),
      session: DrawerSessionState(
        isActive: true,
        startedAt: start,
        openingCash: 50,
        cashierName: 'Cashier',
      ),
    );

    expect(summary.invoiceCount, 3);
    expect(summary.cashSales, 160);
    expect(summary.cardSales, 140);
    expect(summary.totalSales, 300);
    expect(summary.drawerExpenseTotal, 10);
    expect(summary.expectedDrawerAmount, 200);
  });
}
