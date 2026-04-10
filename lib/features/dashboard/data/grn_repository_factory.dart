import '../../setup/services/setup_service.dart';
import 'grn_local_repository.dart';
import 'grn_remote_repository.dart';
import 'grn_repository.dart';

class GrnRepositoryFactory {
  const GrnRepositoryFactory._();

  static Future<GrnRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return GrnRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const GrnLocalRepository();
  }
}
