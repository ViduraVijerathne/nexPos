import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/change_log_service.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'stock_repository.dart';

class StockLocalRepositoryException implements Exception {
  StockLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StockLocalRepository implements StockRepository {
  const StockLocalRepository();

  static const int pageSize = 10;

  Future<void> initialize() async {
    final isar = await AppDatabase.instance;
    await _seedIfNeeded(isar);
  }

  Future<StockPageResult> fetchStocks({
    required int page,
    String? barcodeQuery,
    String? productQuery,
    String? grnQuery,
    String? statusFilter,
    int? qtyLessThan,
    int? qtyGreaterThan,
  }) async {
    final isar = await AppDatabase.instance;
    final allStocks = await isar.stockEntitys.where().findAll()
      ..sort((left, right) {
        final leftDate = left.updatedAt ?? left.createdAt;
        final rightDate = right.updatedAt ?? right.createdAt;
        return rightDate.compareTo(leftDate);
      });

    final summary = StockSummary(
      totalStockItems: allStocks.length,
      activeStocks: allStocks
          .where((stock) => stock.status == StockEntityStatus.active)
          .length,
      lowStockItems: allStocks
          .where((stock) => stock.availableQuantity <= 5)
          .length,
      inactiveStocks: allStocks
          .where((stock) => stock.status == StockEntityStatus.inactive)
          .length,
    );

    final normalizedBarcode = barcodeQuery?.trim().toLowerCase() ?? '';
    final normalizedProduct = productQuery?.trim().toLowerCase() ?? '';
    final normalizedGrn = grnQuery?.trim().toLowerCase() ?? '';

    final filtered = allStocks.where((stock) {
      if (normalizedBarcode.isNotEmpty &&
          !stock.barcode.toLowerCase().contains(normalizedBarcode)) {
        return false;
      }
      if (normalizedProduct.isNotEmpty &&
          !stock.productName.toLowerCase().contains(normalizedProduct)) {
        return false;
      }
      if (normalizedGrn.isNotEmpty &&
          !(stock.grnCode ?? 'Not Assigned').toLowerCase().contains(
            normalizedGrn,
          )) {
        return false;
      }
      if (statusFilter != null &&
          statusFilter != 'All' &&
          _mapStatusFromEntity(stock.status).label != statusFilter) {
        return false;
      }
      if (qtyLessThan != null && stock.availableQuantity >= qtyLessThan) {
        return false;
      }
      if (qtyGreaterThan != null && stock.availableQuantity <= qtyGreaterThan) {
        return false;
      }
      return true;
    }).toList();

    final totalCount = filtered.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <StockEntity>[]
        : filtered.sublist(start, end);

    return StockPageResult(
      stocks: pageItems.map(_mapEntityToRecord).toList(),
      summary: summary,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  Future<List<String>> fetchProductSuggestions() async {
    final isar = await AppDatabase.instance;
    final products = await isar.productEntitys.where().findAll()
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
    return products.map((product) => product.name).toSet().toList();
  }

  Future<List<String>> fetchGrnSuggestions() async {
    final isar = await AppDatabase.instance;
    final grns = await isar.grnEntitys.where().findAll()
      ..sort((left, right) => right.date.compareTo(left.date));
    return grns.map((grn) => grn.code).toSet().toList();
  }

  Future<StockRecord?> fetchStockById(int stockId) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.stockEntitys.get(stockId);
    if (entity == null) {
      return null;
    }
    return _mapEntityToRecord(entity);
  }

  @override
  Future<StockRecord?> fetchStockDetails(StockRecord stock) async {
    final stockId = stock.id;
    if (stockId == null) {
      return null;
    }
    return fetchStockById(stockId);
  }

  Future<StockRecord> saveStock(StockRecord stock) async {
    final isar = await AppDatabase.instance;
    final trimmedBarcode = stock.barcode.trim();

    if (trimmedBarcode.isEmpty) {
      throw StockLocalRepositoryException('Stock barcode is required');
    }

    final existing = stock.id == null
        ? null
        : await isar.stockEntitys.get(stock.id!);
    final conflicting = await isar.stockEntitys
        .filter()
        .barcodeEqualTo(trimmedBarcode, caseSensitive: false)
        .findFirst();
    if (conflicting != null && conflicting.id != stock.id) {
      throw StockLocalRepositoryException(
        'A stock item with this barcode already exists',
      );
    }

    ProductEntity? linkedProduct;
    if (stock.product.trim().isNotEmpty) {
      linkedProduct = await isar.productEntitys
          .filter()
          .nameEqualTo(stock.product.trim(), caseSensitive: false)
          .findFirst();
    }

    final now = DateTime.now();
    final entity = StockEntity()
      ..id = stock.id ?? Isar.autoIncrement
      ..barcode = trimmedBarcode
      ..productName = stock.product.trim()
      ..productBarcode = linkedProduct?.barcode
      ..grnCode = stock.grnId == 'Not Assigned' ? null : stock.grnId.trim()
      ..initialQuantity = stock.initialQty
      ..availableQuantity = stock.availableQty
      ..buyingPrice = stock.buyingPrice
      ..sellingPrice = stock.sellingPrice
      ..maxDiscount = stock.maxDiscount
      ..status = _mapStatusToEntity(stock.status)
      ..expiryDate = _parseDateOrNull(stock.expiryDate)
      ..createdAt = existing?.createdAt ?? now
      ..updatedAt = existing == null ? null : now;

    late final int savedId;
    await isar.writeTxn(() async {
      savedId = await isar.stockEntitys.put(entity);
    });
    final savedRecord = _mapEntityToRecord(entity..id = savedId);
    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.stock,
      entityId: '${savedRecord.id ?? savedRecord.barcode}',
      action: existing == null ? 'create' : 'update',
      title: existing == null
          ? 'Created stock ${savedRecord.barcode}'
          : 'Updated stock ${savedRecord.barcode}',
      details: {
        'product': savedRecord.product,
        'barcode': savedRecord.barcode,
        'quantity': savedRecord.availableQty,
        'status': savedRecord.status.name,
        'grnId': savedRecord.grnId,
      },
    );
    return savedRecord;
  }

  Future<StockRecord?> deactivateStockById(int stockId) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.stockEntitys.get(stockId);
    if (entity == null) {
      return null;
    }

    entity
      ..status = StockEntityStatus.inactive
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.stockEntitys.put(entity);
    });
    final savedRecord = _mapEntityToRecord(entity);
    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.stock,
      entityId: '${savedRecord.id ?? savedRecord.barcode}',
      action: 'deactivate',
      title: 'Deactivated stock ${savedRecord.barcode}',
      details: {
        'product': savedRecord.product,
        'barcode': savedRecord.barcode,
        'status': savedRecord.status.name,
      },
    );
    return savedRecord;
  }

  @override
  Future<StockRecord?> deactivateStock(StockRecord stock) async {
    final stockId = stock.id;
    if (stockId == null) {
      return null;
    }
    return deactivateStockById(stockId);
  }

  Future<void> _seedIfNeeded(Isar isar) async {
    final hasStocks = await isar.stockEntitys.count() > 0;
    if (hasStocks) {
      return;
    }

    final now = DateTime.now();
    final products = await isar.productEntitys.where().findAll();
    if (products.isEmpty) {
      final seedProducts = <ProductEntity>[
        // ProductEntity()
        //   ..name = '444'
        //   ..barcode = '8909131772822'
        //   ..category = '444'
        //   ..unit = 'ITEMS'
        //   ..lowStockQuantity = 44
        //   ..status = ProductEntityStatus.active
        //   ..createdAt = now,
        // ProductEntity()
        //   ..name = 'manchee super cream cracker'
        //   ..barcode = '40440445'
        //   ..category = 'busicuts'
        //   ..unit = 'PACKETS'
        //   ..lowStockQuantity = 20
        //   ..status = ProductEntityStatus.active
        //   ..createdAt = now,
        // ProductEntity()
        //   ..name = 'apple'
        //   ..barcode = '8902723378806'
        //   ..category = 'fruits'
        //   ..unit = 'KG'
        //   ..lowStockQuantity = 10
        //   ..status = ProductEntityStatus.active
        //   ..createdAt = now,
        // ProductEntity()
        //   ..name = 'dodam'
        //   ..barcode = '8907916638112'
        //   ..category = 'd'
        //   ..unit = 'ITEMS'
        //   ..lowStockQuantity = 2
        //   ..status = ProductEntityStatus.active
        //   ..createdAt = now,
        // ProductEntity()
        //   ..name = 'product5'
        //   ..barcode = '40440444'
        //   ..category = 'busicuts'
        //   ..unit = 'ITEMS'
        //   ..lowStockQuantity = 22
        //   ..status = ProductEntityStatus.active
        //   ..createdAt = now,
      ];
      await isar.writeTxn(() async {
        await isar.productEntitys.putAll(seedProducts);
      });
    }

    final hasGrns = await isar.grnEntitys.count() > 0;
    if (!hasGrns) {
      final grnSeeds = <GrnEntity>[
        // GrnEntity()
        //   ..code = 'GRN-1001'
        //   ..supplierName = 'apple'
        //   ..date = now
        //   ..subTotal = 100
        //   ..discount = 0
        //   ..paidAmount = 0
        //   ..paymentMethod = 'Cash'
        //   ..createdAt = now,
        // GrnEntity()
        //   ..code = 'GRN-1002'
        //   ..supplierName = 'apple'
        //   ..date = now.subtract(const Duration(days: 1))
        //   ..subTotal = 200
        //   ..discount = 0
        //   ..paidAmount = 0
        //   ..paymentMethod = 'Cash'
        //   ..createdAt = now.subtract(const Duration(days: 1)),
        // GrnEntity()
        //   ..code = 'GRN-1003'
        //   ..supplierName = 'apple'
        //   ..date = now.subtract(const Duration(days: 2))
        //   ..subTotal = 300
        //   ..discount = 0
        //   ..paidAmount = 0
        //   ..paymentMethod = 'Cash'
        //   ..createdAt = now.subtract(const Duration(days: 2)),
        // GrnEntity()
        //   ..code = 'GRN-APPLE-24'
        //   ..supplierName = 'apple'
        //   ..date = now.subtract(const Duration(days: 3))
        //   ..subTotal = 400
        //   ..discount = 0
        //   ..paidAmount = 0
        //   ..paymentMethod = 'Cash'
        //   ..createdAt = now.subtract(const Duration(days: 3)),
        // GrnEntity()
        //   ..code = 'GRN-CRACKER-10'
        //   ..supplierName = 'apple'
        //   ..date = now.subtract(const Duration(days: 4))
        //   ..subTotal = 500
        //   ..discount = 0
        //   ..paidAmount = 0
        //   ..paymentMethod = 'Cash'
        //   ..createdAt = now.subtract(const Duration(days: 4)),
      ];
      await isar.writeTxn(() async {
        await isar.grnEntitys.putAll(grnSeeds);
      });
    }

    final seedStocks = <StockEntity>[
      // _seedStock(
      //   barcode: '120339-A',
      //   product: '444',
      //   initialQty: 10,
      //   availableQty: 4,
      //   buyingPrice: 4,
      //   sellingPrice: 55,
      //   maxDiscount: 1,
      //   status: StockEntityStatus.inactive,
      //   grnCode: null,
      //   createdAt: now,
      // ),
      // _seedStock(
      //   barcode: '120339-B',
      //   product: '444',
      //   initialQty: 10,
      //   availableQty: 0,
      //   buyingPrice: 4,
      //   sellingPrice: 55,
      //   maxDiscount: 1,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-1001',
      //   createdAt: now.subtract(const Duration(minutes: 5)),
      // ),
      // _seedStock(
      //   barcode: 'STK-1775491845683-pbfer7c31',
      //   product: 'manchee super cream cracker',
      //   initialQty: 7,
      //   availableQty: 7,
      //   buyingPrice: 99,
      //   sellingPrice: 88,
      //   maxDiscount: 0,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-CRACKER-10',
      //   createdAt: now.subtract(const Duration(hours: 1)),
      // ),
      // _seedStock(
      //   barcode: 'STK-1775491815059-tj65mad17',
      //   product: 'manchee super cream cracker',
      //   initialQty: 8,
      //   availableQty: 5,
      //   buyingPrice: 88,
      //   sellingPrice: 99,
      //   maxDiscount: 0,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-1002',
      //   createdAt: now.subtract(const Duration(hours: 2)),
      // ),
      // _seedStock(
      //   barcode: 'STK-1775491789360-ebphsyxbu',
      //   product: 'manchee super cream cracker',
      //   initialQty: 7,
      //   availableQty: 7,
      //   buyingPrice: 99,
      //   sellingPrice: 7,
      //   maxDiscount: 0,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-1003',
      //   createdAt: now.subtract(const Duration(hours: 3)),
      // ),
      // _seedStock(
      //   barcode: 'v',
      //   product: 'manchee super cream cracker',
      //   initialQty: 8,
      //   availableQty: 3,
      //   buyingPrice: 8,
      //   sellingPrice: 88,
      //   maxDiscount: 88,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-CRACKER-10',
      //   createdAt: now.subtract(const Duration(hours: 4)),
      // ),
      // _seedStock(
      //   barcode: 'STK-1775491714698-m3ffqvb3m',
      //   product: 'apple',
      //   initialQty: 99,
      //   availableQty: 95,
      //   buyingPrice: 77,
      //   sellingPrice: 888,
      //   maxDiscount: 0,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-APPLE-24',
      //   expiryDate: DateTime(now.year, 12, 31),
      //   createdAt: now.subtract(const Duration(hours: 5)),
      // ),
      // _seedStock(
      //   barcode: 'STK-1775491682558-3o5mmmzrt',
      //   product: 'dodam',
      //   initialQty: 77,
      //   availableQty: 60,
      //   buyingPrice: 77,
      //   sellingPrice: 88,
      //   maxDiscount: 0,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-1002',
      //   createdAt: now.subtract(const Duration(hours: 6)),
      // ),
      // _seedStock(
      //   barcode: 'STK-1775491653682-qzy1v8xvu',
      //   product: 'product5',
      //   initialQty: 77,
      //   availableQty: 71,
      //   buyingPrice: 777,
      //   sellingPrice: 99,
      //   maxDiscount: 66,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-1003',
      //   createdAt: now.subtract(const Duration(hours: 7)),
      // ),
      // _seedStock(
      //   barcode: 'STK-1775491617229-kdoqdami3',
      //   product: 'manchee super cream cracker',
      //   initialQty: 9,
      //   availableQty: 9,
      //   buyingPrice: 8,
      //   sellingPrice: 77,
      //   maxDiscount: 0,
      //   status: StockEntityStatus.active,
      //   grnCode: 'GRN-1001',
      //   createdAt: now.subtract(const Duration(hours: 8)),
      // ),
    ];

    await isar.writeTxn(() async {
      await isar.stockEntitys.putAll(seedStocks);
    });
  }

  StockEntity _seedStock({
    required String barcode,
    required String product,
    required int initialQty,
    required int availableQty,
    required double buyingPrice,
    required double sellingPrice,
    required double maxDiscount,
    required StockEntityStatus status,
    required String? grnCode,
    required DateTime createdAt,
    DateTime? expiryDate,
  }) {
    return StockEntity()
      ..barcode = barcode
      ..productName = product
      ..productBarcode = null
      ..grnCode = grnCode
      ..initialQuantity = initialQty
      ..availableQuantity = availableQty
      ..buyingPrice = buyingPrice
      ..sellingPrice = sellingPrice
      ..maxDiscount = maxDiscount
      ..status = status
      ..expiryDate = expiryDate
      ..createdAt = createdAt;
  }

  StockRecord _mapEntityToRecord(StockEntity entity) {
    return StockRecord(
      id: entity.id,
      cloudId: null,
      barcode: entity.barcode,
      product: entity.productName,
      initialQty: entity.initialQuantity,
      availableQty: entity.availableQuantity,
      buyingPrice: entity.buyingPrice,
      sellingPrice: entity.sellingPrice,
      maxDiscount: entity.maxDiscount,
      status: _mapStatusFromEntity(entity.status),
      grnId: entity.grnCode ?? 'Not Assigned',
      expiryDate: entity.expiryDate == null
          ? null
          : _formatDate(entity.expiryDate!),
    );
  }

  StockStatus _mapStatusFromEntity(StockEntityStatus status) {
    return switch (status) {
      StockEntityStatus.active => StockStatus.active,
      StockEntityStatus.inactive => StockStatus.inactive,
    };
  }

  StockEntityStatus _mapStatusToEntity(StockStatus status) {
    return switch (status) {
      StockStatus.active => StockEntityStatus.active,
      StockStatus.inactive => StockEntityStatus.inactive,
    };
  }

  DateTime? _parseDateOrNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
