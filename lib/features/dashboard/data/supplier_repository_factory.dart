import '../../setup/services/setup_service.dart';
import 'supplier_local_repository.dart';
import 'supplier_remote_repository.dart';
import 'supplier_repository.dart';

class SupplierRepositoryFactory {
  const SupplierRepositoryFactory._();

  static Future<SupplierRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return SupplierRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const SupplierLocalRepository();
  }
}
