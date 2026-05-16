import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'customer_local_repository.dart';
import 'expense_local_repository.dart';
import 'grn_local_repository.dart';
import 'insight_repository.dart';
import 'product_local_repository.dart';
import 'stock_local_repository.dart';

class InsightLocalRepository implements InsightRepository {
  const InsightLocalRepository();

  Future<void> initialize() async {
    await const ProductLocalRepository().initialize();
    await const StockLocalRepository().initialize();
    await const CustomerLocalRepository().initialize();
    await const GrnLocalRepository().initialize();
    await const ExpenseLocalRepository().initialize();
  }

  Future<InsightDashboardData> fetchDashboardData({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final isar = await AppDatabase.instance;
    final invoices = await isar.invoiceEntitys.where().anyId().findAll();
    final products = await isar.productEntitys.where().findAll();
    final customers = await isar.customerEntitys.where().findAll();
    final stocks = await isar.stockEntitys.where().findAll();
    final grns = await isar.grnEntitys.where().findAll();
    final expenses = await isar.expenseEntitys.where().findAll();
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

    final totalSales = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );
    final totalPurchase = grns.fold<double>(0, (sum, grn) => sum + grn.total);
    final activeExpenses = expenses
        .where((expense) => expense.status == ExpenseEntityStatus.active)
        .toList();
    final totalExpenses = activeExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final totalOrders = invoices.length;
    final activeProducts = products
        .where((product) => product.status == ProductEntityStatus.active)
        .length;
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

    final salesPoints = _buildSalesPoints(
      invoices,
      fromDate: rangeFrom,
      toDate: rangeTo,
    );
    final categoryAllocation = _buildCategoryAllocation(products, stocks);
    final lowStockItems = _buildLowStockItems(products, stocks);
    final expiredStockItems = _buildExpiredStockItems(stocks);
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
      totalPurchase: totalPurchase,
      totalExpenses: totalExpenses,
      totalOrders: totalOrders,
      activeProducts: activeProducts,
      totalCustomers: totalCustomers,
      salesGrowthNote: _buildGrowthNote(
        currentValue: currentMonthSales,
        previousValue: previousMonthSales,
        suffix: 'from last month',
        emptyFallback: 'No sales last month',
        prefix: '',
      ),
      purchasesNote: grns.isEmpty
          ? 'No purchase records yet'
          : '${grns.length} GRNs recorded',
      expensesNote: activeExpenses.isEmpty
          ? 'No active expenses recorded'
          : '${activeExpenses.length} active expenses',
      ordersGrowthNote: _buildGrowthNote(
        currentValue: currentMonthOrders.toDouble(),
        previousValue: previousMonthOrders.toDouble(),
        suffix: 'from last month',
        emptyFallback: 'No orders last month',
        prefix: '',
      ),
      productsNote: 'Across $categoriesCount categories',
      customersNote: customersCreatedThisMonth == 0
          ? 'No new customers this month'
          : '+$customersCreatedThisMonth new customers',
      salesPoints: salesPoints,
      chartDateFromLabel: _formatChartDate(rangeFrom),
      chartDateToLabel: _formatChartDate(rangeTo),
      categoryAllocation: categoryAllocation,
      lowStockItems: lowStockItems,
      expiredStockItems: expiredStockItems,
    );
  }

  Future<void> deactivateExpiredStock(InsightExpiredStockItem item) async {
    final isar = await AppDatabase.instance;
    final stock = await isar.stockEntitys.get(item.id);
    if (stock == null) {
      return;
    }

    stock
      ..status = StockEntityStatus.inactive
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.stockEntitys.put(stock);
    });
  }

  List<InsightSalesPoint> _buildSalesPoints(
    List<InvoiceEntity> invoices, {
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
    List<ProductEntity> products,
    List<StockEntity> stocks,
  ) {
    final productByName = <String, ProductEntity>{
      for (final product in products) product.name.toLowerCase(): product,
    };
    final totals = <String, int>{};

    for (final stock in stocks) {
      if (stock.status != StockEntityStatus.active ||
          stock.availableQuantity <= 0) {
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
    List<ProductEntity> products,
    List<StockEntity> stocks,
  ) {
    final productByName = <String, ProductEntity>{
      for (final product in products) product.name.toLowerCase(): product,
    };

    final alerts = stocks
        .where((stock) => stock.status == StockEntityStatus.active)
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
    List<StockEntity> stocks,
  ) {
    final today = DateTime.now();
    final dateOnlyToday = DateTime(today.year, today.month, today.day);

    final expired =
        stocks
            .where((stock) => stock.status == StockEntityStatus.active)
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
            id: stock.id,
            cloudId: null,
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
    String prefix = '',
  }) {
    if (previousValue <= 0) {
      return currentValue > 0 ? '+100.0% $suffix' : emptyFallback;
    }

    final growth = ((currentValue - previousValue) / previousValue) * 100;
    final sign = growth >= 0 ? '+' : '';
    return '$prefix$sign${growth.toStringAsFixed(1)}% $suffix';
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
