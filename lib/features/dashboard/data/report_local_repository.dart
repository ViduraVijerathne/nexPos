import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'customer_local_repository.dart';
import 'product_local_repository.dart';
import 'stock_local_repository.dart';

class ReportLocalRepository {
  const ReportLocalRepository();

  Future<void> initialize() async {
    await const ProductLocalRepository().initialize();
    await const StockLocalRepository().initialize();
    await const CustomerLocalRepository().initialize();
  }

  Future<ReportDashboardData> fetchDashboardData({
    required DateTime fromDate,
    required DateTime toDate,
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
      lowStockRows: _buildLowStockRows(products, stocks),
      stockValuationRows: _buildStockValuationRows(products, stocks),
      topCustomers: _buildTopCustomers(filteredInvoices),
      fromDateLabel: _formatDisplayDate(normalizedFrom),
      toDateLabel: _formatDisplayDate(normalizedTo),
    );
  }

  List<ReportSalesPoint> _buildSalesPoints(
    List<InvoiceEntity> invoices,
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
    List<InvoiceEntity> invoices,
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
          .fold<double>(0, (sum, invoice) => sum + invoice.tax);

      points.add(
        ReportSalesPoint(label: _formatAxisDate(date), value: totalTax),
      );
    }
    return points;
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
}
