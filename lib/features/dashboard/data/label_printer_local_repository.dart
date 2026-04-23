import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'label_printer_repository.dart';

class LabelPrinterLocalRepository implements LabelPrinterRepository {
  const LabelPrinterLocalRepository();

  static const int pageSize = 10;

  @override
  Future<void> initialize() async {
    await AppDatabase.instance;
  }

  @override
  Future<LabelPrinterPageResult> fetchItems({
    required LabelPrinterSource source,
    required int page,
    String? searchQuery,
  }) async {
    final isar = await AppDatabase.instance;
    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';

    if (source == LabelPrinterSource.product) {
      final products = await isar.productEntitys.where().findAll()
        ..sort((left, right) {
          final leftDate = left.updatedAt ?? left.createdAt;
          final rightDate = right.updatedAt ?? right.createdAt;
          return rightDate.compareTo(leftDate);
        });

      final filtered = products
          .where((product) => product.status == ProductEntityStatus.active)
          .where((product) {
            if (normalizedQuery.isEmpty) {
              return true;
            }

            return product.name.toLowerCase().contains(normalizedQuery) ||
                product.barcode.toLowerCase().contains(normalizedQuery) ||
                product.category.toLowerCase().contains(normalizedQuery);
          })
          .map(
            (product) => LabelPrinterItem(
              source: LabelPrinterSource.product,
              id: '${product.id}',
              title: product.name,
              barcode: product.barcode,
              secondaryText: '${product.category} • ${product.unit}',
            ),
          )
          .toList();

      return _buildPage(items: filtered, page: page);
    }

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final stocks = await isar.stockEntitys.where().findAll()
      ..sort((left, right) {
        final leftDate = left.updatedAt ?? left.createdAt;
        final rightDate = right.updatedAt ?? right.createdAt;
        return rightDate.compareTo(leftDate);
      });

    final filtered = stocks
        .where((stock) => stock.status == StockEntityStatus.active)
        .where((stock) => stock.availableQuantity > 0)
        .where(
          (stock) =>
              stock.expiryDate == null ||
              !stock.expiryDate!.isBefore(startOfToday),
        )
        .where((stock) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return stock.productName.toLowerCase().contains(normalizedQuery) ||
              stock.barcode.toLowerCase().contains(normalizedQuery) ||
              (stock.productBarcode ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              (stock.grnCode ?? '').toLowerCase().contains(normalizedQuery);
        })
        .map(
          (stock) => LabelPrinterItem(
            source: LabelPrinterSource.stock,
            id: '${stock.id}',
            title: stock.productName,
            barcode: stock.barcode,
            productBarcode: stock.productBarcode,
            secondaryText:
                'Product Barcode: ${stock.productBarcode ?? 'N/A'} • GRN: ${stock.grnCode ?? 'Not Assigned'}',
            quantity: stock.availableQuantity,
          ),
        )
        .toList();

    return _buildPage(items: filtered, page: page);
  }

  LabelPrinterPageResult _buildPage({
    required List<LabelPrinterItem> items,
    required int page,
  }) {
    final totalCount = items.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <LabelPrinterItem>[]
        : items.sublist(start, end);

    return LabelPrinterPageResult(
      items: pageItems,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }
}
