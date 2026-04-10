import '../../setup/services/setup_service.dart';
import 'insight_local_repository.dart';
import 'insight_remote_repository.dart';
import 'insight_repository.dart';

class InsightRepositoryFactory {
  const InsightRepositoryFactory._();

  static Future<InsightRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return InsightRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const InsightLocalRepository();
  }
}
