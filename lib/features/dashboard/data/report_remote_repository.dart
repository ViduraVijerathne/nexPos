import 'package:cloud_firestore/cloud_firestore.dart';

import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'report_repository.dart';

class ReportRemoteRepositoryException implements Exception {
  ReportRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReportRemoteRepository implements ReportRepository {
  ReportRemoteRepository({required this.shopId});

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _invoicesRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('invoices');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _stocksRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('stocks');

  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('expenses');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw ReportRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<ReportDashboardData> fetchDashboardData({
    required DateTime fromDate,
    required DateTime toDate,
    required ReportSalesPeriod salesPeriod,
  }) async {
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

    final invoicesSnapshot = await _invoicesRef.get();
    final productsSnapshot = await _productsRef.get();
    final stocksSnapshot = await _stocksRef.get();
    final expensesSnapshot = await _expensesRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'reports',
      documentCount:
          invoicesSnapshot.docs.length +
          productsSnapshot.docs.length +
          stocksSnapshot.docs.length +
          expensesSnapshot.docs.length,
      payload: <Object?>[
        invoicesSnapshot.docs.map((doc) => doc.data()).toList(),
        productsSnapshot.docs.map((doc) => doc.data()).toList(),
        stocksSnapshot.docs.map((doc) => doc.data()).toList(),
        expensesSnapshot.docs.map((doc) => doc.data()).toList(),
      ],
    );

    final invoices = invoicesSnapshot.docs
        .map((doc) => _ReportInvoiceRecord.fromMap(doc.data()))
        .toList();
    final products = productsSnapshot.docs
        .map((doc) => _ReportProductRecord.fromMap(doc.data()))
        .toList();
    final stocks = stocksSnapshot.docs
        .map((doc) => _ReportStockRecord.fromMap(doc.data()))
        .toList();
    final expenses = expensesSnapshot.docs
        .map((doc) => _ReportExpenseRecord.fromMap(doc.id, doc.data()))
        .toList();

    final filteredInvoices =
        invoices
            .where(
              (invoice) =>
                  !invoice.issuedAt.isBefore(normalizedFrom) &&
                  !invoice.issuedAt.isAfter(normalizedTo),
            )
            .toList()
          ..sort((left, right) => left.issuedAt.compareTo(right.issuedAt));

    final lowStockRows = _buildLowStockRows(products, stocks);
    final filteredExpenses =
        expenses
            .where((expense) => expense.isActive)
            .where(
              (expense) =>
                  !expense.date.isBefore(normalizedFrom) &&
                  !expense.date.isAfter(normalizedTo),
            )
            .toList()
          ..sort((left, right) => right.date.compareTo(left.date));

    final summary = ReportSummaryData(
      totalRevenue: filteredInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.totalAmount,
      ),
      totalTax: filteredInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.taxAmount,
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
          .where((stock) => stock.isActive)
          .fold<double>(
            0,
            (sum, stock) =>
                sum + (stock.availableQuantity * stock.sellingPrice),
          ),
      activeProducts: products.where((product) => product.isActive).length,
      lowStockItemsCount: lowStockRows.length,
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
      lowStockRows: lowStockRows,
      stockValuationRows: _buildStockValuationRows(products, stocks),
      topCustomers: _buildTopCustomers(filteredInvoices),
      expenses: filteredExpenses.map((expense) => expense.toRecord()).toList(),
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

  List<ReportSalesPoint> _buildSalesPoints(
    List<_ReportInvoiceRecord> invoices,
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
    List<_ReportInvoiceRecord> invoices,
    DateTime fromDate,
    DateTime toDate,
    ReportSalesPeriod period,
  ) {
    return _buildPeriodPoints(
      invoices: invoices,
      fromDate: fromDate,
      toDate: toDate,
      period: period,
      selector: (invoice) => invoice.taxAmount,
    );
  }

  List<ReportSalesPoint> _buildPeriodPoints({
    required List<_ReportInvoiceRecord> invoices,
    required DateTime fromDate,
    required DateTime toDate,
    required ReportSalesPeriod period,
    required double Function(_ReportInvoiceRecord invoice) selector,
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
    List<_ReportInvoiceRecord> invoices,
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
    List<_ReportInvoiceRecord> invoices,
    List<_ReportProductRecord> products,
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
    List<_ReportProductRecord> products,
    List<_ReportStockRecord> stocks,
  ) {
    final productsByName = <String, _ReportProductRecord>{
      for (final product in products) product.name.toLowerCase(): product,
    };

    final rows =
        stocks
            .where((stock) => stock.isActive)
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
    List<_ReportProductRecord> products,
    List<_ReportStockRecord> stocks,
  ) {
    final productsByName = <String, _ReportProductRecord>{
      for (final product in products) product.name.toLowerCase(): product,
    };
    final totals = <String, ({int items, double value})>{};

    for (final stock in stocks) {
      if (!stock.isActive || stock.availableQuantity <= 0) {
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

  List<ReportTopCustomerRow> _buildTopCustomers(
    List<_ReportInvoiceRecord> invoices,
  ) {
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

class _ReportInvoiceRecord {
  const _ReportInvoiceRecord({
    required this.customerName,
    required this.issuedAt,
    required this.totalAmount,
    required this.taxAmount,
    required this.items,
  });

  final String customerName;
  final DateTime issuedAt;
  final double totalAmount;
  final double taxAmount;
  final List<_ReportInvoiceItemRecord> items;

  factory _ReportInvoiceRecord.fromMap(Map<String, dynamic> data) {
    final totalAmount =
        (data['totalAmount'] as num?)?.toDouble() ??
        (data['amount'] as num?)?.toDouble() ??
        0;
    final subTotal = (data['subTotal'] as num?)?.toDouble();
    final taxAmount =
        (data['taxAmount'] as num?)?.toDouble() ??
        (subTotal == null ? 0 : totalAmount - subTotal);

    return _ReportInvoiceRecord(
      customerName: data['customerName']?.toString() ?? 'Walk-in Customer',
      issuedAt: _readReportDate(
        data['issuedAt'] ?? data['date'] ?? data['createdAt'],
      ),
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      items: (data['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => _ReportInvoiceItemRecord.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class _ReportInvoiceItemRecord {
  const _ReportInvoiceItemRecord({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  double get subtotal => quantity * unitPrice;

  factory _ReportInvoiceItemRecord.fromMap(Map<String, dynamic> data) {
    return _ReportInvoiceItemRecord(
      name: data['name']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _ReportProductRecord {
  const _ReportProductRecord({
    required this.name,
    required this.category,
    required this.lowStockQuantity,
    required this.isActive,
  });

  final String name;
  final String category;
  final int lowStockQuantity;
  final bool isActive;

  factory _ReportProductRecord.fromMap(Map<String, dynamic> data) {
    return _ReportProductRecord(
      name: data['name']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Other',
      lowStockQuantity: (data['lowStockQuantity'] as num?)?.toInt() ?? 0,
      isActive: (data['status']?.toString() ?? 'active') == 'active',
    );
  }
}

class _ReportStockRecord {
  const _ReportStockRecord({
    required this.productName,
    required this.availableQuantity,
    required this.sellingPrice,
    required this.isActive,
  });

  final String productName;
  final int availableQuantity;
  final double sellingPrice;
  final bool isActive;

  factory _ReportStockRecord.fromMap(Map<String, dynamic> data) {
    return _ReportStockRecord(
      productName: data['productName']?.toString() ?? '',
      availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      isActive: (data['status']?.toString() ?? 'active') == 'active',
    );
  }
}

class _ReportExpenseRecord {
  const _ReportExpenseRecord({
    required this.cloudId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.paidFromDrawer,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String cloudId;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final bool paidFromDrawer;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory _ReportExpenseRecord.fromMap(
    String cloudId,
    Map<String, dynamic> data,
  ) {
    final date = _readReportDate(
      data['expenseDate'] ?? data['date'] ?? data['createdAt'],
    );
    final createdAt = _readReportDate(data['createdAt'] ?? data['expenseDate']);
    return _ReportExpenseRecord(
      cloudId: cloudId,
      title: data['title']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: date,
      paymentMethod: data['paymentMethod']?.toString() ?? 'Cash',
      paidFromDrawer: data['paidFromDrawer'] == true,
      notes: data['notes']?.toString() ?? '',
      isActive: (data['status']?.toString() ?? 'active') == 'active',
      createdAt: createdAt,
      updatedAt: _readNullableReportDate(data['updatedAt']),
    );
  }

  ExpenseRecord toRecord() {
    return ExpenseRecord(
      id: null,
      cloudId: cloudId,
      title: title,
      category: category,
      amount: amount,
      date: date,
      paymentMethod: paymentMethod,
      paidFromDrawer: paidFromDrawer,
      notes: notes,
      status: isActive ? ExpenseStatus.active : ExpenseStatus.inactive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

DateTime _readReportDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _readNullableReportDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
