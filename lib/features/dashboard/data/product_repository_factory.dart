import '../../setup/services/setup_service.dart';
import 'product_local_repository.dart';
import 'product_remote_repository.dart';
import 'product_repository.dart';

class ProductRepositoryFactory {
  const ProductRepositoryFactory._();

  static Future<ProductRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return ProductRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const ProductLocalRepository();
  }
}
