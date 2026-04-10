import '../../setup/services/setup_service.dart';
import 'expense_local_repository.dart';
import 'expense_remote_repository.dart';
import 'expense_repository.dart';

class ExpenseRepositoryFactory {
  const ExpenseRepositoryFactory._();

  static Future<ExpenseRepository> create() async {
    final state = await SetupService.instance.loadState();
    if (state.mode == AppMode.online) {
      return ExpenseRemoteRepository(shopId: state.selectedShopId.trim());
    }

    return const ExpenseLocalRepository();
  }
}
