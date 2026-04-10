import '../../setup/services/setup_service.dart';
import 'pos_local_repository.dart';
import 'pos_remote_repository.dart';
import 'pos_repository.dart';

class PosRepositoryFactory {
  const PosRepositoryFactory._();

  static Future<PosRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return PosRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const PosLocalRepository();
  }
}
