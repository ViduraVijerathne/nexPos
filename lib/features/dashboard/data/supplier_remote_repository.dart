import 'package:cloud_firestore/cloud_firestore.dart';

import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'supplier_repository.dart';

class SupplierRemoteRepositoryException implements Exception {
  SupplierRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupplierRemoteRepository implements SupplierRepository {
  SupplierRemoteRepository({required this.shopId});

  static const int pageSize = 10;

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('suppliers');

  CollectionReference<Map<String, dynamic>> get _grnsRef => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(shopId)
      .collection('grns');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw SupplierRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<SupplierPageResult> fetchSuppliers({
    required int page,
    String? searchQuery,
  }) async {
    final supplierSnapshot = await _suppliersRef.get();
    final grnSnapshot = await _grnsRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'suppliers',
      documentCount: supplierSnapshot.docs.length + grnSnapshot.docs.length,
      payload: <Object?>[
        supplierSnapshot.docs.map((doc) => doc.data()).toList(),
        grnSnapshot.docs.map((doc) => doc.data()).toList(),
      ],
    );
    final grnsBySupplier = _groupGrnsBySupplier(grnSnapshot.docs);
    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';

    final filteredSuppliers =
        supplierSnapshot.docs.where((doc) {
          final data = doc.data();
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return (data['supplierName']?.toString() ?? '')
                  .toLowerCase()
                  .contains(normalizedQuery) ||
              (data['companyName']?.toString() ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              (data['email']?.toString() ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              (data['contactNumber']?.toString() ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              (data['companyContact']?.toString() ?? '').toLowerCase().contains(
                normalizedQuery,
              );
        }).toList()..sort((left, right) {
          final leftDate = _readSortDate(left.data());
          final rightDate = _readSortDate(right.data());
          return rightDate.compareTo(leftDate);
        });

    final totalCount = filteredSuppliers.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
        : filteredSuppliers.sublist(start, end);

    return SupplierPageResult(
      suppliers: pageItems.map((doc) {
        final data = doc.data();
        return _mapSupplierDocumentToRecord(
          doc.id,
          data,
          grnsBySupplier[doc.id] ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        );
      }).toList(),
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<SupplierRecord?> fetchSupplierDetails(SupplierRecord supplier) async {
    final docId = supplier.cloudId;
    if (docId == null || docId.isEmpty) {
      throw SupplierRemoteRepositoryException('Supplier identifier is missing');
    }

    final supplierDoc = await _suppliersRef.doc(docId).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'suppliers',
      documentCount: supplierDoc.exists ? 1 : 0,
      payload: supplierDoc.data(),
    );
    if (!supplierDoc.exists) {
      return null;
    }

    final supplierData = supplierDoc.data() ?? <String, dynamic>{};
    QuerySnapshot<Map<String, dynamic>> grnSnapshot = await _grnsRef
        .where('supplierId', isEqualTo: docId)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'suppliers',
      documentCount: grnSnapshot.docs.length,
      payload: grnSnapshot.docs.map((doc) => doc.data()).toList(),
    );
    final supplierName = supplierData['supplierName']?.toString().trim() ?? '';
    if (grnSnapshot.docs.isEmpty && supplierName.isNotEmpty) {
      grnSnapshot = await _grnsRef
          .where('supplierName', isEqualTo: supplierName)
          .get();
      await SubscriptionUsageService.instance.recordRead(
        shopId: shopId,
        module: 'suppliers',
        documentCount: grnSnapshot.docs.length,
        payload: grnSnapshot.docs.map((doc) => doc.data()).toList(),
      );
    }
    final grns = grnSnapshot.docs.toList()
      ..sort((left, right) {
        final leftDate = _readDate(left.data()['date']);
        final rightDate = _readDate(right.data()['date']);
        return rightDate.compareTo(leftDate);
      });

    return _mapSupplierDocumentToRecord(supplierDoc.id, supplierData, grns);
  }

  @override
  Future<SupplierRecord> saveSupplier(SupplierRecord supplier) async {
    final normalizedEmail = supplier.email.trim().toLowerCase();
    final conflict = await _suppliersRef
        .where('emailLower', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'suppliers',
      documentCount: conflict.docs.length,
      payload: conflict.docs.map((doc) => doc.data()).toList(),
    );
    if (conflict.docs.isNotEmpty &&
        conflict.docs.first.id != supplier.cloudId) {
      throw SupplierRemoteRepositoryException(
        'A supplier with this email already exists',
      );
    }

    final docRef = supplier.cloudId == null
        ? _suppliersRef.doc()
        : _suppliersRef.doc(supplier.cloudId);
    final existingSnapshot = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'suppliers',
      documentCount: existingSnapshot.exists ? 1 : 0,
      payload: existingSnapshot.data(),
    );
    final existingData = existingSnapshot.data();
    final now = DateTime.now();

    await docRef.set({
      'supplierName': supplier.supplierName.trim(),
      'companyName': supplier.companyName.trim(),
      'contactNumber': supplier.contactNumber.trim(),
      'companyContact': supplier.companyContact.trim(),
      'email': supplier.email.trim(),
      'emailLower': normalizedEmail,
      'address': supplier.address.trim(),
      'isActive': supplier.isActive,
      'createdAt': existingData?['createdAt'] ?? now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'suppliers',
      payload: <String, dynamic>{
        'supplierName': supplier.supplierName.trim(),
        'companyName': supplier.companyName.trim(),
        'email': supplier.email.trim(),
        'contactNumber': supplier.contactNumber.trim(),
        'isActive': supplier.isActive,
      },
    );

    final saved = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'suppliers',
      documentCount: saved.exists ? 1 : 0,
      payload: saved.data(),
    );
    return _mapSupplierDocumentToRecord(
      saved.id,
      saved.data() ?? <String, dynamic>{},
      const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    );
  }

  @override
  Future<SupplierRecord?> toggleSupplierStatus(SupplierRecord supplier) async {
    final docId = supplier.cloudId;
    if (docId == null || docId.isEmpty) {
      throw SupplierRemoteRepositoryException('Supplier identifier is missing');
    }

    await _suppliersRef.doc(docId).update({
      'isActive': !supplier.isActive,
      'updatedAt': DateTime.now(),
    });
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'suppliers',
      payload: <String, dynamic>{'isActive': !supplier.isActive},
    );

    return fetchSupplierDetails(
      supplier.copyWith(isActive: !supplier.isActive),
    );
  }

  @override
  Future<SupplierRecord?> recordDuePayment({
    required SupplierRecord supplier,
    required String grnId,
    required double amount,
    required String method,
  }) async {
    final snapshot = await _grnsRef
        .where('code', isEqualTo: grnId)
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'suppliers',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    if (snapshot.docs.isEmpty) {
      throw SupplierRemoteRepositoryException('GRN not found');
    }

    final docRef = _grnsRef.doc(snapshot.docs.first.id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final grnDoc = await transaction.get(docRef);
      final data = grnDoc.data() ?? <String, dynamic>{};
      final total =
          (data['total'] as num?)?.toDouble() ??
          (((data['subTotal'] as num?)?.toDouble() ?? 0) -
              ((data['discount'] as num?)?.toDouble() ?? 0));
      final paidAmount = (data['paidAmount'] as num?)?.toDouble() ?? 0;
      final currentDue = (total - paidAmount).clamp(0, double.infinity);
      if (amount <= 0 || amount > currentDue) {
        throw SupplierRemoteRepositoryException('Invalid payment amount');
      }

      final history = List<Map<String, dynamic>>.from(
        (data['paymentHistory'] as List<dynamic>? ?? const <dynamic>[]).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      history.add({
        'paidAt': DateTime.now(),
        'amount': amount,
        'method': method,
        'remainingBalance': (currentDue - amount).clamp(0, double.infinity),
      });

      transaction.update(docRef, {
        'paidAmount': paidAmount + amount,
        'paymentHistory': history,
        'updatedAt': DateTime.now(),
      });
    });
    await SubscriptionUsageService.instance.recordTransaction(
      shopId: shopId,
      module: 'suppliers',
      reads: 1,
      writes: 1,
      payload: <String, dynamic>{
        'grnId': grnId,
        'amount': amount,
        'method': method,
      },
    );

    return fetchSupplierDetails(supplier);
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _groupGrnsBySupplier(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final map = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in docs) {
      final supplierId = doc.data()['supplierId']?.toString().trim();
      if (supplierId == null || supplierId.isEmpty) {
        continue;
      }
      map
          .putIfAbsent(
            supplierId,
            () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )
          .add(doc);
    }

    for (final entry in map.entries) {
      entry.value.sort((left, right) {
        final leftDate = _readDate(left.data()['date']);
        final rightDate = _readDate(right.data()['date']);
        return rightDate.compareTo(leftDate);
      });
    }
    return map;
  }

  SupplierRecord _mapSupplierDocumentToRecord(
    String docId,
    Map<String, dynamic> data,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> grns,
  ) {
    return SupplierRecord(
      id: 0,
      cloudId: docId,
      supplierName: data['supplierName']?.toString() ?? '',
      companyName: data['companyName']?.toString() ?? '',
      contactNumber: data['contactNumber']?.toString() ?? '',
      companyContact: data['companyContact']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
      grns: grns.map(_mapGrnDocumentToRecord).toList(),
    );
  }

  SupplierGrnRecord _mapGrnDocumentToRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final total =
        (data['total'] as num?)?.toDouble() ??
        (((data['subTotal'] as num?)?.toDouble() ?? 0) -
            ((data['discount'] as num?)?.toDouble() ?? 0));
    final paid = (data['paidAmount'] as num?)?.toDouble() ?? 0;
    final due = (total - paid).clamp(0, double.infinity).toDouble();
    final items = data['items'] as List<dynamic>? ?? const <dynamic>[];

    return SupplierGrnRecord(
      grnId: data['code']?.toString() ?? doc.id,
      date: _formatDate(_readDate(data['date'])),
      itemsCount: items.length,
      total: total,
      paid: paid,
      due: due,
      status: _resolveSupplierGrnStatus(due, paid),
    );
  }

  SupplierGrnStatus _resolveSupplierGrnStatus(double due, double paid) {
    if (due <= 0) {
      return SupplierGrnStatus.paid;
    }
    if (paid > 0) {
      return SupplierGrnStatus.partial;
    }
    return SupplierGrnStatus.due;
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

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }
}
