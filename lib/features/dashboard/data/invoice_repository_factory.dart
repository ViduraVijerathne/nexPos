import '../../setup/services/setup_service.dart';
import 'invoice_local_repository.dart';
import 'invoice_remote_repository.dart';
import 'invoice_repository.dart';

class InvoiceRepositoryFactory {
  const InvoiceRepositoryFactory._();

  static Future<InvoiceRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return InvoiceRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const InvoiceLocalRepository();
  }
}
