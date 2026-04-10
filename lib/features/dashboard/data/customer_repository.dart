import '../models/models.dart';

abstract class CustomerRepository {
  Future<void> initialize();

  Future<CustomerPageResult> fetchCustomers({
    required int page,
    String? searchQuery,
    double? spentLessThan,
    double? spentGreaterThan,
  });

  Future<CustomerRecord?> fetchCustomerDetails(CustomerRecord customer);

  Future<CustomerRecord?> fetchCustomerByPhone(String phone);

  Future<CustomerRecord> saveCustomer(CustomerRecord customer);
}
