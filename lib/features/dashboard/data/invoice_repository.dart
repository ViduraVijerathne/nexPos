import '../models/models.dart';

abstract class InvoiceRepository {
  Future<void> initialize();

  Future<InvoicePageResult> fetchInvoices({
    required int page,
    String? invoiceIdQuery,
    String? customerQuery,
    String? dateFrom,
    String? dateTo,
    double? amountLessThan,
    double? amountGreaterThan,
    String? statusFilter,
  });

  Future<InvoiceRecord?> fetchInvoiceById(String invoiceId);
}
