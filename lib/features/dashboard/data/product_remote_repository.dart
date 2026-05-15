import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/change_log_service.dart';
import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'product_repository.dart';

class ProductRemoteRepositoryException implements Exception {
  ProductRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductRemoteRepository implements ProductRepository {
  ProductRemoteRepository({required this.shopId});

  static const int pageSize = 10;

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('categories');

  CollectionReference<Map<String, dynamic>> get _stocksRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('stocks');

  CollectionReference<Map<String, dynamic>> get _grnsRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('grns');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw ProductRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<ProductPageResult> fetchProducts({
    required int page,
    String? nameQuery,
    String? categoryQuery,
    String? barcodeQuery,
  }) async {
    final snapshot = await _productsRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final documents = snapshot.docs.toList()
      ..sort((left, right) {
        final leftDate = _readSortDate(left.data());
        final rightDate = _readSortDate(right.data());
        return rightDate.compareTo(leftDate);
      });
    final products = documents.map(_mapDocumentToRecord).toList();

    final normalizedName = nameQuery?.trim().toLowerCase() ?? '';
    final normalizedCategory = categoryQuery?.trim().toLowerCase() ?? '';
    final normalizedBarcode = barcodeQuery?.trim().toLowerCase() ?? '';

    final filteredProducts = products.where((product) {
      if (normalizedName.isNotEmpty) {
        return product.name.toLowerCase().contains(normalizedName);
      }

      if (normalizedCategory.isNotEmpty) {
        return product.category.toLowerCase().contains(normalizedCategory);
      }

      if (normalizedBarcode.isNotEmpty) {
        return product.barcode.toLowerCase().contains(normalizedBarcode);
      }

      return true;
    }).toList();

    final totalCount = filteredProducts.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <ProductRecord>[]
        : filteredProducts.sublist(start, end);

    return ProductPageResult(
      products: pageItems,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<String>> fetchCategorySuggestions(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    final snapshot = await _categoriesRef.orderBy('nameLower').limit(20).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final names = snapshot.docs
        .map((doc) => doc.data()['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .where((name) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return name.toLowerCase().contains(normalizedQuery);
        })
        .take(3)
        .toList();
    return names;
  }

  @override
  Future<bool> categoryExists(String categoryName) async {
    final normalized = categoryName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    final snapshot = await _categoriesRef
        .where('nameLower', isEqualTo: normalized)
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<String> createCategory(String categoryName) async {
    final normalizedName = categoryName.trim();
    final normalizedLower = normalizedName.toLowerCase();
    if (normalizedName.isEmpty) {
      throw ProductRemoteRepositoryException('Category name is required');
    }

    final existing = await _categoriesRef
        .where('nameLower', isEqualTo: normalizedLower)
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: existing.docs.length,
      payload: existing.docs.map((doc) => doc.data()).toList(),
    );
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.data()['name']?.toString() ?? normalizedName;
    }

    await _categoriesRef.add({
      'name': normalizedName,
      'nameLower': normalizedLower,
      'createdAt': DateTime.now(),
    });
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'products',
      payload: <String, dynamic>{
        'name': normalizedName,
        'nameLower': normalizedLower,
      },
    );
    return normalizedName;
  }

  @override
  Future<ProductRecord?> fetchProductByName(String productName) async {
    final normalized = productName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final snapshot = await _productsRef
        .where('nameLower', isEqualTo: normalized)
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    if (snapshot.docs.isEmpty) {
      return null;
    }

    return _mapDocumentToRecord(snapshot.docs.first);
  }

  @override
  Future<ProductRecord> saveProduct(ProductRecord product) async {
    final normalizedName = product.name.trim();
    final trimmedBarcode = product.barcode.trim();
    final normalizedCategory = product.category.trim();

    if (normalizedName.isEmpty) {
      throw ProductRemoteRepositoryException('Product name is required');
    }
    if (trimmedBarcode.isEmpty) {
      throw ProductRemoteRepositoryException('Barcode is required');
    }
    if (normalizedCategory.isEmpty) {
      throw ProductRemoteRepositoryException('Category is required');
    }

    final conflict = await _productsRef
        .where('barcodeLower', isEqualTo: trimmedBarcode.toLowerCase())
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: conflict.docs.length,
      payload: conflict.docs.map((doc) => doc.data()).toList(),
    );
    if (conflict.docs.isNotEmpty && conflict.docs.first.id != product.cloudId) {
      throw ProductRemoteRepositoryException(
        'A product with this barcode already exists',
      );
    }

    await _saveCategoryIfMissing(normalizedCategory);

    final docRef = product.cloudId == null
        ? _productsRef.doc()
        : _productsRef.doc(product.cloudId);
    final existingSnapshot = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: existingSnapshot.exists ? 1 : 0,
      payload: existingSnapshot.data(),
    );
    final existingData = existingSnapshot.data();
    final previousName = existingData?['name']?.toString() ?? '';
    final previousBarcode = existingData?['barcode']?.toString() ?? '';
    final now = DateTime.now();

    await docRef.set({
      'name': normalizedName,
      'nameLower': normalizedName.toLowerCase(),
      'barcode': trimmedBarcode,
      'barcodeLower': trimmedBarcode.toLowerCase(),
      'category': normalizedCategory,
      'categoryLower': normalizedCategory.toLowerCase(),
      'unit': product.unit,
      'lowStockQuantity': product.lowStock,
      'isQuickSelling': product.isQuickSelling,
      'status': product.status.name,
      'createdAt': existingData?['createdAt'] ?? now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'products',
      payload: <String, dynamic>{
        'name': normalizedName,
        'barcode': trimmedBarcode,
        'category': normalizedCategory,
        'unit': product.unit,
        'lowStockQuantity': product.lowStock,
        'isQuickSelling': product.isQuickSelling,
        'status': product.status.name,
      },
    );

    if (existingData != null) {
      await _cascadeProductChanges(
        previousName: previousName,
        previousBarcode: previousBarcode,
        updatedName: normalizedName,
        updatedBarcode: trimmedBarcode,
      );
    }

    final savedSnapshot = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: savedSnapshot.exists ? 1 : 0,
      payload: savedSnapshot.data(),
    );
    final savedRecord = _mapDocumentToRecord(savedSnapshot);
    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.product,
      entityId: savedRecord.cloudId ?? savedRecord.barcode,
      action: existingData == null ? 'create' : 'update',
      title: existingData == null
          ? 'Created product ${savedRecord.name}'
          : 'Updated product ${savedRecord.name}',
      details: {
        'name': savedRecord.name,
        'barcode': savedRecord.barcode,
        'category': savedRecord.category,
        'unit': savedRecord.unit,
        'isQuickSelling': savedRecord.isQuickSelling,
        'status': savedRecord.status.name,
        if (existingData != null) ...{
          'previousName': previousName,
          'previousBarcode': previousBarcode,
          'previousCategory': existingData['category']?.toString() ?? '',
          'previousUnit': existingData['unit']?.toString() ?? '',
          'previousIsQuickSelling': existingData['isQuickSelling'] == true,
          'previousStatus': existingData['status']?.toString() ?? 'active',
        },
      },
    );
    return savedRecord;
  }

  Future<void> _cascadeProductChanges({
    required String previousName,
    required String previousBarcode,
    required String updatedName,
    required String updatedBarcode,
  }) async {
    final stocksSnapshot = await _stocksRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: stocksSnapshot.docs.length,
      payload: stocksSnapshot.docs.map((doc) => doc.data()).toList(),
    );
    var stockWriteCount = 0;
    for (final stockDoc in stocksSnapshot.docs) {
      final data = stockDoc.data();
      final stockProductName = data['productName']?.toString() ?? '';
      final stockProductBarcode = data['productBarcode']?.toString() ?? '';
      final matchesName =
          previousName.trim().isNotEmpty &&
          stockProductName.toLowerCase() == previousName.toLowerCase();
      final matchesBarcode =
          previousBarcode.trim().isNotEmpty &&
          stockProductBarcode.toLowerCase() == previousBarcode.toLowerCase();
      if (!matchesName && !matchesBarcode) {
        continue;
      }

      await stockDoc.reference.update({
        'productName': updatedName,
        'productNameLower': updatedName.toLowerCase(),
        'productBarcode': updatedBarcode,
        'updatedAt': DateTime.now(),
      });
      stockWriteCount++;
    }
    if (stockWriteCount > 0) {
      await SubscriptionUsageService.instance.recordWrite(
        shopId: shopId,
        module: 'products',
        documentCount: stockWriteCount,
        payload: <String, dynamic>{
          'productName': updatedName,
          'productBarcode': updatedBarcode,
        },
      );
    }

    final grnSnapshot = await _grnsRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: grnSnapshot.docs.length,
      payload: grnSnapshot.docs.map((doc) => doc.data()).toList(),
    );
    var grnWriteCount = 0;
    for (final grnDoc in grnSnapshot.docs) {
      final data = grnDoc.data();
      final items = List<Map<String, dynamic>>.from(
        (data['items'] as List<dynamic>? ?? const <dynamic>[]).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      var changed = false;
      for (final item in items) {
        final itemName = item['productName']?.toString() ?? '';
        final itemBarcode = item['productBarcode']?.toString() ?? '';
        final matchesName =
            previousName.trim().isNotEmpty &&
            itemName.toLowerCase() == previousName.toLowerCase();
        final matchesBarcode =
            previousBarcode.trim().isNotEmpty &&
            itemBarcode.toLowerCase() == previousBarcode.toLowerCase();
        if (!matchesName && !matchesBarcode) {
          continue;
        }
        item['productName'] = updatedName;
        item['productBarcode'] = updatedBarcode;
        changed = true;
      }
      if (changed) {
        await grnDoc.reference.update({
          'items': items,
          'updatedAt': DateTime.now(),
        });
        grnWriteCount++;
      }
    }
    if (grnWriteCount > 0) {
      await SubscriptionUsageService.instance.recordWrite(
        shopId: shopId,
        module: 'products',
        documentCount: grnWriteCount,
        payload: <String, dynamic>{
          'updatedProductName': updatedName,
          'updatedProductBarcode': updatedBarcode,
        },
      );
    }
  }

  Future<void> _saveCategoryIfMissing(String categoryName) async {
    final normalized = categoryName.trim();
    final normalizedLower = normalized.toLowerCase();
    final existing = await _categoriesRef
        .where('nameLower', isEqualTo: normalizedLower)
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'products',
      documentCount: existing.docs.length,
      payload: existing.docs.map((doc) => doc.data()).toList(),
    );
    if (existing.docs.isNotEmpty) {
      return;
    }

    await _categoriesRef.add({
      'name': normalized,
      'nameLower': normalizedLower,
      'createdAt': DateTime.now(),
    });
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'products',
      payload: <String, dynamic>{
        'name': normalized,
        'nameLower': normalizedLower,
      },
    );
  }

  ProductRecord _mapDocumentToRecord(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ProductRecord(
      cloudId: document.id,
      name: data['name']?.toString() ?? '',
      barcode: data['barcode']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      unit: data['unit']?.toString() ?? 'ITEMS',
      lowStock: (data['lowStockQuantity'] as num?)?.toInt() ?? 0,
      isQuickSelling: data['isQuickSelling'] == true,
      status: _mapStatus(data['status']?.toString()),
    );
  }

  ProductStatus _mapStatus(String? value) {
    return switch (value) {
      'inactive' => ProductStatus.inactive,
      _ => ProductStatus.active,
    };
  }

  DateTime _readSortDate(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'];
    final createdAt = data['createdAt'];
    if (updatedAt is Timestamp) {
      return updatedAt.toDate();
    }
    if (updatedAt is DateTime) {
      return updatedAt;
    }
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }
    if (createdAt is DateTime) {
      return createdAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
