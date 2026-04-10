import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'customer_local_repository.dart';
import 'invoice_repository.dart';

class InvoiceLocalRepositoryException implements Exception {
  InvoiceLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InvoiceLocalRepository implements InvoiceRepository {
  const InvoiceLocalRepository();

  static const int pageSize = 10;

  Future<void> initialize() async {
    await const CustomerLocalRepository().initialize();
  }

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
    final isar = await AppDatabase.instance;
    final entities = await isar.invoiceEntitys.where().anyId().findAll()
      ..sort((left, right) => right.issuedAt.compareTo(left.issuedAt));

    final allRecords = entities.map(_mapEntityToRecord).toList();
    final summary = InvoiceSummary.fromInvoices(allRecords);

    final normalizedInvoiceId = invoiceIdQuery?.trim().toLowerCase() ?? '';
    final normalizedCustomer = customerQuery?.trim().toLowerCase() ?? '';
    final parsedDateFrom = _parseDate(dateFrom);
    final parsedDateTo = _parseDate(dateTo, endOfDay: true);

    final filtered = allRecords.where((invoice) {
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

  Future<InvoiceRecord?> fetchInvoiceById(String invoiceId) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.invoiceEntitys.getByInvoiceNumber(invoiceId);
    if (entity == null) {
      return null;
    }
    return _mapEntityToRecord(entity);
  }

  InvoiceRecord _mapEntityToRecord(InvoiceEntity entity) {
    return InvoiceRecord(
      invoiceId: entity.invoiceNumber,
      customerName: entity.customerName,
      customerCode: entity.customerCode ?? 'walk-in',
      date: entity.issuedAt.toIso8601String(),
      amount: entity.totalAmount,
      subtotal: entity.subtotal,
      tax: entity.tax,
      status: _mapStatus(entity.status),
      items: entity.items
          .map(
            (item) => InvoiceLineItem(
              name: item.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ),
          )
          .toList(),
      paymentMethod: entity.paymentMethod,
      cashierName: entity.cashierName,
    );
  }

  InvoiceStatus _mapStatus(InvoiceEntityStatus status) {
    return switch (status) {
      InvoiceEntityStatus.paid => InvoiceStatus.paid,
      InvoiceEntityStatus.pending => InvoiceStatus.pending,
      InvoiceEntityStatus.overdue => InvoiceStatus.overdue,
    };
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
