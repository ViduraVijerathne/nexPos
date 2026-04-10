import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'insight_repository.dart';

class InsightRemoteRepositoryException implements Exception {
  InsightRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InsightRemoteRepository implements InsightRepository {
  InsightRemoteRepository({required this.shopId});

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

  CollectionReference<Map<String, dynamic>> get _customersRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('customers');

  CollectionReference<Map<String, dynamic>> get _stocksRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('stocks');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw InsightRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<InsightDashboardData> fetchDashboardData({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final normalizedFrom = fromDate == null
        ? DateTime.now().subtract(const Duration(days: 6))
        : DateTime(fromDate.year, fromDate.month, fromDate.day);
    final normalizedTo = toDate == null
        ? DateTime.now()
        : DateTime(toDate.year, toDate.month, toDate.day);
    final rangeFrom = normalizedFrom.isAfter(normalizedTo)
        ? normalizedTo
        : normalizedFrom;
    final rangeTo = normalizedTo.isBefore(normalizedFrom)
        ? normalizedFrom
        : normalizedTo;

    final invoicesSnapshot = await _invoicesRef.get();
    final productsSnapshot = await _productsRef.get();
    final customersSnapshot = await _customersRef.get();
    final stocksSnapshot = await _stocksRef.get();

    final invoices = invoicesSnapshot.docs
        .map((doc) => _InvoiceAnalyticsRecord.fromMap(doc.data()))
        .toList();
    final products = productsSnapshot.docs
        .map((doc) => _ProductAnalyticsRecord.fromMap(doc.id, doc.data()))
        .toList();
    final customers = customersSnapshot.docs
        .map((doc) => _CustomerAnalyticsRecord.fromMap(doc.data()))
        .toList();
    final stocks = stocksSnapshot.docs
        .map((doc) => _StockAnalyticsRecord.fromMap(doc.id, doc.data()))
        .toList();

    final totalSales = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );
    final totalOrders = invoices.length;
    final activeProducts = products.where((product) => product.isActive).length;
    final totalCustomers = customers.length;

    final currentMonthStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );
    final previousMonthStart = DateTime(
      currentMonthStart.month == 1
          ? currentMonthStart.year - 1
          : currentMonthStart.year,
      currentMonthStart.month == 1 ? 12 : currentMonthStart.month - 1,
    );
    final previousMonthEnd = currentMonthStart.subtract(
      const Duration(days: 1),
    );

    final currentMonthInvoices = invoices.where(
      (invoice) => !invoice.issuedAt.isBefore(currentMonthStart),
    );
    final previousMonthInvoices = invoices.where(
      (invoice) =>
          !invoice.issuedAt.isBefore(previousMonthStart) &&
          !invoice.issuedAt.isAfter(previousMonthEnd),
    );

    final currentMonthSales = currentMonthInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );
    final previousMonthSales = previousMonthInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );
    final currentMonthOrders = currentMonthInvoices.length;
    final previousMonthOrders = previousMonthInvoices.length;

    final categoriesCount = products
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .length;
    final customersCreatedThisMonth = customers
        .where((customer) => !customer.createdAt.isBefore(currentMonthStart))
        .length;

    return InsightDashboardData(
      totalSales: totalSales,
      totalOrders: totalOrders,
      activeProducts: activeProducts,
      totalCustomers: totalCustomers,
      salesGrowthNote: _buildGrowthNote(
        currentValue: currentMonthSales,
        previousValue: previousMonthSales,
        suffix: 'from last month',
        emptyFallback: 'No sales last month',
      ),
      ordersGrowthNote: _buildGrowthNote(
        currentValue: currentMonthOrders.toDouble(),
        previousValue: previousMonthOrders.toDouble(),
        suffix: 'from last month',
        emptyFallback: 'No orders last month',
      ),
      productsNote: 'Across $categoriesCount categories',
      customersNote: customersCreatedThisMonth == 0
          ? 'No new customers this month'
          : '+$customersCreatedThisMonth new customers',
      salesPoints: _buildSalesPoints(
        invoices,
        fromDate: rangeFrom,
        toDate: rangeTo,
      ),
      chartDateFromLabel: _formatChartDate(rangeFrom),
      chartDateToLabel: _formatChartDate(rangeTo),
      categoryAllocation: _buildCategoryAllocation(products, stocks),
      lowStockItems: _buildLowStockItems(products, stocks),
      expiredStockItems: _buildExpiredStockItems(stocks),
    );
  }

  @override
  Future<void> deactivateExpiredStock(InsightExpiredStockItem item) async {
    final cloudId = item.cloudId;
    if (cloudId == null || cloudId.isEmpty) {
      throw InsightRemoteRepositoryException(
        'Expired stock identifier is missing',
      );
    }

    await _stocksRef.doc(cloudId).update({
      'status': 'inactive',
      'updatedAt': DateTime.now(),
    });
  }

  List<InsightSalesPoint> _buildSalesPoints(
    List<_InvoiceAnalyticsRecord> invoices, {
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final points = <InsightSalesPoint>[];

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
      points.add(
        InsightSalesPoint(label: _formatChartAxis(date), value: total),
      );
    }

    return points;
  }

  List<InsightCategoryAllocation> _buildCategoryAllocation(
    List<_ProductAnalyticsRecord> products,
    List<_StockAnalyticsRecord> stocks,
  ) {
    final productByName = <String, _ProductAnalyticsRecord>{
      for (final product in products) product.name.toLowerCase(): product,
    };
    final totals = <String, int>{};

    for (final stock in stocks) {
      if (!stock.isActive || stock.availableQuantity <= 0) {
        continue;
      }
      final category =
          productByName[stock.productName.toLowerCase()]?.category ?? 'Other';
      totals.update(
        category,
        (value) => value + stock.availableQuantity,
        ifAbsent: () => stock.availableQuantity,
      );
    }

    final totalQty = totals.values.fold<int>(0, (sum, value) => sum + value);
    if (totalQty == 0) {
      return const <InsightCategoryAllocation>[];
    }

    final allocations =
        totals.entries
            .map(
              (entry) => InsightCategoryAllocation(
                label: entry.key,
                percentage: (entry.value / totalQty) * 100,
              ),
            )
            .toList()
          ..sort((left, right) => right.percentage.compareTo(left.percentage));

    return allocations.take(5).toList();
  }

  List<InsightLowStockItem> _buildLowStockItems(
    List<_ProductAnalyticsRecord> products,
    List<_StockAnalyticsRecord> stocks,
  ) {
    final productByName = <String, _ProductAnalyticsRecord>{
      for (final product in products) product.name.toLowerCase(): product,
    };

    final alerts = stocks
        .where((stock) => stock.isActive)
        .where((stock) {
          final lowStockLimit =
              productByName[stock.productName.toLowerCase()]
                  ?.lowStockQuantity ??
              5;
          return stock.availableQuantity <= lowStockLimit;
        })
        .map((stock) {
          final lowStockLimit =
              productByName[stock.productName.toLowerCase()]
                  ?.lowStockQuantity ??
              5;
          return InsightLowStockItem(
            name: stock.productName,
            status: stock.availableQuantity == 0
                ? 'Out of Stock'
                : stock.availableQuantity <= (lowStockLimit / 2).ceil()
                ? 'Low Stock'
                : 'Running Low',
          );
        })
        .toList();

    return alerts.take(5).toList();
  }

  List<InsightExpiredStockItem> _buildExpiredStockItems(
    List<_StockAnalyticsRecord> stocks,
  ) {
    final today = DateTime.now();
    final dateOnlyToday = DateTime(today.year, today.month, today.day);

    final expired =
        stocks
            .where((stock) => stock.isActive)
            .where((stock) => stock.expiryDate != null)
            .where((stock) {
              final expiry = stock.expiryDate!;
              final dateOnly = DateTime(expiry.year, expiry.month, expiry.day);
              return !dateOnly.isAfter(dateOnlyToday);
            })
            .toList()
          ..sort(
            (left, right) => left.expiryDate!.compareTo(right.expiryDate!),
          );

    return expired
        .map(
          (stock) => InsightExpiredStockItem(
            id: 0,
            cloudId: stock.cloudId,
            name: stock.productName,
            barcode: stock.barcode,
            expiryDate: _formatExpiryDate(stock.expiryDate!),
          ),
        )
        .take(6)
        .toList();
  }

  String _buildGrowthNote({
    required double currentValue,
    required double previousValue,
    required String suffix,
    required String emptyFallback,
  }) {
    if (previousValue <= 0) {
      return currentValue > 0 ? '+100.0% $suffix' : emptyFallback;
    }

    final growth = ((currentValue - previousValue) / previousValue) * 100;
    final sign = growth >= 0 ? '+' : '';
    return '$sign${growth.toStringAsFixed(1)}% $suffix';
  }

  String _formatChartAxis(DateTime date) {
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

  String _formatChartDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _formatExpiryDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _InvoiceAnalyticsRecord {
  const _InvoiceAnalyticsRecord({
    required this.issuedAt,
    required this.totalAmount,
  });

  final DateTime issuedAt;
  final double totalAmount;

  factory _InvoiceAnalyticsRecord.fromMap(Map<String, dynamic> data) {
    return _InvoiceAnalyticsRecord(
      issuedAt: _readDate(
        data['issuedAt'] ?? data['date'] ?? data['createdAt'],
      ),
      totalAmount:
          (data['totalAmount'] as num?)?.toDouble() ??
          (data['amount'] as num?)?.toDouble() ??
          0,
    );
  }
}

class _ProductAnalyticsRecord {
  const _ProductAnalyticsRecord({
    required this.cloudId,
    required this.name,
    required this.category,
    required this.lowStockQuantity,
    required this.isActive,
  });

  final String cloudId;
  final String name;
  final String category;
  final int lowStockQuantity;
  final bool isActive;

  factory _ProductAnalyticsRecord.fromMap(
    String cloudId,
    Map<String, dynamic> data,
  ) {
    return _ProductAnalyticsRecord(
      cloudId: cloudId,
      name: data['name']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Other',
      lowStockQuantity: (data['lowStockQuantity'] as num?)?.toInt() ?? 5,
      isActive: (data['status']?.toString() ?? 'active') == 'active',
    );
  }
}

class _CustomerAnalyticsRecord {
  const _CustomerAnalyticsRecord({required this.createdAt});

  final DateTime createdAt;

  factory _CustomerAnalyticsRecord.fromMap(Map<String, dynamic> data) {
    return _CustomerAnalyticsRecord(
      createdAt: _readDate(data['joinDate'] ?? data['createdAt']),
    );
  }
}

class _StockAnalyticsRecord {
  const _StockAnalyticsRecord({
    required this.cloudId,
    required this.productName,
    required this.barcode,
    required this.availableQuantity,
    required this.isActive,
    required this.expiryDate,
  });

  final String cloudId;
  final String productName;
  final String barcode;
  final int availableQuantity;
  final bool isActive;
  final DateTime? expiryDate;

  factory _StockAnalyticsRecord.fromMap(
    String cloudId,
    Map<String, dynamic> data,
  ) {
    return _StockAnalyticsRecord(
      cloudId: cloudId,
      productName: data['productName']?.toString() ?? '',
      barcode: data['barcode']?.toString() ?? '',
      availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
      isActive: (data['status']?.toString() ?? 'active') == 'active',
      expiryDate: _readNullableDate(data['expiryDate']),
    );
  }
}

DateTime _readDate(dynamic value) {
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

DateTime? _readNullableDate(dynamic value) {
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
