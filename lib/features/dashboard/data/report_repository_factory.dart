import '../../setup/services/setup_service.dart';
import 'report_local_repository.dart';
import 'report_remote_repository.dart';
import 'report_repository.dart';

class ReportRepositoryFactory {
  const ReportRepositoryFactory._();

  static Future<ReportRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return ReportRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const ReportLocalRepository();
  }
}
