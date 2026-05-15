import 'package:cloud_firestore/cloud_firestore.dart';

import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import '../../settings/services/app_settings_service.dart';
import 'pos_repository.dart';

class PosRemoteRepositoryException implements Exception {
  PosRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PosRemoteRepository implements PosRepository {
  PosRemoteRepository({required this.shopId});

  static const PosCustomerOption walkInCustomer = PosCustomerOption(
    id: null,
    cloudId: null,
    name: 'Walk-in Customer',
    phone: 'walk-in',
    email: '',
    isWalkIn: true,
  );

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

  CollectionReference<Map<String, dynamic>> get _customersRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('customers');

  CollectionReference<Map<String, dynamic>> get _invoicesRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('invoices');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw PosRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<PosCatalogResult> fetchCatalog({
    String? searchQuery,
    String? category,
    PosCatalogLoadMode loadMode = PosCatalogLoadMode.defaultOrder,
  }) async {
    final stockSnapshot = await _stocksRef.get();
    final productSnapshot = await _productsRef.get();
    final invoiceSnapshot = await _invoicesRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'pos',
      documentCount:
          stockSnapshot.docs.length +
          productSnapshot.docs.length +
          invoiceSnapshot.docs.length,
      payload: <Object?>[
        stockSnapshot.docs.map((doc) => doc.data()).toList(),
        productSnapshot.docs.map((doc) => doc.data()).toList(),
        invoiceSnapshot.docs.map((doc) => doc.data()).toList(),
      ],
    );

    final productsByName = <String, List<Map<String, dynamic>>>{};
    final productsByBarcode = <String, Map<String, dynamic>>{};
    for (final doc in productSnapshot.docs) {
      final data = doc.data();
      final nameKey = data['name']?.toString().trim().toLowerCase() ?? '';
      if (nameKey.isNotEmpty) {
        productsByName
            .putIfAbsent(nameKey, () => <Map<String, dynamic>>[])
            .add(data);
      }
      final barcodeKey = data['barcode']?.toString().trim().toLowerCase() ?? '';
      if (barcodeKey.isNotEmpty) {
        productsByBarcode[barcodeKey] = data;
      }
    }

    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';
    final normalizedCategory = category?.trim() ?? 'All';
    final appliedLoadMode = normalizedQuery.isEmpty
        ? loadMode
        : PosCatalogLoadMode.defaultOrder;
    final salesByProductKey = _buildRemoteSalesMap(invoiceSnapshot.docs);

    final items =
        stockSnapshot.docs
            .where((doc) {
              final data = doc.data();
              final isActive =
                  (data['status']?.toString() ?? 'active') == 'active';
              final availableQty =
                  (data['availableQuantity'] as num?)?.toInt() ?? 0;
              if (!isActive || availableQty <= 0) {
                return false;
              }

              final productName = data['productName']?.toString() ?? '';
              final product = _resolveProduct(
                stockData: data,
                productsByName: productsByName,
                productsByBarcode: productsByBarcode,
              );
              final productBarcode =
                  product?['barcode']?.toString() ??
                  data['productBarcode']?.toString() ??
                  '';
              final productCategory =
                  product?['category']?.toString() ?? 'Uncategorized';
              final isQuickSelling = product?['isQuickSelling'] == true;

              final matchesQuery =
                  normalizedQuery.isEmpty ||
                  productName.toLowerCase().contains(normalizedQuery) ||
                  (data['barcode']?.toString() ?? '').toLowerCase().contains(
                    normalizedQuery,
                  ) ||
                  productBarcode.toLowerCase().contains(normalizedQuery);
              final matchesCategory =
                  normalizedCategory == 'All' ||
                  productCategory == normalizedCategory;
              final matchesLoadMode =
                  appliedLoadMode != PosCatalogLoadMode.quickSelling ||
                  isQuickSelling;

              return matchesQuery && matchesCategory && matchesLoadMode;
            })
            .map((doc) {
              final data = doc.data();
              final productName = data['productName']?.toString() ?? '';
              final product = _resolveProduct(
                stockData: data,
                productsByName: productsByName,
                productsByBarcode: productsByBarcode,
              );
              return PosCatalogItem(
                stockId: null,
                stockCloudId: doc.id,
                stockBarcode: data['barcode']?.toString() ?? '',
                productName: productName,
                productBarcode:
                    product?['barcode']?.toString() ??
                    data['productBarcode']?.toString() ??
                    '',
                category: product?['category']?.toString() ?? 'Uncategorized',
                availableQty: (data['availableQuantity'] as num?)?.toInt() ?? 0,
                sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
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

  @override
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

  @override
  Future<List<PosCustomerOption>> searchCustomers(String query) async {
    final snapshot = await _customersRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'pos',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final normalized = query.trim().toLowerCase();

    final docs =
        snapshot.docs.where((doc) {
          if (normalized.isEmpty) {
            return true;
          }
          final data = doc.data();
          return (data['name']?.toString() ?? '').toLowerCase().contains(
                normalized,
              ) ||
              (data['phone']?.toString() ?? '').toLowerCase().contains(
                normalized,
              );
        }).toList()..sort((left, right) {
          final leftDate = _readSortDate(left.data());
          final rightDate = _readSortDate(right.data());
          return rightDate.compareTo(leftDate);
        });

    return docs.take(6).map((doc) {
      final data = doc.data();
      return PosCustomerOption(
        id: null,
        cloudId: doc.id,
        name: data['name']?.toString() ?? '',
        phone: data['phone']?.toString() ?? '',
        email: data['email']?.toString() ?? '',
      );
    }).toList();
  }

  @override
  Future<PosCheckoutResult> processSale({
    required List<PosCartItem> items,
    required PosCustomerOption customer,
    required String paymentMethod,
    required double amountPaid,
    required String cashierName,
    required double taxAmount,
  }) async {
    if (items.isEmpty) {
      throw PosRemoteRepositoryException('Add at least one item to the cart');
    }

    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final total = subtotal + taxAmount;
    if (amountPaid < total) {
      throw PosRemoteRepositoryException(
        'Paid amount must be equal to or greater than total',
      );
    }

    final stockIds = items
        .map((item) => item.stockCloudId)
        .whereType<String>()
        .toSet()
        .toList();
    if (stockIds.length != items.length) {
      throw PosRemoteRepositoryException(
        'One or more stock items are missing remote identifiers',
      );
    }

    final invoiceNumber = await _generateNextInvoiceNumber();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final stockRefs = {
        for (final stockId in stockIds) stockId: _stocksRef.doc(stockId),
      };
      final stockSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final entry in stockRefs.entries) {
        final snapshot = await transaction.get(entry.value);
        if (!snapshot.exists) {
          throw PosRemoteRepositoryException(
            'One or more stock items are no longer available',
          );
        }
        stockSnapshots[entry.key] = snapshot;
      }

      for (final item in items) {
        final snapshot = stockSnapshots[item.stockCloudId]!;
        final data = snapshot.data() ?? <String, dynamic>{};
        final status = data['status']?.toString() ?? 'active';
        final availableQty = (data['availableQuantity'] as num?)?.toInt() ?? 0;
        if (status != 'active') {
          throw PosRemoteRepositoryException(
            'One or more stock items are no longer available',
          );
        }
        if (availableQty < item.quantity) {
          throw PosRemoteRepositoryException(
            'Not enough available quantity for ${item.productName}',
          );
        }
      }

      for (final item in items) {
        final ref = stockRefs[item.stockCloudId]!;
        final snapshot = stockSnapshots[item.stockCloudId]!;
        final data = snapshot.data() ?? <String, dynamic>{};
        final availableQty = (data['availableQuantity'] as num?)?.toInt() ?? 0;
        transaction.update(ref, {
          'availableQuantity': availableQty - item.quantity,
          'updatedAt': DateTime.now(),
        });
      }

      final invoiceRef = _invoicesRef.doc();
      transaction.set(invoiceRef, {
        'invoiceNumber': invoiceNumber,
        'customerId': customer.cloudId,
        'customerName': customer.name,
        'customerCode': customer.isWalkIn ? 'walk-in' : customer.phone,
        'issuedAt': DateTime.now(),
        'totalAmount': total,
        'subTotal': subtotal,
        'taxAmount': taxAmount,
        'status': 'paid',
        'paymentMethod': paymentMethod,
        'cashierName': cashierName,
        'shopId': shopId,
        'items': items
            .map(
              (item) => {
                'name': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'stockId': item.stockCloudId,
                'stockBarcode': item.stockBarcode,
                'productBarcode': item.productBarcode,
              },
            )
            .toList(),
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
    });
    await SubscriptionUsageService.instance.recordTransaction(
      shopId: shopId,
      module: 'pos',
      reads: stockIds.length,
      writes: stockIds.length + 1,
      payload: <String, dynamic>{
        'invoiceNumber': invoiceNumber,
        'itemCount': items.length,
        'customerName': customer.name,
        'paymentMethod': paymentMethod,
        'amountPaid': amountPaid,
      },
    );

    return PosCheckoutResult(
      invoiceNumber: invoiceNumber,
      changeAmount: amountPaid - total,
    );
  }

  Future<String> _generateNextInvoiceNumber() async {
    final invoices = await _invoicesRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'pos',
      documentCount: invoices.docs.length,
      payload: invoices.docs.map((doc) => doc.data()).toList(),
    );
    var maxNumber = 0;
    for (final invoice in invoices.docs) {
      final value = invoice.data()['invoiceNumber']?.toString().trim() ?? '';
      final match = RegExp(r'^INV-(\d+)$').firstMatch(value);
      final parsed = int.tryParse(match?.group(1) ?? '');
      if (parsed != null && parsed > maxNumber) {
        maxNumber = parsed;
      }
    }
    final next = maxNumber + 1;
    return 'INV-${next.toString().padLeft(6, '0')}';
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

  Map<String, dynamic>? _resolveProduct({
    required Map<String, dynamic> stockData,
    required Map<String, List<Map<String, dynamic>>> productsByName,
    required Map<String, Map<String, dynamic>> productsByBarcode,
  }) {
    final barcodeKey =
        stockData['productBarcode']?.toString().trim().toLowerCase() ?? '';
    if (barcodeKey.isNotEmpty) {
      final matchedByBarcode = productsByBarcode[barcodeKey];
      if (matchedByBarcode != null) {
        return matchedByBarcode;
      }
    }

    final productName =
        stockData['productName']?.toString().trim().toLowerCase() ?? '';
    final namedProducts = productsByName[productName];
    if (namedProducts == null || namedProducts.isEmpty) {
      return null;
    }
    return namedProducts.first;
  }

  Map<String, int> _buildRemoteSalesMap(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> invoiceDocs,
  ) {
    final sales = <String, int>{};
    for (final doc in invoiceDocs) {
      final items = doc.data()['items'] as List<dynamic>? ?? const <dynamic>[];
      for (final rawItem in items) {
        if (rawItem is! Map) {
          continue;
        }
        final item = Map<String, dynamic>.from(rawItem);
        final barcodeKey =
            item['productBarcode']?.toString().trim().toLowerCase() ?? '';
        final nameKey = item['name']?.toString().trim().toLowerCase() ?? '';
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (quantity <= 0) {
          continue;
        }
        if (barcodeKey.isNotEmpty) {
          sales.update(
            barcodeKey,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        } else if (nameKey.isNotEmpty) {
          sales.update(
            nameKey,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        }
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
