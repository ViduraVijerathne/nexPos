import '../models/models.dart';
import '../../settings/services/app_settings_service.dart';

abstract class PosRepository {
  void invalidateCatalog() {}
  Future<void> initialize();

  Future<PosCatalogResult> fetchCatalog({
    String? searchQuery,
    String? category,
    PosCatalogLoadMode loadMode = PosCatalogLoadMode.defaultOrder,
  });

  Future<PosCatalogItem?> findExactCatalogMatch(String value);

  Future<List<PosCustomerOption>> searchCustomers(String query);

  Future<PosCheckoutResult> processSale({
    required List<PosCartItem> items,
    required PosCustomerOption customer,
    required String paymentMethod,
    required double amountPaid,
    required double cashPaidAmount,
    required double cardPaidAmount,
    required String cashierName,
    required double discountAmount,
    required double taxAmount,
  });
}
