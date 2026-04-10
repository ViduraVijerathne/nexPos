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
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'reports',
      documentCount:
          invoicesSnapshot.docs.length +
          productsSnapshot.docs.length +
          stocksSnapshot.docs.length,
      payload: <Object?>[
        invoicesSnapshot.docs.map((doc) => doc.data()).toList(),
        productsSnapshot.docs.map((doc) => doc.data()).toList(),
        stocksSnapshot.docs.map((doc) => doc.data()).toList(),
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
      salesPoints: _buildSalesPoints(
        filteredInvoices,
        normalizedFrom,
        normalizedTo,
      ),
      taxPoints: _buildTaxPoints(
        filteredInvoices,
        normalizedFrom,
        normalizedTo,
      ),
      lowStockRows: lowStockRows,
      stockValuationRows: _buildStockValuationRows(products, stocks),
      topCustomers: _buildTopCustomers(filteredInvoices),
      fromDateLabel: _formatDisplayDate(normalizedFrom),
      toDateLabel: _formatDisplayDate(normalizedTo),
    );
  }

  List<ReportSalesPoint> _buildSalesPoints(
    List<_ReportInvoiceRecord> invoices,
    DateTime fromDate,
    DateTime toDate,
  ) {
    final points = <ReportSalesPoint>[];
    for (
      var date = DateTime(fromDate.year, fromDate.month, fromDate.day);
      !date.isAfter(toDate);
      date = date.add(const Duration(days: 1))
    ) {
      final total = invoices
          .where(
            (invoice) =>
                invoice.issuedAt.year == date.year &&
                invoice.issuedAt.month == date.month &&
                invoice.issuedAt.day == date.day,
          )
          .fold<double>(0, (sum, invoice) => sum + invoice.totalAmount);

      points.add(ReportSalesPoint(label: _formatAxisDate(date), value: total));
    }
    return points;
  }

  List<ReportSalesPoint> _buildTaxPoints(
    List<_ReportInvoiceRecord> invoices,
    DateTime fromDate,
    DateTime toDate,
  ) {
    final points = <ReportSalesPoint>[];
    for (
      var date = DateTime(fromDate.year, fromDate.month, fromDate.day);
      !date.isAfter(toDate);
      date = date.add(const Duration(days: 1))
    ) {
      final totalTax = invoices
          .where(
            (invoice) =>
                invoice.issuedAt.year == date.year &&
                invoice.issuedAt.month == date.month &&
                invoice.issuedAt.day == date.day,
          )
          .fold<double>(0, (sum, invoice) => sum + invoice.taxAmount);

      points.add(
        ReportSalesPoint(label: _formatAxisDate(date), value: totalTax),
      );
    }
    return points;
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
}

class _ReportInvoiceRecord {
  const _ReportInvoiceRecord({
    required this.customerName,
    required this.issuedAt,
    required this.totalAmount,
    required this.taxAmount,
  });

  final String customerName;
  final DateTime issuedAt;
  final double totalAmount;
  final double taxAmount;

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
