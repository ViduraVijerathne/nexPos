import 'package:cloud_firestore/cloud_firestore.dart';

import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'label_printer_repository.dart';

class LabelPrinterRemoteRepository implements LabelPrinterRepository {
  LabelPrinterRemoteRepository({required this.shopId});

  static const int pageSize = 10;

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _stocksRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('stocks');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw Exception(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<LabelPrinterPageResult> fetchItems({
    required LabelPrinterSource source,
    required int page,
    String? searchQuery,
  }) async {
    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';

    if (source == LabelPrinterSource.product) {
      final snapshot = await _productsRef.get();
      await SubscriptionUsageService.instance.recordRead(
        shopId: shopId,
        module: 'label_printer',
        documentCount: snapshot.docs.length,
        payload: snapshot.docs.map((doc) => doc.data()).toList(),
      );

      final items = snapshot.docs.toList()
        ..sort((left, right) {
          final leftDate = _readSortDate(left.data());
          final rightDate = _readSortDate(right.data());
          return rightDate.compareTo(leftDate);
        });

      final filtered = items
          .where(
            (doc) =>
                (doc.data()['status']?.toString().toLowerCase() ?? 'active') ==
                'active',
          )
          .where((doc) {
            final data = doc.data();
            final name = data['name']?.toString() ?? '';
            final barcode = data['barcode']?.toString() ?? '';
            final category = data['category']?.toString() ?? '';
            if (normalizedQuery.isEmpty) {
              return true;
            }

            return name.toLowerCase().contains(normalizedQuery) ||
                barcode.toLowerCase().contains(normalizedQuery) ||
                category.toLowerCase().contains(normalizedQuery);
          })
          .map(
            (doc) => LabelPrinterItem(
              source: LabelPrinterSource.product,
              id: doc.id,
              title: doc.data()['name']?.toString() ?? '',
              barcode: doc.data()['barcode']?.toString() ?? '',
              secondaryText:
                  '${doc.data()['category']?.toString() ?? 'Uncategorized'} • ${doc.data()['unit']?.toString() ?? 'ITEMS'}',
            ),
          )
          .toList();

      return _buildPage(items: filtered, page: page);
    }

    final snapshot = await _stocksRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'label_printer',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final items = snapshot.docs.toList()
      ..sort((left, right) {
        final leftDate = _readSortDate(left.data());
        final rightDate = _readSortDate(right.data());
        return rightDate.compareTo(leftDate);
      });

    final filtered = items
        .where((doc) {
          final data = doc.data();
          final status = data['status']?.toString().toLowerCase() ?? 'active';
          final availableQty =
              (data['availableQuantity'] as num?)?.toInt() ?? 0;
          final expiryRaw = data['expiryDate'];
          final expiryDate = _readDate(expiryRaw);
          final isExpired =
              expiryDate != null && expiryDate.isBefore(startOfToday);
          if (status != 'active' || availableQty <= 0 || isExpired) {
            return false;
          }

          final productName = data['productName']?.toString() ?? '';
          final barcode = data['barcode']?.toString() ?? '';
          final productBarcode = data['productBarcode']?.toString() ?? '';
          final grnCode = data['grnCode']?.toString() ?? '';

          if (normalizedQuery.isEmpty) {
            return true;
          }

          return productName.toLowerCase().contains(normalizedQuery) ||
              barcode.toLowerCase().contains(normalizedQuery) ||
              productBarcode.toLowerCase().contains(normalizedQuery) ||
              grnCode.toLowerCase().contains(normalizedQuery);
        })
        .map((doc) {
          final data = doc.data();
          return LabelPrinterItem(
            source: LabelPrinterSource.stock,
            id: doc.id,
            title: data['productName']?.toString() ?? '',
            barcode: data['barcode']?.toString() ?? '',
            productBarcode: data['productBarcode']?.toString(),
            secondaryText:
                'Product Barcode: ${data['productBarcode']?.toString() ?? 'N/A'} • GRN: ${data['grnCode']?.toString() ?? 'Not Assigned'}',
            quantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
          );
        })
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

  DateTime _readSortDate(Map<String, dynamic> data) {
    final updated = _readDate(data['updatedAt']);
    final created = _readDate(data['createdAt']);
    return updated ?? created ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
