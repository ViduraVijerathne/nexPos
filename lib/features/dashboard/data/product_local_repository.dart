import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'product_repository.dart';

class ProductLocalRepositoryException implements Exception {
  ProductLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Local-only repository for products and categories.
///
/// This keeps the product UI decoupled from Isar-specific details so we can
/// introduce the online mode later without rewriting the screen logic.
class ProductLocalRepository implements ProductRepository {
  const ProductLocalRepository();

  static const int pageSize = 10;

  Future<void> initialize() async {
    final isar = await AppDatabase.instance;
    await _seedIfNeeded(isar);
  }

  Future<ProductPageResult> fetchProducts({
    required int page,
    String? nameQuery,
    String? categoryQuery,
    String? barcodeQuery,
  }) async {
    final isar = await AppDatabase.instance;
    final allProducts = await isar.productEntitys.where().findAll();
    allProducts.sort((left, right) {
      final leftDate = left.updatedAt ?? left.createdAt;
      final rightDate = right.updatedAt ?? right.createdAt;
      return rightDate.compareTo(leftDate);
    });

    final filteredProducts = allProducts.where((entity) {
      if (nameQuery != null && nameQuery.isNotEmpty) {
        return entity.name.toLowerCase().contains(nameQuery.toLowerCase());
      }

      if (categoryQuery != null && categoryQuery.isNotEmpty) {
        return entity.category.toLowerCase().contains(
          categoryQuery.toLowerCase(),
        );
      }

      if (barcodeQuery != null && barcodeQuery.isNotEmpty) {
        return entity.barcode.toLowerCase().contains(
          barcodeQuery.toLowerCase(),
        );
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
        ? <ProductEntity>[]
        : filteredProducts.sublist(start, end);

    return ProductPageResult(
      products: pageItems.map(_mapEntityToRecord).toList(),
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  Future<List<String>> fetchCategorySuggestions(String query) async {
    final isar = await AppDatabase.instance;
    final categories = await isar.categoryEntitys
        .where()
        .sortByName()
        .findAll();
    final normalizedQuery = query.trim().toLowerCase();

    final matches = categories
        .where((category) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return category.name.toLowerCase().contains(normalizedQuery);
        })
        .take(3);

    return matches.map((category) => category.name).toList();
  }

  Future<bool> categoryExists(String categoryName) async {
    final isar = await AppDatabase.instance;

    final existing = await isar.categoryEntitys
        .filter()
        .nameEqualTo(categoryName, caseSensitive: false)
        .findFirst();

    return existing != null;
  }

  Future<String> createCategory(String categoryName) async {
    final isar = await AppDatabase.instance;
    final normalizedName = categoryName.trim();
    if (normalizedName.isEmpty) {
      throw ProductLocalRepositoryException('Category name is required');
    }

    final existing = await isar.categoryEntitys
        .filter()
        .nameEqualTo(normalizedName, caseSensitive: false)
        .findFirst();
    if (existing != null) {
      return existing.name;
    }

    final category = CategoryEntity()
      ..name = normalizedName
      ..createdAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.categoryEntitys.put(category);
    });

    return category.name;
  }

  Future<ProductRecord?> fetchProductByName(String productName) async {
    final isar = await AppDatabase.instance;
    final trimmedName = productName.trim();
    if (trimmedName.isEmpty) {
      return null;
    }

    final entity = await isar.productEntitys
        .filter()
        .nameEqualTo(trimmedName, caseSensitive: false)
        .findFirst();

    if (entity == null) {
      return null;
    }

    return _mapEntityToRecord(entity);
  }

  Future<ProductRecord> saveProduct(ProductRecord product) async {
    final isar = await AppDatabase.instance;
    final normalizedCategory = product.category.trim();
    final trimmedBarcode = product.barcode.trim();

    if (normalizedCategory.isEmpty) {
      throw ProductLocalRepositoryException('Category is required');
    }

    final existingProduct = product.id == null
        ? null
        : await isar.productEntitys.get(product.id!);

    final conflictingProduct = await isar.productEntitys
        .filter()
        .barcodeEqualTo(trimmedBarcode, caseSensitive: false)
        .findFirst();
    if (conflictingProduct != null && conflictingProduct.id != product.id) {
      throw ProductLocalRepositoryException(
        'A product with this barcode already exists',
      );
    }

    await _saveCategoryIfMissing(isar, normalizedCategory);

    final now = DateTime.now();
    final entity = ProductEntity()
      ..id = product.id ?? Isar.autoIncrement
      ..name = product.name.trim()
      ..barcode = trimmedBarcode
      ..category = normalizedCategory
      ..unit = product.unit
      ..lowStockQuantity = product.lowStock
      ..status = _mapStatusToEntity(product.status)
      ..createdAt = existingProduct?.createdAt ?? now
      ..updatedAt = product.id == null ? null : now;

    late final int savedId;
    await isar.writeTxn(() async {
      savedId = await isar.productEntitys.put(entity);
    });

    return _mapEntityToRecord(entity..id = savedId);
  }

  Future<void> _seedIfNeeded(Isar isar) async {
    final hasProducts = await isar.productEntitys.count() > 0;
    final hasCategories = await isar.categoryEntitys.count() > 0;

    if (hasProducts || hasCategories) {
      return;
    }

    final seedProducts = <ProductRecord>[
      // const ProductRecord(
      //   name: '555',
      //   barcode: '8908077319466',
      //   category: '55',
      //   unit: 'ITEMS',
      //   lowStock: 555,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: '444',
      //   barcode: '8909131772822',
      //   category: '444',
      //   unit: 'ITEMS',
      //   lowStock: 44,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: 'product5',
      //   barcode: '40440444',
      //   category: 'busicuts',
      //   unit: 'ITEMS',
      //   lowStock: 22,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: '444',
      //   barcode: '8903332598783',
      //   category: '44',
      //   unit: 'ITEMS',
      //   lowStock: 44,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: 'manchee super cream cracker',
      //   barcode: '40440445',
      //   category: 'busicuts',
      //   unit: 'PACKETS',
      //   lowStock: 20,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: 'dodam',
      //   barcode: '8907916638112',
      //   category: 'd',
      //   unit: 'ITEMS',
      //   lowStock: 2,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: '444',
      //   barcode: '8900439305666',
      //   category: '4',
      //   unit: 'ITEMS',
      //   lowStock: 44,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: '44',
      //   barcode: '8903800200289',
      //   category: '444',
      //   unit: 'ITEMS',
      //   lowStock: 44,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: '5555',
      //   barcode: '8907366713413',
      //   category: '55',
      //   unit: 'ITEMS',
      //   lowStock: 55,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: 'product1',
      //   barcode: '1992222',
      //   category: 'cat1',
      //   unit: 'ITEMS',
      //   lowStock: 22,
      //   status: ProductStatus.active,
      // ),
      // const ProductRecord(
      //   name: 'apple',
      //   barcode: '8902723378806',
      //   category: 'fruits',
      //   unit: 'KG',
      //   lowStock: 10,
      //   status: ProductStatus.active,
      // ),
    ];

    final now = DateTime.now();
    final categoryNames = <String>{
      for (final product in seedProducts) product.category,
    };

    await isar.writeTxn(() async {
      for (final categoryName in categoryNames) {
        final category = CategoryEntity()
          ..name = categoryName
          ..createdAt = now;
        await isar.categoryEntitys.put(category);
      }

      for (final product in seedProducts) {
        final entity = ProductEntity()
          ..name = product.name
          ..barcode = product.barcode
          ..category = product.category
          ..unit = product.unit
          ..lowStockQuantity = product.lowStock
          ..status = _mapStatusToEntity(product.status)
          ..createdAt = now;
        await isar.productEntitys.put(entity);
      }
    });
  }

  Future<void> _saveCategoryIfMissing(Isar isar, String categoryName) async {
    final existing = await isar.categoryEntitys
        .filter()
        .nameEqualTo(categoryName, caseSensitive: false)
        .findFirst();
    if (existing != null) {
      return;
    }

    final category = CategoryEntity()
      ..name = categoryName
      ..createdAt = DateTime.now();

    await isar.categoryEntitys.put(category);
  }

  ProductRecord _mapEntityToRecord(ProductEntity entity) {
    return ProductRecord(
      id: entity.id,
      name: entity.name,
      barcode: entity.barcode,
      category: entity.category,
      unit: entity.unit,
      lowStock: entity.lowStockQuantity,
      status: _mapStatusFromEntity(entity.status),
    );
  }

  ProductEntityStatus _mapStatusToEntity(ProductStatus status) {
    return switch (status) {
      ProductStatus.active => ProductEntityStatus.active,
      ProductStatus.inactive => ProductEntityStatus.inactive,
    };
  }

  ProductStatus _mapStatusFromEntity(ProductEntityStatus status) {
    return switch (status) {
      ProductEntityStatus.active => ProductStatus.active,
      ProductEntityStatus.inactive => ProductStatus.inactive,
    };
  }
}
