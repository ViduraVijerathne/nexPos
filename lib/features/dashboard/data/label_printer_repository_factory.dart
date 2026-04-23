import '../../setup/services/setup_service.dart';
import 'label_printer_local_repository.dart';
import 'label_printer_remote_repository.dart';
import 'label_printer_repository.dart';

class LabelPrinterRepositoryFactory {
  const LabelPrinterRepositoryFactory._();

  static Future<LabelPrinterRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return LabelPrinterRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const LabelPrinterLocalRepository();
  }
}
