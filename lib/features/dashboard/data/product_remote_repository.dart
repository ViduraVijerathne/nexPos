import 'package:cloud_firestore/cloud_firestore.dart';

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
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.data()['name']?.toString() ?? normalizedName;
    }

    await _categoriesRef.add({
      'name': normalizedName,
      'nameLower': normalizedLower,
      'createdAt': DateTime.now(),
    });
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
    final existingData = existingSnapshot.data();
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
      'status': product.status.name,
      'createdAt': existingData?['createdAt'] ?? now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    final savedSnapshot = await docRef.get();
    return _mapDocumentToRecord(savedSnapshot);
  }

  Future<void> _saveCategoryIfMissing(String categoryName) async {
    final normalized = categoryName.trim();
    final normalizedLower = normalized.toLowerCase();
    final existing = await _categoriesRef
        .where('nameLower', isEqualTo: normalizedLower)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return;
    }

    await _categoriesRef.add({
      'name': normalized,
      'nameLower': normalizedLower,
      'createdAt': DateTime.now(),
    });
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
