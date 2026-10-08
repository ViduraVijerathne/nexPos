import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/change_log_service.dart';
import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'grn_repository.dart';

class GrnRemoteRepositoryException implements Exception {
  GrnRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GrnRemoteRepository implements GrnRepository {
  GrnRemoteRepository({
    required this.shopId,
    FirebaseFirestore? firestore,
    SubscriptionUsageService? usageService,
  }) : _firestoreOverride = firestore,
       _usageOverride = usageService;

  final FirebaseFirestore? _firestoreOverride;
  final SubscriptionUsageService? _usageOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  SubscriptionUsageService get _usage =>
      _usageOverride ?? SubscriptionUsageService.instance;

  static const int pageSize = 10;

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _grnsRef =>
      _firestore.collection('shops').doc(shopId).collection('grns');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('shops').doc(shopId).collection('products');

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore.collection('shops').doc(shopId).collection('suppliers');

  CollectionReference<Map<String, dynamic>> get _stocksRef =>
      _firestore.collection('shops').doc(shopId).collection('stocks');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw GrnRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<GrnPageResult> fetchGrns({
    required int page,
    String? supplierQuery,
    String? dateFrom,
    String? dateTo,
    double? dueAbove,
  }) async {
    final snapshot = await _grnsRef.get();
    await _usage.recordRead(
      shopId: shopId,
      module: 'grn',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final records = snapshot.docs.map(_mapGrnDocumentToRecord).toList()
      ..sort((left, right) => right.date.compareTo(left.date));

    final normalizedSupplier = supplierQuery?.trim().toLowerCase() ?? '';
    final normalizedFrom = dateFrom?.trim() ?? '';
    final normalizedTo = dateTo?.trim() ?? '';

    final filtered = records.where((grn) {
      if (normalizedSupplier.isNotEmpty &&
          !grn.supplier.toLowerCase().contains(normalizedSupplier)) {
        return false;
      }

      if (normalizedFrom.isNotEmpty && grn.date.compareTo(normalizedFrom) < 0) {
        return false;
      }
      if (normalizedTo.isNotEmpty && grn.date.compareTo(normalizedTo) > 0) {
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
        ? <GrnRecord>[]
        : filtered.sublist(start, end);

    return GrnPageResult(
      records: pageItems,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<String>> fetchProductSuggestions() async {
    final snapshot = await _productsRef.orderBy('nameLower').limit(50).get();
    await _usage.recordRead(
      shopId: shopId,
      module: 'grn',
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
  Future<List<String>> fetchSupplierSuggestions() async {
    final snapshot = await _suppliersRef
        .orderBy('supplierName')
        .limit(50)
        .get();
    await _usage.recordRead(
      shopId: shopId,
      module: 'grn',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    return snapshot.docs
        .map((doc) => doc.data()['supplierName']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Future<GrnRecord?> fetchGrnById(String grnId) async {
    final doc = await _grnsRef.doc(grnId).get();
    await _usage.recordRead(
      shopId: shopId,
      module: 'grn',
      documentCount: doc.exists ? 1 : 0,
      payload: doc.data(),
    );
    if (!doc.exists) {
      final snapshot = await _grnsRef
          .where('code', isEqualTo: grnId)
          .limit(1)
          .get();
      await _usage.recordRead(
        shopId: shopId,
        module: 'grn',
        documentCount: snapshot.docs.length,
        payload: snapshot.docs.map((doc) => doc.data()).toList(),
      );
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return _mapGrnDocumentToRecord(snapshot.docs.first);
    }
    return _mapGrnDocumentSnapshotToRecord(doc);
  }

  @override
  Future<GrnRecord> saveGrn(
    GrnRecord record, {
    required bool addToStock,
  }) async {
    final supplierName = record.supplier.trim();
    if (supplierName.isEmpty) {
      throw GrnRemoteRepositoryException('Supplier is required');
    }
    if (record.items.isEmpty) {
      throw GrnRemoteRepositoryException('Add at least one GRN item');
    }

    final supplierId = await _findSupplierIdByName(supplierName);
    final now = DateTime.now();
    final items = record.items
        .map((item) => _itemMap(item.copyWithInStock(addToStock)))
        .toList();
    final payments = record.paidAmount > 0
        ? <Map<String, dynamic>>[
            {
              'paidAt': now,
              'amount': record.paidAmount,
              'method': record.paymentMethod,
              'remainingBalance': (record.total - record.paidAmount).clamp(
                0,
                double.infinity,
              ),
            },
          ]
        : <Map<String, dynamic>>[];

    final stockPayloads = <Map<String, dynamic>>[];
    if (addToStock) {
      for (final item in record.items) {
        stockPayloads.add(await _stockPayload(record.id, item, now));
      }
    }
    final stockRefs = [for (final _ in stockPayloads) _stocksRef.doc()];
    final grnRef = _grnsRef.doc(record.id);
    await _firestore.runTransaction((transaction) async {
      if ((await transaction.get(grnRef)).exists) {
        throw GrnRemoteRepositoryException(
          'This GRN already exists. Reload before trying again.',
        );
      }
      transaction.set(grnRef, {
        'code': record.id,
        'supplierName': supplierName,
        'supplierId': supplierId,
        'date': _parseDate(record.date),
        'subTotal': record.subTotal,
        'discount': record.discount,
        'paidAmount': record.paidAmount,
        'paymentMethod': record.paymentMethod,
        'items': items,
        'paymentHistory': payments,
        'createdAt': now,
        'updatedAt': now,
      });
      for (var i = 0; i < stockPayloads.length; i++) {
        transaction.set(stockRefs[i], stockPayloads[i]);
      }
    });
    await _usage.recordRead(shopId: shopId, module: 'grn', documentCount: 1);
    await _usage.recordWrite(
      shopId: shopId,
      module: 'grn',
      documentCount: 1 + stockPayloads.length,
      payload: items,
    );
    final savedRecord = (await fetchGrnById(record.id))!;
    await ChangeLogService.instance.logChange(
      entityType: ChangeLogEntityType.grn,
      entityId: savedRecord.id,
      action: 'create',
      title: 'Created GRN ${savedRecord.id}',
      details: {
        'supplier': savedRecord.supplier,
        'itemCount': savedRecord.items.length,
        'total': savedRecord.total,
        'paidAmount': savedRecord.paidAmount,
        'dueAmount': savedRecord.dueAmount,
        'addedToStock': addToStock,
      },
    );
    return savedRecord;
  }

  @override
  Future<GrnRecord?> recordDuePayment({
    required String grnId,
    required double amount,
    required String method,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw GrnRemoteRepositoryException('Invalid payment amount');
    }
    final docRef = _grnsRef.doc(grnId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw GrnRemoteRepositoryException('GRN not found');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final total = _readTotal(data);
      final paidAmount = (data['paidAmount'] as num?)?.toDouble() ?? 0;
      final due = (total - paidAmount).clamp(0, double.infinity).toDouble();
      if (amount <= 0 || amount > due) {
        throw GrnRemoteRepositoryException('Invalid payment amount');
      }

      final history = List<Map<String, dynamic>>.from(
        (data['paymentHistory'] as List<dynamic>? ?? const <dynamic>[]).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      history.insert(0, {
        'paidAt': DateTime.now(),
        'amount': amount,
        'method': method,
        'remainingBalance': (due - amount).clamp(0, double.infinity),
      });

      transaction.update(docRef, {
        'paidAmount': paidAmount + amount,
        'paymentHistory': history,
        'updatedAt': DateTime.now(),
      });
    });
    await _usage.recordTransaction(
      shopId: shopId,
      module: 'grn',
      reads: 1,
      writes: 1,
      payload: <String, dynamic>{
        'grnId': grnId,
        'amount': amount,
        'method': method,
      },
    );

    final savedRecord = await fetchGrnById(grnId);
    if (savedRecord != null) {
      await ChangeLogService.instance.logChange(
        entityType: ChangeLogEntityType.grn,
        entityId: savedRecord.id,
        action: 'payment',
        title: 'Recorded GRN payment for ${savedRecord.id}',
        details: {
          'amount': amount,
          'method': method,
          'paidAmount': savedRecord.paidAmount,
          'dueAmount': savedRecord.dueAmount,
        },
      );
    }
    return savedRecord;
  }

  @override
  Future<GrnRecord?> addPendingItemsToStock(String grnId) async {
    final docRef = _grnsRef.doc(grnId);
    final snapshot = await docRef.get();
    await _usage.recordRead(
      shopId: shopId,
      module: 'grn',
      documentCount: snapshot.exists ? 1 : 0,
      payload: snapshot.data(),
    );
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final items = List<Map<String, dynamic>>.from(
      (data['items'] as List<dynamic>? ?? const <dynamic>[]).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    final pending = items.where(
      (item) => (item['inStock'] as bool? ?? false) == false,
    );
    if (pending.isEmpty) {
      return _mapGrnDocumentSnapshotToRecord(snapshot);
    }

    final now = DateTime.now();
    final productBarcodes = <String, String?>{};
    for (final item in pending) {
      final name = item['productName']?.toString() ?? '';
      if (!productBarcodes.containsKey(name)) {
        productBarcodes[name] = await _findProductBarcodeByName(name);
      }
    }
    var addedCount = 0;
    await _firestore.runTransaction((transaction) async {
      addedCount = 0;
      final current = await transaction.get(docRef);
      if (!current.exists) {
        throw GrnRemoteRepositoryException('GRN no longer exists');
      }
      final currentItems = List<Map<String, dynamic>>.from(
        (current.data()?['items'] as List<dynamic>? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final writes =
          <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
      for (final item in currentItems) {
        if (item['inStock'] as bool? ?? false) continue;
        final parsed = _mapMapToItem(item);
        if (!productBarcodes.containsKey(parsed.product)) {
          throw GrnRemoteRepositoryException(
            'GRN changed. Reload before adding stock.',
          );
        }
        writes[_stocksRef.doc()] = _stockMap(
          grnId,
          parsed,
          now,
          productBarcodes[parsed.product],
        );
        item['inStock'] = true;
        addedCount++;
      }
      for (final entry in writes.entries) {
        transaction.set(entry.key, entry.value);
      }
      if (addedCount > 0) {
        transaction.update(docRef, {'items': currentItems, 'updatedAt': now});
      }
    });
    await _usage.recordRead(shopId: shopId, module: 'grn', documentCount: 1);
    if (addedCount > 0) {
      await _usage.recordWrite(
        shopId: shopId,
        module: 'grn',
        documentCount: addedCount + 1,
        payload: {'grnId': grnId},
      );
    }
    final savedRecord = await fetchGrnById(grnId);
    if (savedRecord != null) {
      await ChangeLogService.instance.logChange(
        entityType: ChangeLogEntityType.grn,
        entityId: savedRecord.id,
        action: 'add_to_stock',
        title: 'Added pending GRN items to stock for ${savedRecord.id}',
        details: {'supplier': savedRecord.supplier, 'itemCount': addedCount},
      );
    }
    return savedRecord;
  }

  Future<String?> _findSupplierIdByName(String supplierName) async {
    final snapshot = await _suppliersRef
        .where('supplierName', isEqualTo: supplierName)
        .limit(1)
        .get();
    await _usage.recordRead(
      shopId: shopId,
      module: 'grn',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
  }

  Future<String?> _findProductBarcodeByName(String productName) async {
    final snapshot = await _productsRef
        .where('name', isEqualTo: productName)
        .limit(1)
        .get();
    await _usage.recordRead(
      shopId: shopId,
      module: 'grn',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first.data()['barcode']?.toString();
  }

  Future<Map<String, dynamic>> _stockPayload(
    String grnId,
    GrnItem item,
    DateTime createdAt,
  ) async => _stockMap(
    grnId,
    item,
    createdAt,
    await _findProductBarcodeByName(item.product),
  );

  Map<String, dynamic> _stockMap(
    String grnId,
    GrnItem item,
    DateTime createdAt,
    String? productBarcode,
  ) => {
    'barcode': item.stockBarcode,
    'productName': item.product,
    'productBarcode': productBarcode,
    'grnCode': grnId,
    'initialQuantity': item.quantity,
    'availableQuantity': item.quantity,
    'buyingPrice': item.buyingPrice,
    'sellingPrice': item.sellingPrice,
    'maxDiscount': item.maxDiscount,
    'status': 'active',
    'createdAt': createdAt,
    'updatedAt': createdAt,
  };
  GrnRecord _mapGrnDocumentToRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _mapGrnDocumentSnapshotToRecord(doc);
  }

  GrnRecord _mapGrnDocumentSnapshotToRecord(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final date = _readDate(data['date']);
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => _mapMapToItem(Map<String, dynamic>.from(item as Map)))
        .toList();
    final paymentHistory =
        (data['paymentHistory'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) => _mapPaymentMap(
                Map<String, dynamic>.from(item as Map<String, dynamic>),
              ),
            )
            .toList();

    return GrnRecord(
      id: data['code']?.toString() ?? doc.id,
      supplier: data['supplierName']?.toString() ?? '',
      date: _formatDate(date),
      subTotal: (data['subTotal'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      items: items,
      paymentHistory: paymentHistory,
      paymentMethod: data['paymentMethod']?.toString() ?? 'Cash',
    );
  }

  Map<String, dynamic> _itemMap(GrnItem item) {
    return {
      'productName': item.product,
      'stockBarcode': item.stockBarcode,
      'quantity': item.quantity,
      'buyingPrice': item.buyingPrice,
      'sellingPrice': item.sellingPrice,
      'maxDiscount': item.maxDiscount,
      'inStock': item.inStock,
    };
  }

  GrnItem _mapMapToItem(Map<String, dynamic> map) {
    return GrnItem(
      product: map['productName']?.toString() ?? '',
      stockBarcode: map['stockBarcode']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      buyingPrice: (map['buyingPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0,
      maxDiscount: (map['maxDiscount'] as num?)?.toDouble() ?? 0,
      inStock: map['inStock'] as bool? ?? false,
    );
  }

  PaymentHistory _mapPaymentMap(Map<String, dynamic> map) {
    final paidAt = _readDateTime(map['paidAt']);
    return PaymentHistory(
      dateTime: _formatDateTime(paidAt),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method: map['method']?.toString() ?? 'Cash',
      remainingBalance: (map['remainingBalance'] as num?)?.toDouble() ?? 0,
    );
  }

  double _readTotal(Map<String, dynamic> data) {
    final subTotal = (data['subTotal'] as num?)?.toDouble() ?? 0;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0;
    return subTotal - discount;
  }

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  DateTime _readDateTime(dynamic value) => _readDate(value);

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
}
