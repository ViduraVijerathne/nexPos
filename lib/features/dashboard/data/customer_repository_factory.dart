import '../../setup/services/setup_service.dart';
import 'customer_local_repository.dart';
import 'customer_remote_repository.dart';
import 'customer_repository.dart';

class CustomerRepositoryFactory {
  const CustomerRepositoryFactory._();

  static Future<CustomerRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return CustomerRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const CustomerLocalRepository();
  }
}
