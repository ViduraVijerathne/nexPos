import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/change_log_service.dart';
import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'stock_repository.dart';

class StockRemoteRepositoryException implements Exception {
  StockRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StockRemoteRepository implements StockRepository {
  StockRemoteRepository({required this.shopId});

  static const int pageSize = 10;

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _stocksRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('stocks');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _grnsRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('grns');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw StockRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<StockPageResult> fetchStocks({
    required int page,
    String? barcodeQuery,
    String? productQuery,
    String? grnQuery,
    String? statusFilter,
    int? qtyLessThan,
    int? qtyGreaterThan,
  }) async {
    final stockSnapshot = await _stocksRef.get();
    final productSnapshot = await _productsRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: stockSnapshot.docs.length + productSnapshot.docs.length,
      payload: <Object?>[
        stockSnapshot.docs.map((doc) => doc.data()).toList(),
        productSnapshot.docs.map((doc) => doc.data()).toList(),
      ],
    );

    final productsByName = <String, Map<String, dynamic>>{
      for (final doc in productSnapshot.docs)
        (doc.data()['name']?.toString().trim().toLowerCase() ?? ''): doc.data(),
    };

    final docs = stockSnapshot.docs.toList()
      ..sort((left, right) {
        final leftDate = _readSortDate(left.data());
        final rightDate = _readSortDate(right.data());
        return rightDate.compareTo(leftDate);
      });

    final allStocks = docs.map(_mapDocumentToRecord).toList();
    final normalizedBarcode = barcodeQuery?.trim().toLowerCase() ?? '';
    final normalizedProduct = productQuery?.trim().toLowerCase() ?? '';
    final normalizedGrn = grnQuery?.trim().toLowerCase() ?? '';

    final summary = StockSummary(
      totalStockItems: allStocks.length,
      activeStocks: allStocks
          .where((stock) => stock.status == StockStatus.active)
          .length,
      lowStockItems: allStocks.where((stock) {
        final productData = productsByName[stock.product.toLowerCase()];
        final lowStockQty =
            (productData?['lowStockQuantity'] as num?)?.toInt() ?? 5;
        return stock.status == StockStatus.active &&
            stock.availableQty <= lowStockQty;
      }).length,
      inactiveStocks: allStocks
          .where((stock) => stock.status == StockStatus.inactive)
          .length,
    );

    final filtered = allStocks.where((stock) {
      if (normalizedBarcode.isNotEmpty &&
          !stock.barcode.toLowerCase().contains(normalizedBarcode)) {
        return false;
      }
      if (normalizedProduct.isNotEmpty &&
          !stock.product.toLowerCase().contains(normalizedProduct)) {
        return false;
      }
      if (normalizedGrn.isNotEmpty &&
          !stock.grnId.toLowerCase().contains(normalizedGrn)) {
        return false;
      }
      if (statusFilter != null &&
          statusFilter != 'All' &&
          stock.status.label != statusFilter) {
        return false;
      }
      if (qtyLessThan != null && stock.availableQty >= qtyLessThan) {
        return false;
      }
      if (qtyGreaterThan != null && stock.availableQty <= qtyGreaterThan) {
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
        ? <StockRecord>[]
        : filtered.sublist(start, end);

    return StockPageResult(
      stocks: pageItems,
      summary: summary,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<String>> fetchProductSuggestions() async {
    final snapshot = await _productsRef.orderBy('nameLower').limit(50).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    return snapshot.docs
        .map((doc) => doc.data()['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Future<List<String>> fetchGrnSuggestions() async {
    final snapshot = await _grnsRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final codes =
        snapshot.docs
            .map((doc) => doc.data()['code']?.toString().trim() ?? doc.id)
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return codes;
  }

  @override
  Future<StockRecord?> fetchStockDetails(StockRecord stock) async {
    final cloudId = stock.cloudId;
    if (cloudId == null || cloudId.isEmpty) {
      throw StockRemoteRepositoryException('Stock identifier is missing');
    }

    final snapshot = await _stocksRef.doc(cloudId).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: snapshot.exists ? 1 : 0,
      payload: snapshot.data(),
    );
    if (!snapshot.exists) {
      return null;
    }
    return _mapDocumentToRecord(snapshot);
  }

  @override
  Future<StockRecord> saveStock(StockRecord stock) async {
    final trimmedBarcode = stock.barcode.trim();
    final trimmedProduct = stock.product.trim();
    final trimmedGrn =
        stock.grnId.trim().isEmpty || stock.grnId == 'Not Assigned'
        ? ''
        : stock.grnId.trim();

    if (trimmedBarcode.isEmpty) {
      throw StockRemoteRepositoryException('Stock barcode is required');
    }
    if (trimmedProduct.isEmpty) {
      throw StockRemoteRepositoryException('Product is required');
    }

    final conflict = await _stocksRef
        .where('barcodeLower', isEqualTo: trimmedBarcode.toLowerCase())
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: conflict.docs.length,
      payload: conflict.docs.map((doc) => doc.data()).toList(),
    );
    if (conflict.docs.isNotEmpty && conflict.docs.first.id != stock.cloudId) {
      throw StockRemoteRepositoryException(
        'A stock item with this barcode already exists',
      );
    }

    final productBarcode = await _findProductBarcodeByName(trimmedProduct);
    final docRef = stock.cloudId == null
        ? _stocksRef.doc()
        : _stocksRef.doc(stock.cloudId);
    final existing = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: existing.exists ? 1 : 0,
      payload: existing.data(),
    );
    final existingData = existing.data();
    final now = DateTime.now();

    await docRef.set({
      'barcode': trimmedBarcode,
      'barcodeLower': trimmedBarcode.toLowerCase(),
      'productName': trimmedProduct,
      'productNameLower': trimmedProduct.toLowerCase(),
      'productBarcode': productBarcode,
      'grnCode': trimmedGrn.isEmpty ? null : trimmedGrn,
      'initialQuantity': stock.initialQty,
      'availableQuantity': stock.availableQty,
      'buyingPrice': stock.buyingPrice,
      'sellingPrice': stock.sellingPrice,
      'maxDiscount': stock.maxDiscount,
      'status': stock.status.name,
      'expiryDate': stock.expiryDate,
      'createdAt': existingData?['createdAt'] ?? now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'stocks',
      payload: <String, dynamic>{
        'barcode': trimmedBarcode,
        'productName': trimmedProduct,
        'grnCode': trimmedGrn,
        'initialQuantity': stock.initialQty,
        'availableQuantity': stock.availableQty,
      },
    );

    final saved = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: saved.exists ? 1 : 0,
      payload: saved.data(),
    );
    final savedRecord = _mapDocumentToRecord(saved);
    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.stock,
      entityId: savedRecord.cloudId ?? savedRecord.barcode,
      action: existingData == null ? 'create' : 'update',
      title: existingData == null
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

  @override
  Future<StockRecord?> deactivateStock(StockRecord stock) async {
    final cloudId = stock.cloudId;
    if (cloudId == null || cloudId.isEmpty) {
      throw StockRemoteRepositoryException('Stock identifier is missing');
    }

    await _stocksRef.doc(cloudId).update({
      'status': 'inactive',
      'updatedAt': DateTime.now(),
    });
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'stocks',
      payload: <String, dynamic>{
        'barcode': stock.barcode,
        'status': 'inactive',
      },
    );
    final savedRecord = await fetchStockDetails(
      stock.copyWith(status: StockStatus.inactive),
    );
    if (savedRecord != null) {
      await ChangeLogService.instance.logChange(
        entityType: ChangeLogEntityType.stock,
        entityId: savedRecord.cloudId ?? savedRecord.barcode,
        action: 'deactivate',
        title: 'Deactivated stock ${savedRecord.barcode}',
        details: {
          'product': savedRecord.product,
          'barcode': savedRecord.barcode,
          'status': savedRecord.status.name,
        },
      );
    }
    return savedRecord;
  }

  Future<String?> _findProductBarcodeByName(String productName) async {
    final snapshot = await _productsRef
        .where('nameLower', isEqualTo: productName.toLowerCase())
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'stocks',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first.data()['barcode']?.toString();
  }

  StockRecord _mapDocumentToRecord(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return StockRecord(
      id: null,
      cloudId: document.id,
      barcode: data['barcode']?.toString() ?? '',
      product: data['productName']?.toString() ?? '',
      initialQty: (data['initialQuantity'] as num?)?.toInt() ?? 0,
      availableQty: (data['availableQuantity'] as num?)?.toInt() ?? 0,
      buyingPrice: (data['buyingPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      maxDiscount: (data['maxDiscount'] as num?)?.toDouble() ?? 0,
      status: _mapStatus(data['status']?.toString()),
      grnId: data['grnCode']?.toString().trim().isNotEmpty == true
          ? data['grnCode'].toString()
          : 'Not Assigned',
      expiryDate: data['expiryDate']?.toString(),
    );
  }

  StockStatus _mapStatus(String? value) {
    return switch (value) {
      'inactive' => StockStatus.inactive,
      _ => StockStatus.active,
    };
  }

  DateTime _readSortDate(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) {
      return updatedAt.toDate();
    }
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
