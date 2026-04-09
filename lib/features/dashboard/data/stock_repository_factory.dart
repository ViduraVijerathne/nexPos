import '../../setup/services/setup_service.dart';
import 'stock_local_repository.dart';
import 'stock_remote_repository.dart';
import 'stock_repository.dart';

class StockRepositoryFactory {
  const StockRepositoryFactory._();

  static Future<StockRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return StockRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const StockLocalRepository();
  }
}
