import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import 'expense_local_repository.dart';
import '../models/models.dart';
import 'customer_local_repository.dart';
import 'product_local_repository.dart';
import 'report_repository.dart';
import 'stock_local_repository.dart';

class ReportLocalRepository implements ReportRepository {
  const ReportLocalRepository();

  Future<void> initialize() async {
    await const ProductLocalRepository().initialize();
    await const StockLocalRepository().initialize();
    await const CustomerLocalRepository().initialize();
    await const ExpenseLocalRepository().initialize();
  }

  Future<ReportDashboardData> fetchDashboardData({
    required DateTime fromDate,
    required DateTime toDate,
    required ReportSalesPeriod salesPeriod,
  }) async {
    final isar = await AppDatabase.instance;
    final normalizedFrom = DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
    );
    final normalizedTo = DateTime(
      toDate.year,
      toDate.month,
      toDate.day,
      23,
      59,
      59,
      999,
    );

    final invoices = await isar.invoiceEntitys.where().anyId().findAll();
    final products = await isar.productEntitys.where().findAll();
    final stocks = await isar.stockEntitys.where().findAll();
    final expenses = await isar.expenseEntitys.where().findAll();

    final filteredInvoices =
        invoices
            .where(
              (invoice) =>
                  !invoice.issuedAt.isBefore(normalizedFrom) &&
                  !invoice.issuedAt.isAfter(normalizedTo),
            )
            .toList()
          ..sort((left, right) => left.issuedAt.compareTo(right.issuedAt));

    final activeProducts = products
        .where((product) => product.status == ProductEntityStatus.active)
        .length;
    final filteredExpenses =
        expenses
            .where((expense) => expense.status == ExpenseEntityStatus.active)
            .where(
              (expense) =>
                  !expense.expenseDate.isBefore(normalizedFrom) &&
                  !expense.expenseDate.isAfter(normalizedTo),
            )
            .toList()
          ..sort(
            (left, right) => right.expenseDate.compareTo(left.expenseDate),
          );

    final summary = ReportSummaryData(
      totalRevenue: filteredInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.totalAmount,
      ),
      totalTax: filteredInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.tax,
      ),
      totalOrders: filteredInvoices.length,
      averageOrderValue: filteredInvoices.isEmpty
          ? 0
          : filteredInvoices.fold<double>(
                  0,
                  (sum, invoice) => sum + invoice.totalAmount,
                ) /
                filteredInvoices.length,
      stockValue: stocks
          .where((stock) => stock.status == StockEntityStatus.active)
          .fold<double>(
            0,
            (sum, stock) =>
                sum + (stock.availableQuantity * stock.sellingPrice),
          ),
      activeProducts: activeProducts,
      lowStockItemsCount: _buildLowStockRows(products, stocks).length,
    );

    return ReportDashboardData(
      summary: summary,
      salesPeriod: salesPeriod,
      salesPoints: _buildSalesPoints(
        filteredInvoices,
        normalizedFrom,
        normalizedTo,
        salesPeriod,
      ),
      taxPoints: _buildTaxPoints(
        filteredInvoices,
        normalizedFrom,
        normalizedTo,
        salesPeriod,
      ),
      productSales: _buildProductSalesRows(filteredInvoices),
      categorySales: _buildCategorySalesRows(filteredInvoices, products),
      lowStockRows: _buildLowStockRows(products, stocks),
      stockValuationRows: _buildStockValuationRows(products, stocks),
      topCustomers: _buildTopCustomers(filteredInvoices),
      expenses: filteredExpenses.map(_mapExpenseEntityToRecord).toList(),
      totalExpenseAmount: filteredExpenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      ),
      fromDate: normalizedFrom,
      toDate: normalizedTo,
      fromDateLabel: _formatDisplayDate(normalizedFrom),
      toDateLabel: _formatDisplayDate(normalizedTo),
    );
  }

  ExpenseRecord _mapExpenseEntityToRecord(ExpenseEntity entity) {
    return ExpenseRecord(
      id: entity.id,
      cloudId: null,
      title: entity.title,
      category: entity.category,
      amount: entity.amount,
      date: entity.expenseDate,
      paymentMethod: entity.paymentMethod,
      paidFromDrawer: entity.paidFromDrawer,
      notes: entity.notes,
      status: entity.status == ExpenseEntityStatus.active
          ? ExpenseStatus.active
          : ExpenseStatus.inactive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  List<ReportSalesPoint> _buildSalesPoints(
    List<InvoiceEntity> invoices,
    DateTime fromDate,
    DateTime toDate,
    ReportSalesPeriod period,
  ) {
    return _buildPeriodPoints(
      invoices: invoices,
      fromDate: fromDate,
      toDate: toDate,
      period: period,
      selector: (invoice) => invoice.totalAmount,
    );
  }

  List<ReportSalesPoint> _buildTaxPoints(
    List<InvoiceEntity> invoices,
    DateTime fromDate,
    DateTime toDate,
    ReportSalesPeriod period,
  ) {
    return _buildPeriodPoints(
      invoices: invoices,
      fromDate: fromDate,
      toDate: toDate,
      period: period,
      selector: (invoice) => invoice.tax,
    );
  }

  List<ReportSalesPoint> _buildPeriodPoints({
    required List<InvoiceEntity> invoices,
    required DateTime fromDate,
    required DateTime toDate,
    required ReportSalesPeriod period,
    required double Function(InvoiceEntity invoice) selector,
  }) {
    final totals = <String, double>{};
    final labels = <String, String>{};

    for (final invoice in invoices) {
      final bucket = _bucketKey(invoice.issuedAt, period);
      totals.update(
        bucket,
        (value) => value + selector(invoice),
        ifAbsent: () => selector(invoice),
      );
      labels[bucket] = _bucketLabel(invoice.issuedAt, period);
    }

    final points = <ReportSalesPoint>[];
    for (
      var cursor = _bucketStart(fromDate, period);
      !cursor.isAfter(toDate);
      cursor = _nextBucket(cursor, period)
    ) {
      final key = _bucketKey(cursor, period);
      points.add(
        ReportSalesPoint(
          label: labels[key] ?? _bucketLabel(cursor, period),
          value: totals[key] ?? 0,
        ),
      );
    }
    return points;
  }

  List<ReportProductSalesRow> _buildProductSalesRows(
    List<InvoiceEntity> invoices,
  ) {
    final totals = <String, ({int qty, double total})>{};
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        final name = item.name.trim().isEmpty
            ? 'Unknown Product'
            : item.name.trim();
        final current = totals[name] ?? (qty: 0, total: 0.0);
        totals[name] = (
          qty: current.qty + item.quantity,
          total: current.total + item.subtotal,
        );
      }
    }

    final rows =
        totals.entries
            .map(
              (entry) => ReportProductSalesRow(
                product: entry.key,
                quantity: entry.value.qty,
                totalSales: entry.value.total,
              ),
            )
            .toList()
          ..sort((left, right) => right.totalSales.compareTo(left.totalSales));
    return rows;
  }

  List<ReportCategorySalesRow> _buildCategorySalesRows(
    List<InvoiceEntity> invoices,
    List<ProductEntity> products,
  ) {
    final categoryByProduct = <String, String>{
      for (final product in products)
        product.name.toLowerCase(): product.category,
    };
    final totals = <String, ({int qty, double total})>{};

    for (final invoice in invoices) {
      for (final item in invoice.items) {
        final category =
            categoryByProduct[item.name.trim().toLowerCase()] ?? 'Other';
        final current = totals[category] ?? (qty: 0, total: 0.0);
        totals[category] = (
          qty: current.qty + item.quantity,
          total: current.total + item.subtotal,
        );
      }
    }

    final rows =
        totals.entries
            .map(
              (entry) => ReportCategorySalesRow(
                category: entry.key,
                quantity: entry.value.qty,
                totalSales: entry.value.total,
              ),
            )
            .toList()
          ..sort((left, right) => right.totalSales.compareTo(left.totalSales));
    return rows;
  }

  List<ReportLowStockRow> _buildLowStockRows(
    List<ProductEntity> products,
    List<StockEntity> stocks,
  ) {
    final productsByName = <String, ProductEntity>{
      for (final product in products) product.name.toLowerCase(): product,
    };

    final rows =
        stocks
            .where((stock) => stock.status == StockEntityStatus.active)
            .map((stock) {
              final product = productsByName[stock.productName.toLowerCase()];
              final minimumRequired = product?.lowStockQuantity ?? 0;
              return ReportLowStockRow(
                product: stock.productName,
                currentStock: stock.availableQuantity,
                minimumRequired: minimumRequired,
                status: stock.availableQuantity <= 0
                    ? 'Critical'
                    : stock.availableQuantity <= (minimumRequired / 2).ceil()
                    ? 'Critical'
                    : 'Warning',
              );
            })
            .where((row) => row.currentStock <= row.minimumRequired)
            .toList()
          ..sort(
            (left, right) => left.currentStock.compareTo(right.currentStock),
          );

    return rows;
  }

  List<ReportStockValuationRow> _buildStockValuationRows(
    List<ProductEntity> products,
    List<StockEntity> stocks,
  ) {
    final productsByName = <String, ProductEntity>{
      for (final product in products) product.name.toLowerCase(): product,
    };
    final totals = <String, ({int items, double value})>{};

    for (final stock in stocks) {
      if (stock.status != StockEntityStatus.active ||
          stock.availableQuantity <= 0) {
        continue;
      }

      final category =
          productsByName[stock.productName.toLowerCase()]?.category ?? 'Other';
      final current = totals[category] ?? (items: 0, value: 0.0);
      totals[category] = (
        items: current.items + stock.availableQuantity,
        value: current.value + (stock.availableQuantity * stock.sellingPrice),
      );
    }

    final rows =
        totals.entries
            .map(
              (entry) => ReportStockValuationRow(
                category: entry.key,
                totalItems: entry.value.items,
                totalValue: entry.value.value,
              ),
            )
            .toList()
          ..sort((left, right) => right.totalValue.compareTo(left.totalValue));

    return rows;
  }

  List<ReportTopCustomerRow> _buildTopCustomers(List<InvoiceEntity> invoices) {
    final totals = <String, ({int orders, double total})>{};

    for (final invoice in invoices) {
      final key = invoice.customerName.trim().isEmpty
          ? 'Walk-in Customer'
          : invoice.customerName.trim();
      final current = totals[key] ?? (orders: 0, total: 0.0);
      totals[key] = (
        orders: current.orders + 1,
        total: current.total + invoice.totalAmount,
      );
    }

    final rows =
        totals.entries
            .map(
              (entry) => ReportTopCustomerRow(
                rank: 0,
                customer: entry.key,
                orders: entry.value.orders,
                totalSpent: entry.value.total,
                averageOrder: entry.value.total / entry.value.orders,
              ),
            )
            .toList()
          ..sort((left, right) => right.totalSpent.compareTo(left.totalSpent));

    return [
      for (var i = 0; i < rows.length && i < 5; i++)
        ReportTopCustomerRow(
          rank: i + 1,
          customer: rows[i].customer,
          orders: rows[i].orders,
          totalSpent: rows[i].totalSpent,
          averageOrder: rows[i].averageOrder,
        ),
    ];
  }

  String _formatDisplayDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
  }

  String _formatAxisDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _bucketStart(DateTime date, ReportSalesPeriod period) {
    switch (period) {
      case ReportSalesPeriod.daily:
        return DateTime(date.year, date.month, date.day);
      case ReportSalesPeriod.weekly:
        final normalized = DateTime(date.year, date.month, date.day);
        return normalized.subtract(Duration(days: normalized.weekday - 1));
      case ReportSalesPeriod.monthly:
        return DateTime(date.year, date.month);
      case ReportSalesPeriod.yearly:
        return DateTime(date.year);
    }
  }

  DateTime _nextBucket(DateTime date, ReportSalesPeriod period) {
    switch (period) {
      case ReportSalesPeriod.daily:
        return date.add(const Duration(days: 1));
      case ReportSalesPeriod.weekly:
        return date.add(const Duration(days: 7));
      case ReportSalesPeriod.monthly:
        return DateTime(date.year, date.month + 1);
      case ReportSalesPeriod.yearly:
        return DateTime(date.year + 1);
    }
  }

  String _bucketKey(DateTime date, ReportSalesPeriod period) {
    final bucket = _bucketStart(date, period);
    return '${bucket.year}-${bucket.month}-${bucket.day}';
  }

  String _bucketLabel(DateTime date, ReportSalesPeriod period) {
    switch (period) {
      case ReportSalesPeriod.daily:
        return _formatAxisDate(date);
      case ReportSalesPeriod.weekly:
        final start = _bucketStart(date, period);
        return 'Wk ${start.month}/${start.day}';
      case ReportSalesPeriod.monthly:
        const months = <String>[
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[date.month - 1]} ${date.year}';
      case ReportSalesPeriod.yearly:
        return date.year.toString();
    }
  }
}
