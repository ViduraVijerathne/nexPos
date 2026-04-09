import '../models/models.dart';

abstract class SupplierRepository {
  Future<void> initialize();

  Future<SupplierPageResult> fetchSuppliers({
    required int page,
    String? searchQuery,
  });

  Future<SupplierRecord?> fetchSupplierDetails(SupplierRecord supplier);

  Future<SupplierRecord> saveSupplier(SupplierRecord supplier);

  Future<SupplierRecord?> toggleSupplierStatus(SupplierRecord supplier);

  Future<SupplierRecord?> recordDuePayment({
    required SupplierRecord supplier,
    required String grnId,
    required double amount,
    required String method,
  });
}
