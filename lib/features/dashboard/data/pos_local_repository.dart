import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import '../../settings/services/app_settings_service.dart';
import 'customer_local_repository.dart';
import 'pos_repository.dart';
import 'stock_local_repository.dart';

class PosLocalRepositoryException implements Exception {
  PosLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PosLocalRepository implements PosRepository {
  const PosLocalRepository();

  static const PosCustomerOption walkInCustomer = PosCustomerOption(
    id: null,
    cloudId: null,
    name: 'Walk-in Customer',
    phone: 'walk-in',
    email: '',
    isWalkIn: true,
  );

  Future<void> initialize() async {
    await const StockLocalRepository().initialize();
    await const CustomerLocalRepository().initialize();
  }

  Future<PosCatalogResult> fetchCatalog({
    String? searchQuery,
    String? category,
    PosCatalogLoadMode loadMode = PosCatalogLoadMode.defaultOrder,
  }) async {
    final isar = await AppDatabase.instance;
    final products = await isar.productEntitys.where().findAll();
    final productsByName = <String, List<ProductEntity>>{};
    for (final product in products) {
      productsByName
          .putIfAbsent(product.name.toLowerCase(), () => <ProductEntity>[])
          .add(product);
    }
    final productsByBarcode = <String, ProductEntity>{
      for (final product in products) product.barcode.toLowerCase(): product,
    };

    final activeStocks = await isar.stockEntitys.where().findAll();
    final invoices = await isar.invoiceEntitys.where().findAll();
    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';
    final normalizedCategory = category?.trim() ?? 'All';
    final appliedLoadMode = normalizedQuery.isEmpty
        ? loadMode
        : PosCatalogLoadMode.defaultOrder;
    final salesByProductKey = _buildLocalSalesMap(invoices);

    final items =
        activeStocks
            .where((stock) {
              if (stock.status != StockEntityStatus.active ||
                  stock.availableQuantity <= 0) {
                return false;
              }

              final product = _resolveProduct(
                stock: stock,
                productsByName: productsByName,
                productsByBarcode: productsByBarcode,
              );
              final productBarcode =
                  product?.barcode ?? stock.productBarcode ?? '';
              final productCategory = product?.category ?? 'Uncategorized';
              final isQuickSelling = product?.isQuickSelling ?? false;

              final matchesQuery =
                  normalizedQuery.isEmpty ||
                  stock.productName.toLowerCase().contains(normalizedQuery) ||
                  stock.barcode.toLowerCase().contains(normalizedQuery) ||
                  productBarcode.toLowerCase().contains(normalizedQuery);
              final matchesCategory =
                  normalizedCategory == 'All' ||
                  productCategory == normalizedCategory;
              final matchesLoadMode =
                  appliedLoadMode != PosCatalogLoadMode.quickSelling ||
                  isQuickSelling;

              return matchesQuery && matchesCategory && matchesLoadMode;
            })
            .map((stock) {
              final product = _resolveProduct(
                stock: stock,
                productsByName: productsByName,
                productsByBarcode: productsByBarcode,
              );
              return PosCatalogItem(
                stockId: stock.id,
                stockCloudId: null,
                stockBarcode: stock.barcode,
                productName: stock.productName,
                productBarcode: product?.barcode ?? stock.productBarcode ?? '',
                category: product?.category ?? 'Uncategorized',
                availableQty: stock.availableQuantity,
                sellingPrice: stock.sellingPrice,
              );
            })
            .toList()
          ..sort(
            (left, right) => _compareCatalogItems(
              left,
              right,
              loadMode: appliedLoadMode,
              salesByProductKey: salesByProductKey,
            ),
          );

    final categories = <String>{
      'All',
      ...items
          .map((item) => item.category)
          .where((value) => value.trim().isNotEmpty),
    }.toList();

    return PosCatalogResult(items: items, categories: categories);
  }

  Future<PosCatalogItem?> findExactCatalogMatch(String value) async {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      return null;
    }

    final catalog = await fetchCatalog();
    for (final item in catalog.items) {
      if (item.stockBarcode.toLowerCase() == query ||
          item.productBarcode.toLowerCase() == query) {
        return item;
      }
    }
    return null;
  }

  Future<List<PosCustomerOption>> searchCustomers(String query) async {
    final isar = await AppDatabase.instance;
    final customers = await isar.customerEntitys.where().findAll();
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return customers
          .take(6)
          .map(
            (customer) => PosCustomerOption(
              id: customer.id,
              cloudId: null,
              name: customer.name,
              phone: customer.phone,
              email: customer.email,
            ),
          )
          .toList();
    }

    final matches =
        customers.where((customer) {
          return customer.name.toLowerCase().contains(normalized) ||
              customer.phone.toLowerCase().contains(normalized);
        }).toList()..sort((left, right) {
          final leftDate = left.updatedAt ?? left.createdAt;
          final rightDate = right.updatedAt ?? right.createdAt;
          return rightDate.compareTo(leftDate);
        });

    return matches
        .take(6)
        .map(
          (customer) => PosCustomerOption(
            id: customer.id,
            cloudId: null,
            name: customer.name,
            phone: customer.phone,
            email: customer.email,
          ),
        )
        .toList();
  }

  Future<PosCheckoutResult> processSale({
    required List<PosCartItem> items,
    required PosCustomerOption customer,
    required String paymentMethod,
    required double amountPaid,
    required String cashierName,
    required double discountAmount,
    required double taxAmount,
  }) async {
    if (items.isEmpty) {
      throw PosLocalRepositoryException('Add at least one item to the cart');
    }

    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final sanitizedDiscount = discountAmount.clamp(0, subtotal).toDouble();
    final total = (subtotal - sanitizedDiscount) + taxAmount;
    if (amountPaid < total) {
      throw PosLocalRepositoryException(
        'Paid amount must be equal to or greater than total',
      );
    }

    final isar = await AppDatabase.instance;
    final stockIds = items
        .map((item) => item.stockId)
        .whereType<int>()
        .toList();
    final stocks = await isar.stockEntitys.getAll(stockIds);
    final stocksById = <int, StockEntity>{
      for (final stock in stocks.whereType<StockEntity>()) stock.id: stock,
    };

    for (final item in items) {
      final stock = stocksById[item.stockId];
      if (stock == null || stock.status != StockEntityStatus.active) {
        throw PosLocalRepositoryException(
          'One or more stock items are no longer available',
        );
      }
      if (stock.availableQuantity < item.quantity) {
        throw PosLocalRepositoryException(
          'Not enough available quantity for ${item.productName}',
        );
      }
    }

    final invoiceNumber = await _generateNextInvoiceNumber(isar);
    final invoice = InvoiceEntity()
      ..invoiceNumber = invoiceNumber
      ..customerName = customer.name
      ..customerCode = customer.isWalkIn ? 'walk-in' : customer.phone
      ..customerDbId = customer.id
      ..issuedAt = DateTime.now()
      ..discountAmount = sanitizedDiscount
      ..totalAmount = total
      ..status = InvoiceEntityStatus.paid
      ..paymentMethod = paymentMethod
      ..cashierName = cashierName
      ..items = items.map((item) {
        final line = InvoiceLineItemEmbedded()
          ..name = item.productName
          ..quantity = item.quantity
          ..unitPrice = item.unitPrice;
        return line;
      }).toList()
      ..createdAt = DateTime.now();

    await isar.writeTxn(() async {
      for (final item in items) {
        final stock = stocksById[item.stockId]!;
        stock
          ..availableQuantity -= item.quantity
          ..updatedAt = DateTime.now();
        await isar.stockEntitys.put(stock);
      }
      await isar.invoiceEntitys.put(invoice);
    });

    return PosCheckoutResult(
      invoiceNumber: invoiceNumber,
      changeAmount: amountPaid - total,
    );
  }

  Future<String> _generateNextInvoiceNumber(Isar isar) async {
    final invoices = await isar.invoiceEntitys.where().findAll();
    var maxNumber = 0;
    for (final invoice in invoices) {
      final value = invoice.invoiceNumber.trim();
      final match = RegExp(r'^INV-(\d+)$').firstMatch(value);
      final parsed = int.tryParse(match?.group(1) ?? '');
      if (parsed != null && parsed > maxNumber) {
        maxNumber = parsed;
      }
    }
    final next = maxNumber + 1;
    return 'INV-${next.toString().padLeft(6, '0')}';
  }

  ProductEntity? _resolveProduct({
    required StockEntity stock,
    required Map<String, List<ProductEntity>> productsByName,
    required Map<String, ProductEntity> productsByBarcode,
  }) {
    final normalizedBarcode = stock.productBarcode?.trim().toLowerCase();
    if (normalizedBarcode != null && normalizedBarcode.isNotEmpty) {
      final matchedByBarcode = productsByBarcode[normalizedBarcode];
      if (matchedByBarcode != null) {
        return matchedByBarcode;
      }
    }

    final namedProducts = productsByName[stock.productName.toLowerCase()];
    if (namedProducts == null || namedProducts.isEmpty) {
      return null;
    }
    return namedProducts.first;
  }

  Map<String, int> _buildLocalSalesMap(List<InvoiceEntity> invoices) {
    final sales = <String, int>{};
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        final key = item.name.trim().toLowerCase();
        if (key.isEmpty) {
          continue;
        }
        sales.update(
          key,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    return sales;
  }

  int _compareCatalogItems(
    PosCatalogItem left,
    PosCatalogItem right, {
    required PosCatalogLoadMode loadMode,
    required Map<String, int> salesByProductKey,
  }) {
    if (loadMode == PosCatalogLoadMode.highStock) {
      final qtyCompare = right.availableQty.compareTo(left.availableQty);
      if (qtyCompare != 0) {
        return qtyCompare;
      }
    }

    if (loadMode == PosCatalogLoadMode.mostSelling) {
      final rightSales =
          salesByProductKey[right.productBarcode.toLowerCase()] ??
          salesByProductKey[right.productName.toLowerCase()] ??
          0;
      final leftSales =
          salesByProductKey[left.productBarcode.toLowerCase()] ??
          salesByProductKey[left.productName.toLowerCase()] ??
          0;
      final salesCompare = rightSales.compareTo(leftSales);
      if (salesCompare != 0) {
        return salesCompare;
      }
    }

    final productCompare = left.productName.toLowerCase().compareTo(
      right.productName.toLowerCase(),
    );
    if (productCompare != 0) {
      return productCompare;
    }
    return left.stockBarcode.toLowerCase().compareTo(
      right.stockBarcode.toLowerCase(),
    );
  }
}
