import 'package:cloud_firestore/cloud_firestore.dart';

import '../../subscription/services/subscription_usage_service.dart';
import '../models/models.dart';
import 'invoice_repository.dart';

class InvoiceRemoteRepositoryException implements Exception {
  InvoiceRemoteRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InvoiceRemoteRepository implements InvoiceRepository {
  InvoiceRemoteRepository({required this.shopId});

  static const int pageSize = 10;

  final String shopId;

  CollectionReference<Map<String, dynamic>> get _invoicesRef =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('invoices');

  @override
  Future<void> initialize() async {
    if (shopId.isEmpty) {
      throw InvoiceRemoteRepositoryException(
        'Online shop is not selected. Please complete the setup again.',
      );
    }
  }

  @override
  Future<InvoicePageResult> fetchInvoices({
    required int page,
    String? invoiceIdQuery,
    String? customerQuery,
    String? dateFrom,
    String? dateTo,
    double? amountLessThan,
    double? amountGreaterThan,
    String? statusFilter,
  }) async {
    final snapshot = await _invoicesRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'invoices',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    final records = snapshot.docs.map(_mapInvoiceDocumentToRecord).toList()
      ..sort((left, right) => right.date.compareTo(left.date));

    final summary = InvoiceSummary.fromInvoices(records);
    final normalizedInvoiceId = invoiceIdQuery?.trim().toLowerCase() ?? '';
    final normalizedCustomer = customerQuery?.trim().toLowerCase() ?? '';
    final parsedDateFrom = _parseDate(dateFrom);
    final parsedDateTo = _parseDate(dateTo, endOfDay: true);

    final filtered = records.where((invoice) {
      if (normalizedInvoiceId.isNotEmpty &&
          !invoice.invoiceId.toLowerCase().contains(normalizedInvoiceId)) {
        return false;
      }

      if (normalizedCustomer.isNotEmpty &&
          !invoice.customerName.toLowerCase().contains(normalizedCustomer) &&
          !invoice.customerCode.toLowerCase().contains(normalizedCustomer)) {
        return false;
      }

      final invoiceDate = DateTime.tryParse(invoice.date);
      if (parsedDateFrom != null &&
          (invoiceDate == null || invoiceDate.isBefore(parsedDateFrom))) {
        return false;
      }

      if (parsedDateTo != null &&
          (invoiceDate == null || invoiceDate.isAfter(parsedDateTo))) {
        return false;
      }

      if (amountLessThan != null && invoice.amount >= amountLessThan) {
        return false;
      }

      if (amountGreaterThan != null && invoice.amount <= amountGreaterThan) {
        return false;
      }

      if (statusFilter != null &&
          statusFilter != 'All Status' &&
          invoice.status.label != statusFilter) {
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
        ? <InvoiceRecord>[]
        : filtered.sublist(start, end);

    return InvoicePageResult(
      invoices: pageItems,
      summary: summary,
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  @override
  Future<InvoiceRecord?> fetchInvoiceById(String invoiceId) async {
    final doc = await _invoicesRef.doc(invoiceId).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'invoices',
      documentCount: doc.exists ? 1 : 0,
      payload: doc.data(),
    );
    if (doc.exists) {
      return _mapInvoiceDocumentSnapshotToRecord(doc);
    }

    final snapshot = await _invoicesRef
        .where('invoiceNumber', isEqualTo: invoiceId)
        .limit(1)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'invoices',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return _mapInvoiceDocumentToRecord(snapshot.docs.first);
  }

  InvoiceRecord _mapInvoiceDocumentToRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _mapInvoiceDataToRecord(doc.id, doc.data());
  }

  InvoiceRecord _mapInvoiceDocumentSnapshotToRecord(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _mapInvoiceDataToRecord(doc.id, doc.data() ?? <String, dynamic>{});
  }

  InvoiceRecord _mapInvoiceDataToRecord(
    String docId,
    Map<String, dynamic> data,
  ) {
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .map(_mapLineItem)
        .toList();
    final subtotal =
        (data['subTotal'] as num?)?.toDouble() ??
        items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final discount =
        (data['discountAmount'] as num?)?.toDouble() ??
        (data['discount'] as num?)?.toDouble() ??
        0;
    final amount =
        (data['totalAmount'] as num?)?.toDouble() ??
        (data['amount'] as num?)?.toDouble() ??
        (subtotal - discount).clamp(0, double.infinity).toDouble();
    final tax =
        (data['taxAmount'] as num?)?.toDouble() ??
        (amount - (subtotal - discount)).clamp(0, double.infinity);

    return InvoiceRecord(
      invoiceId: data['invoiceNumber']?.toString() ?? docId,
      customerName: data['customerName']?.toString() ?? 'Walk-in Customer',
      customerCode: data['customerCode']?.toString() ?? 'walk-in',
      date: _readIssuedAt(data).toIso8601String(),
      amount: amount,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      status: _mapStatus(data['status']?.toString()),
      items: items,
      paymentMethod: data['paymentMethod']?.toString() ?? 'Cash',
      cashierName: data['cashierName']?.toString() ?? 'Cashier',
    );
  }

  InvoiceLineItem _mapLineItem(dynamic rawItem) {
    if (rawItem is Map<String, dynamic>) {
      return InvoiceLineItem(
        name: rawItem['name']?.toString() ?? '',
        quantity: (rawItem['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (rawItem['unitPrice'] as num?)?.toDouble() ?? 0,
      );
    }

    if (rawItem is Map) {
      return InvoiceLineItem(
        name: rawItem['name']?.toString() ?? '',
        quantity: (rawItem['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (rawItem['unitPrice'] as num?)?.toDouble() ?? 0,
      );
    }

    return const InvoiceLineItem(name: '', quantity: 0, unitPrice: 0);
  }

  InvoiceStatus _mapStatus(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'paid':
        return InvoiceStatus.paid;
      case 'overdue':
        return InvoiceStatus.overdue;
      case 'pending':
      default:
        return InvoiceStatus.pending;
    }
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

  DateTime? _parseDate(String? value, {bool endOfDay = false}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      final date = DateTime.parse(value.trim());
      if (!endOfDay) {
        return DateTime(date.year, date.month, date.day);
      }
      return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    } catch (_) {
      return null;
    }
  }
}
