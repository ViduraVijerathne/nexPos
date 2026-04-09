import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'grn_repository.dart';

class GrnLocalRepositoryException implements Exception {
  GrnLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GrnLocalRepository implements GrnRepository {
  const GrnLocalRepository();

  static const int pageSize = 10;

  Future<void> initialize() async {
    final isar = await AppDatabase.instance;
    await _seedIfNeeded(isar);
  }

  Future<GrnPageResult> fetchGrns({
    required int page,
    String? supplierQuery,
    String? dateFrom,
    String? dateTo,
    double? dueAbove,
  }) async {
    final isar = await AppDatabase.instance;
    final grns = await isar.grnEntitys.where().findAll()
      ..sort((left, right) => right.date.compareTo(left.date));

    final normalizedSupplier = supplierQuery?.trim().toLowerCase() ?? '';
    final normalizedFrom = dateFrom?.trim() ?? '';
    final normalizedTo = dateTo?.trim() ?? '';

    final filtered = grns.where((grn) {
      if (normalizedSupplier.isNotEmpty &&
          !grn.supplierName.toLowerCase().contains(normalizedSupplier)) {
        return false;
      }

      final grnDate = _formatDate(grn.date);
      if (normalizedFrom.isNotEmpty && grnDate.compareTo(normalizedFrom) < 0) {
        return false;
      }
      if (normalizedTo.isNotEmpty && grnDate.compareTo(normalizedTo) > 0) {
        return false;
      }
      if (dueAbove != null && grn.dueAmount <= dueAbove) {
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
        ? <GrnEntity>[]
        : filtered.sublist(start, end);

    return GrnPageResult(
      records: pageItems.map(_mapGrnEntityToRecord).toList(),
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

  Future<List<String>> fetchSupplierSuggestions() async {
    final isar = await AppDatabase.instance;
    final suppliers = await isar.supplierEntitys.where().findAll()
      ..sort(
        (left, right) => left.supplierName.toLowerCase().compareTo(
          right.supplierName.toLowerCase(),
        ),
      );
    return suppliers.map((supplier) => supplier.supplierName).toSet().toList();
  }

  Future<GrnRecord?> fetchGrnById(String grnId) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.grnEntitys
        .filter()
        .codeEqualTo(grnId)
        .findFirst();
    if (entity == null) {
      return null;
    }

    return _mapGrnEntityToRecord(entity);
  }

  Future<GrnRecord> saveGrn(
    GrnRecord record, {
    required bool addToStock,
  }) async {
    final isar = await AppDatabase.instance;
    final supplierName = record.supplier.trim();
    if (supplierName.isEmpty) {
      throw GrnLocalRepositoryException('Supplier is required');
    }
    if (record.items.isEmpty) {
      throw GrnLocalRepositoryException('Add at least one GRN item');
    }

    final existing = await isar.grnEntitys
        .filter()
        .codeEqualTo(record.id)
        .findFirst();
    final supplier = await isar.supplierEntitys
        .filter()
        .supplierNameEqualTo(supplierName, caseSensitive: false)
        .findFirst();

    final items = record.items
        .map((item) => _mapGrnItemToEmbedded(item, inStock: addToStock))
        .toList();

    final now = DateTime.now();
    final initialPaymentHistory =
        existing?.paymentHistory ??
        (record.paidAmount > 0
            ? <GrnPaymentEmbedded>[
                GrnPaymentEmbedded()
                  ..paidAt = now
                  ..amount = record.paidAmount
                  ..method = record.paymentMethod
                  ..remainingBalance = (record.total - record.paidAmount).clamp(
                    0,
                    double.infinity,
                  ),
              ]
            : <GrnPaymentEmbedded>[]);
    final entity = GrnEntity()
      ..id = existing?.id ?? Isar.autoIncrement
      ..code = record.id
      ..supplierName = supplierName
      ..supplierDbId = supplier?.id
      ..date = _parseDate(record.date)
      ..subTotal = record.subTotal
      ..discount = record.discount
      ..paidAmount = record.paidAmount
      ..paymentMethod = record.paymentMethod
      ..items = items
      ..paymentHistory = initialPaymentHistory
      ..createdAt = existing?.createdAt ?? now
      ..updatedAt = existing == null ? null : now;

    late final int savedId;
    await isar.writeTxn(() async {
      savedId = await isar.grnEntitys.put(entity);

      if (addToStock) {
        for (final item in record.items) {
          final stock = StockEntity()
            ..barcode = item.stockBarcode
            ..productName = item.product
            ..productBarcode = null
            ..grnCode = record.id
            ..initialQuantity = item.quantity
            ..availableQuantity = item.quantity
            ..buyingPrice = item.buyingPrice
            ..sellingPrice = item.sellingPrice
            ..maxDiscount = item.maxDiscount
            ..status = StockEntityStatus.active
            ..createdAt = now;
          await isar.stockEntitys.put(stock);
        }
      }
    });

    return _mapGrnEntityToRecord(entity..id = savedId);
  }

  Future<GrnRecord?> recordDuePayment({
    required String grnId,
    required double amount,
    required String method,
  }) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.grnEntitys
        .filter()
        .codeEqualTo(grnId)
        .findFirst();
    if (entity == null) {
      return null;
    }

    if (amount <= 0 || amount > entity.dueAmount) {
      throw GrnLocalRepositoryException('Invalid payment amount');
    }

    final payment = GrnPaymentEmbedded()
      ..paidAt = DateTime.now()
      ..amount = amount
      ..method = method
      ..remainingBalance = (entity.dueAmount - amount).clamp(
        0,
        double.infinity,
      );

    entity
      ..paidAmount += amount
      ..paymentHistory = <GrnPaymentEmbedded>[payment, ...entity.paymentHistory]
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.grnEntitys.put(entity);
    });

    return _mapGrnEntityToRecord(entity);
  }

  Future<GrnRecord?> addPendingItemsToStock(String grnId) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.grnEntitys
        .filter()
        .codeEqualTo(grnId)
        .findFirst();
    if (entity == null) {
      return null;
    }

    final pendingItems = entity.items.where((item) => !item.inStock).toList();
    if (pendingItems.isEmpty) {
      return _mapGrnEntityToRecord(entity);
    }

    final now = DateTime.now();
    await isar.writeTxn(() async {
      for (final item in pendingItems) {
        final stock = StockEntity()
          ..barcode = item.stockBarcode
          ..productName = item.productName
          ..productBarcode = item.productBarcode
          ..grnCode = entity.code
          ..initialQuantity = item.quantity
          ..availableQuantity = item.quantity
          ..buyingPrice = item.buyingPrice
          ..sellingPrice = item.sellingPrice
          ..maxDiscount = item.maxDiscount
          ..status = StockEntityStatus.active
          ..createdAt = now;
        await isar.stockEntitys.put(stock);
        item.inStock = true;
      }

      entity.updatedAt = now;
      await isar.grnEntitys.put(entity);
    });

    return _mapGrnEntityToRecord(entity);
  }

  Future<void> _seedIfNeeded(Isar isar) async {
    final hasProducts = await isar.productEntitys.count() > 0;
    if (!hasProducts) {
      final now = DateTime.now();
      final seedProducts = <ProductEntity>[
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
        //   ..name = '444'
        //   ..barcode = '8909131772822'
        //   ..category = '444'
        //   ..unit = 'ITEMS'
        //   ..lowStockQuantity = 44
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

    final hasSuppliers = await isar.supplierEntitys.count() > 0;
    if (!hasSuppliers) {
      final now = DateTime.now();
      final seedSuppliers = <SupplierEntity>[
        // SupplierEntity()
        //   ..supplierName = 'apple'
        //   ..companyName = 'Uva wellassa university Sri lanka'
        //   ..contactNumber = '0733'
        //   ..companyContact = '29922'
        //   ..email = 'bet23058@std.uwu.ac.lk'
        //   ..address = 'moroththa,madahapola'
        //   ..isActive = true
        //   ..createdAt = now,
        // SupplierEntity()
        //   ..supplierName = 'banana co'
        //   ..companyName = 'Banana Co Pvt Ltd'
        //   ..contactNumber = '0711111111'
        //   ..companyContact = '0111111111'
        //   ..email = 'hello@bananaco.lk'
        //   ..address = 'Colombo'
        //   ..isActive = true
        //   ..createdAt = now,
      ];
      await isar.writeTxn(() async {
        await isar.supplierEntitys.putAll(seedSuppliers);
      });
    }

    final hasGrns = await isar.grnEntitys.count() > 0;
    if (hasGrns) {
      return;
    }

    final suppliers = await isar.supplierEntitys.where().findAll();
    if (suppliers.isEmpty) {
      return;
    }

    final appleSupplier = suppliers.firstWhere(
      (supplier) => supplier.supplierName.toLowerCase() == 'apple',
      orElse: () => suppliers.first,
    );
    final bananaSupplier = suppliers.firstWhere(
      (supplier) => supplier.supplierName.toLowerCase() == 'banana co',
      orElse: () => suppliers.first,
    );

    final now = DateTime.now();
    final seedGrns = <GrnEntity>[
      // _seedGrn(
      //   code: 'ya5Rw466RR08...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2)),
      //   subTotal: 5929,
      //   discount: 0,
      //   paidAmount: 333,
      //   items: [
      //     _embeddedItem(
      //       productName: 'dodam',
      //       stockBarcode: 'STK-1775491682558-3o5mmmzrt',
      //       quantity: 77,
      //       buyingPrice: 77,
      //       sellingPrice: 88,
      //       inStock: true,
      //     ),
      //   ],
      //   payments: [
      //     _embeddedPayment(
      //       paidAt: now.subtract(const Duration(hours: 1)),
      //       amount: 333,
      //       method: 'Bank Transfer',
      //       remainingBalance: 5596,
      //     ),
      //     _embeddedPayment(
      //       paidAt: now.subtract(const Duration(hours: 1, minutes: 2)),
      //       amount: 333,
      //       method: 'Bank Transfer',
      //       remainingBalance: 5596,
      //     ),
      //   ],
      // ),
      // _seedGrn(
      //   code: 'n5g0DP7r...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 1)),
      //   subTotal: 693,
      //   discount: 0,
      //   paidAmount: 0,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'kOHpHalv...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 2)),
      //   subTotal: 27972,
      //   discount: 0,
      //   paidAmount: 20000,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'iG5ANULe...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 3)),
      //   subTotal: 9801,
      //   discount: 9,
      //   paidAmount: 0,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'hzx2nKMe...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 4)),
      //   subTotal: 72,
      //   discount: 0,
      //   paidAmount: 0,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'YxIEzec4...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 5)),
      //   subTotal: 64,
      //   discount: 0,
      //   paidAmount: 88,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'FwrM5nMM...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 6)),
      //   subTotal: 7623,
      //   discount: 0,
      //   paidAmount: 0,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'FSe1bGT1...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 7)),
      //   subTotal: 704,
      //   discount: 0,
      //   paidAmount: 0,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'EblchgQG...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 8)),
      //   subTotal: 693,
      //   discount: 0,
      //   paidAmount: 0,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: '5r4MH2V6...',
      //   supplier: appleSupplier,
      //   date: now.subtract(const Duration(days: 2, hours: 9)),
      //   subTotal: 59829,
      //   discount: 0,
      //   paidAmount: 59829,
      //   items: const [],
      //   payments: const [],
      // ),
      // _seedGrn(
      //   code: 'EXTRA111...',
      //   supplier: bananaSupplier,
      //   date: now,
      //   subTotal: 100,
      //   discount: 0,
      //   paidAmount: 20,
      //   items: const [],
      //   payments: const [],
      // ),
    ];

    if (seedGrns.isEmpty) {
      return;
    }

    await isar.writeTxn(() async {
      await isar.grnEntitys.putAll(seedGrns);
    });
  }

  GrnEntity _seedGrn({
    required String code,
    required SupplierEntity supplier,
    required DateTime date,
    required double subTotal,
    required double discount,
    required double paidAmount,
    required List<GrnItemEmbedded> items,
    required List<GrnPaymentEmbedded> payments,
  }) {
    return GrnEntity()
      ..code = code
      ..supplierName = supplier.supplierName
      ..supplierDbId = supplier.id
      ..date = date
      ..subTotal = subTotal
      ..discount = discount
      ..paidAmount = paidAmount
      ..paymentMethod = 'Cash'
      ..items = items
      ..paymentHistory = payments
      ..createdAt = date;
  }

  GrnItemEmbedded _embeddedItem({
    required String productName,
    required String stockBarcode,
    required int quantity,
    required double buyingPrice,
    required double sellingPrice,
    required bool inStock,
  }) {
    return GrnItemEmbedded()
      ..productName = productName
      ..stockBarcode = stockBarcode
      ..quantity = quantity
      ..buyingPrice = buyingPrice
      ..sellingPrice = sellingPrice
      ..maxDiscount = 0
      ..inStock = inStock;
  }

  GrnPaymentEmbedded _embeddedPayment({
    required DateTime paidAt,
    required double amount,
    required String method,
    required double remainingBalance,
  }) {
    return GrnPaymentEmbedded()
      ..paidAt = paidAt
      ..amount = amount
      ..method = method
      ..remainingBalance = remainingBalance;
  }

  GrnItemEmbedded _mapGrnItemToEmbedded(GrnItem item, {required bool inStock}) {
    return GrnItemEmbedded()
      ..productName = item.product
      ..stockBarcode = item.stockBarcode
      ..quantity = item.quantity
      ..buyingPrice = item.buyingPrice
      ..sellingPrice = item.sellingPrice
      ..maxDiscount = item.maxDiscount
      ..inStock = inStock;
  }

  GrnRecord _mapGrnEntityToRecord(GrnEntity entity) {
    return GrnRecord(
      id: entity.code,
      supplier: entity.supplierName,
      date: _formatDate(entity.date),
      subTotal: entity.subTotal,
      discount: entity.discount,
      paidAmount: entity.paidAmount,
      items: entity.items
          .map(
            (item) => GrnItem(
              product: item.productName,
              stockBarcode: item.stockBarcode,
              quantity: item.quantity,
              buyingPrice: item.buyingPrice,
              sellingPrice: item.sellingPrice,
              maxDiscount: item.maxDiscount,
              inStock: item.inStock,
            ),
          )
          .toList(),
      paymentHistory: entity.paymentHistory
          .map(
            (payment) => PaymentHistory(
              dateTime: _formatDateTime(payment.paidAt),
              amount: payment.amount,
              method: payment.method,
              remainingBalance: payment.remainingBalance,
            ),
          )
          .toList(),
      paymentMethod: entity.paymentMethod,
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDateTime(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/${date.year}, $hour:$minute $period';
  }

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }
}
