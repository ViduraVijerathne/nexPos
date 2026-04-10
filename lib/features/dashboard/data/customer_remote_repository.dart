import 'package:cloud_firestore/cloud_firestore.dart';

import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'customer_repository.dart';

class CustomerRemoteRepositoryException implements Exception {
  CustomerRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomerRemoteRepository implements CustomerRepository {
  CustomerRemoteRepository({required this.shopId});

  static const int pageSize = 10;

  final String shopId;

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
      throw CustomerRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<CustomerPageResult> fetchCustomers({
    required int page,
    String? searchQuery,
    double? spentLessThan,
    double? spentGreaterThan,
  }) async {
    final customerSnapshot = await _customersRef.get();
    final invoiceSnapshot = await _invoicesRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'customers',
      documentCount: customerSnapshot.docs.length + invoiceSnapshot.docs.length,
      payload: <Object?>[
        customerSnapshot.docs.map((doc) => doc.data()).toList(),
        invoiceSnapshot.docs.map((doc) => doc.data()).toList(),
      ],
    );
    final invoicesByCustomer = _groupInvoicesByCustomer(invoiceSnapshot.docs);
    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';

    final filteredCustomers =
        customerSnapshot.docs.where((doc) {
          final data = doc.data();
          final invoices =
              invoicesByCustomer[doc.id] ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final totalSpent = invoices.fold<double>(
            0,
            (sum, invoice) => sum + _readInvoiceTotal(invoice.data()),
          );

          final matchesQuery =
              normalizedQuery.isEmpty ||
              (data['name']?.toString() ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              (data['phone']?.toString() ?? '').toLowerCase().contains(
                normalizedQuery,
              ) ||
              (data['email']?.toString() ?? '').toLowerCase().contains(
                normalizedQuery,
              );

          final matchesLess =
              spentLessThan == null || totalSpent < spentLessThan;
          final matchesGreater =
              spentGreaterThan == null || totalSpent > spentGreaterThan;

          return matchesQuery && matchesLess && matchesGreater;
        }).toList()..sort((left, right) {
          final leftDate = _readSortDate(left.data());
          final rightDate = _readSortDate(right.data());
          return rightDate.compareTo(leftDate);
        });

    final totalCount = filteredCustomers.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
        : filteredCustomers.sublist(start, end);

    return CustomerPageResult(
      customers: pageItems.map((doc) {
        final invoices =
            invoicesByCustomer[doc.id] ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return _mapCustomerDocumentToRecord(doc.id, doc.data(), invoices);
      }).toList(),
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<CustomerRecord?> fetchCustomerDetails(CustomerRecord customer) async {
    final docId = customer.cloudId;
    if (docId == null || docId.isEmpty) {
      throw CustomerRemoteRepositoryException('Customer identifier is missing');
    }

    final customerDoc = await _customersRef.doc(docId).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'customers',
      documentCount: customerDoc.exists ? 1 : 0,
      payload: customerDoc.data(),
    );
    if (!customerDoc.exists) {
      return null;
    }

    QuerySnapshot<Map<String, dynamic>> invoices = await _invoicesRef
        .where('customerId', isEqualTo: docId)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'customers',
      documentCount: invoices.docs.length,
      payload: invoices.docs.map((doc) => doc.data()).toList(),
    );
    final customerName =
        (customerDoc.data() ?? const <String, dynamic>{})['name']
            ?.toString()
            .trim() ??
        '';
    if (invoices.docs.isEmpty && customerName.isNotEmpty) {
      invoices = await _invoicesRef
          .where('customerName', isEqualTo: customerName)
          .get();
      await SubscriptionUsageService.instance.recordRead(
        shopId: shopId,
        module: 'customers',
        documentCount: invoices.docs.length,
        payload: invoices.docs.map((doc) => doc.data()).toList(),
      );
    }

    final invoiceDocs = invoices.docs.toList()
      ..sort((left, right) {
        final leftDate = _readIssuedAt(left.data());
        final rightDate = _readIssuedAt(right.data());
        return rightDate.compareTo(leftDate);
      });

    return _mapCustomerDocumentToRecord(
      customerDoc.id,
      customerDoc.data() ?? <String, dynamic>{},
      invoiceDocs,
    );
  }

  @override
  Future<CustomerRecord?> fetchCustomerByPhone(String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return null;
    }

    final snapshot = await _customersRef
        .where('phoneLower', isEqualTo: trimmedPhone.toLowerCase())
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'customers',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return fetchCustomerDetails(
      CustomerRecord(
        id: 0,
        cloudId: doc.id,
        name: doc.data()['name']?.toString() ?? '',
        email: doc.data()['email']?.toString() ?? '',
        phone: doc.data()['phone']?.toString() ?? '',
        address: doc.data()['address']?.toString() ?? '',
        joinDate: '',
        invoices: const [],
      ),
    );
  }

  @override
  Future<CustomerRecord> saveCustomer(CustomerRecord customer) async {
    final normalizedEmail = customer.email.trim().toLowerCase();
    final trimmedEmail = customer.email.trim();
    if (trimmedEmail.isNotEmpty) {
      final conflict = await _customersRef
          .where('emailLower', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      await SubscriptionUsageService.instance.recordRead(
        shopId: shopId,
        module: 'customers',
        documentCount: conflict.docs.length,
        payload: conflict.docs.map((doc) => doc.data()).toList(),
      );
      if (conflict.docs.isNotEmpty &&
          conflict.docs.first.id != customer.cloudId) {
        throw CustomerRemoteRepositoryException(
          'A customer with this email already exists',
        );
      }
    }

    final docRef = customer.cloudId == null
        ? _customersRef.doc()
        : _customersRef.doc(customer.cloudId);
    final existing = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'customers',
      documentCount: existing.exists ? 1 : 0,
      payload: existing.data(),
    );
    final existingData = existing.data();
    final now = DateTime.now();

    await docRef.set({
      'name': customer.name.trim(),
      'nameLower': customer.name.trim().toLowerCase(),
      'email': trimmedEmail,
      'emailLower': normalizedEmail,
      'phone': customer.phone.trim(),
      'phoneLower': customer.phone.trim().toLowerCase(),
      'address': customer.address.trim(),
      'joinDate': existingData?['joinDate'] ?? now,
      'createdAt': existingData?['createdAt'] ?? now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'customers',
      payload: <String, dynamic>{
        'name': customer.name.trim(),
        'email': trimmedEmail,
        'phone': customer.phone.trim(),
        'address': customer.address.trim(),
      },
    );

    final saved = await docRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'customers',
      documentCount: saved.exists ? 1 : 0,
      payload: saved.data(),
    );
    return _mapCustomerDocumentToRecord(
      saved.id,
      saved.data() ?? <String, dynamic>{},
      const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    );
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _groupInvoicesByCustomer(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final map = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in docs) {
      final customerId = doc.data()['customerId']?.toString().trim();
      if (customerId == null || customerId.isEmpty) {
        continue;
      }
      map
          .putIfAbsent(
            customerId,
            () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )
          .add(doc);
    }

    for (final entry in map.entries) {
      entry.value.sort((left, right) {
        final leftDate = _readIssuedAt(left.data());
        final rightDate = _readIssuedAt(right.data());
        return rightDate.compareTo(leftDate);
      });
    }
    return map;
  }

  CustomerRecord _mapCustomerDocumentToRecord(
    String docId,
    Map<String, dynamic> data,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> invoices,
  ) {
    return CustomerRecord(
      id: 0,
      cloudId: docId,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      joinDate: _formatShortDate(_readJoinDate(data)),
      invoices: invoices.map(_mapInvoiceDocumentToRecord).toList(),
    );
  }

  CustomerInvoice _mapInvoiceDocumentToRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final items = data['items'] as List<dynamic>? ?? const <dynamic>[];
    final itemsCount = items.fold<int>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum + ((item['quantity'] as num?)?.toInt() ?? 0);
      }
      if (item is Map) {
        return sum + ((item['quantity'] as num?)?.toInt() ?? 0);
      }
      return sum;
    });

    return CustomerInvoice(
      invoiceNumber: data['invoiceNumber']?.toString() ?? doc.id,
      date: _formatInvoiceDate(_readIssuedAt(data)),
      itemsCount: itemsCount,
      total: _readInvoiceTotal(data),
    );
  }

  double _readInvoiceTotal(Map<String, dynamic> data) {
    final totalAmount = data['totalAmount'];
    final amount = data['amount'];
    if (totalAmount is num) {
      return totalAmount.toDouble();
    }
    if (amount is num) {
      return amount.toDouble();
    }
    return 0;
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

  DateTime _readJoinDate(Map<String, dynamic> data) {
    final joinDate = data['joinDate'];
    if (joinDate is Timestamp) {
      return joinDate.toDate();
    }
    if (joinDate is DateTime) {
      return joinDate;
    }
    if (joinDate is String && joinDate.trim().isNotEmpty) {
      return DateTime.tryParse(joinDate) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return _readSortDate(data);
  }

  DateTime _readIssuedAt(Map<String, dynamic> data) {
    final issuedAt = data['issuedAt'];
    final date = data['date'];
    if (issuedAt is Timestamp) {
      return issuedAt.toDate();
    }
    if (issuedAt is DateTime) {
      return issuedAt;
    }
    if (date is Timestamp) {
      return date.toDate();
    }
    if (date is DateTime) {
      return date;
    }
    if (issuedAt is String && issuedAt.trim().isNotEmpty) {
      return DateTime.tryParse(issuedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (date is String && date.trim().isNotEmpty) {
      return DateTime.tryParse(date) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatInvoiceDate(DateTime date) {
    return date.toIso8601String();
  }
}
