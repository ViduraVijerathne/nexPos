import '../models/models.dart';

abstract class GrnRepository {
  Future<void> initialize();

  Future<GrnPageResult> fetchGrns({
    required int page,
    String? supplierQuery,
    String? dateFrom,
    String? dateTo,
    double? dueAbove,
  });

  Future<List<String>> fetchProductSuggestions();

  Future<List<String>> fetchSupplierSuggestions();

  Future<GrnRecord?> fetchGrnById(String grnId);

  Future<GrnRecord> saveGrn(GrnRecord record, {required bool addToStock});

  Future<GrnRecord?> recordDuePayment({
    required String grnId,
    required double amount,
    required String method,
  });

  Future<GrnRecord?> addPendingItemsToStock(String grnId);
}
