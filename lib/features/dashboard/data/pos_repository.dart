import '../models/models.dart';
import '../../settings/services/app_settings_service.dart';

abstract class PosRepository {
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
    required String cashierName,
    required double taxAmount,
  });
}
