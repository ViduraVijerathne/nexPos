import 'package:isar/isar.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/entities/entities.dart';
import '../models/models.dart';
import 'customer_repository.dart';

class CustomerLocalRepositoryException implements Exception {
  CustomerLocalRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomerLocalRepository implements CustomerRepository {
  const CustomerLocalRepository();

  static const int pageSize = 10;

  Future<void> initialize() async {
    final isar = await AppDatabase.instance;
    await _seedIfNeeded(isar);
  }

  Future<CustomerPageResult> fetchCustomers({
    required int page,
    String? searchQuery,
    double? spentLessThan,
    double? spentGreaterThan,
  }) async {
    final isar = await AppDatabase.instance;
    final customers = await isar.customerEntitys.where().findAll();
    final invoices = await isar.invoiceEntitys.where().findAll();
    final invoicesByCustomer = _groupInvoicesByCustomer(invoices);

    final normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';

    final filteredCustomers =
        customers.where((customer) {
          final customerInvoices =
              invoicesByCustomer[customer.id] ?? const <InvoiceEntity>[];
          final totalSpent = customerInvoices.fold<double>(
            0,
            (sum, invoice) => sum + invoice.totalAmount,
          );

          final matchesQuery =
              normalizedQuery.isEmpty ||
              customer.name.toLowerCase().contains(normalizedQuery) ||
              customer.phone.toLowerCase().contains(normalizedQuery) ||
              customer.email.toLowerCase().contains(normalizedQuery);

          final matchesLess =
              spentLessThan == null || totalSpent < spentLessThan;
          final matchesGreater =
              spentGreaterThan == null || totalSpent > spentGreaterThan;

          return matchesQuery && matchesLess && matchesGreater;
        }).toList()..sort((left, right) {
          final leftDate = left.updatedAt ?? left.createdAt;
          final rightDate = right.updatedAt ?? right.createdAt;
          return rightDate.compareTo(leftDate);
        });

    final totalCount = filteredCustomers.length;
    final safePage = totalCount == 0
        ? 1
        : page.clamp(1, (totalCount / pageSize).ceil()) as int;
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = totalCount == 0
        ? <CustomerEntity>[]
        : filteredCustomers.sublist(start, end);

    return CustomerPageResult(
      customers: pageItems
          .map(
            (customer) => _mapCustomerEntityToRecord(
              customer,
              invoicesByCustomer[customer.id] ?? const <InvoiceEntity>[],
            ),
          )
          .toList(),
      totalCount: totalCount,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  Future<CustomerRecord?> fetchCustomerDetails(CustomerRecord customer) async {
    final isar = await AppDatabase.instance;
    final entity = await isar.customerEntitys.get(customer.id);
    if (entity == null) {
      return null;
    }

    final invoices = await _fetchInvoicesForCustomer(isar, entity);
    return _mapCustomerEntityToRecord(entity, invoices);
  }

  Future<CustomerRecord?> fetchCustomerByPhone(String phone) async {
    final isar = await AppDatabase.instance;
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return null;
    }

    final customer = await isar.customerEntitys
        .filter()
        .phoneEqualTo(trimmedPhone, caseSensitive: false)
        .findFirst();
    if (customer == null) {
      return null;
    }

    final invoices = await _fetchInvoicesForCustomer(isar, customer);
    return _mapCustomerEntityToRecord(customer, invoices);
  }

  Future<CustomerRecord> saveCustomer(CustomerRecord customer) async {
    final isar = await AppDatabase.instance;

    final trimmedEmail = customer.email.trim();
    if (trimmedEmail.isNotEmpty) {
      final existingByEmail = await isar.customerEntitys
          .filter()
          .emailEqualTo(trimmedEmail, caseSensitive: false)
          .findFirst();
      if (existingByEmail != null && existingByEmail.id != customer.id) {
        throw CustomerLocalRepositoryException(
          'A customer with this email already exists',
        );
      }
    }

    final existing = customer.id <= 0
        ? null
        : await isar.customerEntitys.get(customer.id);
    final now = DateTime.now();

    final entity = CustomerEntity()
      ..id = customer.id > 0 ? customer.id : Isar.autoIncrement
      ..name = customer.name.trim()
      ..email = trimmedEmail
      ..phone = customer.phone.trim()
      ..address = customer.address.trim()
      ..joinDate = existing?.joinDate ?? now
      ..createdAt = existing?.createdAt ?? now
      ..updatedAt = existing == null ? null : now;

    late final int savedId;
    await isar.writeTxn(() async {
      savedId = await isar.customerEntitys.put(entity);
    });

    return customer.copyWith(
      id: savedId,
      joinDate: _formatDate(existing?.joinDate ?? now),
    );
  }

  Future<void> _seedIfNeeded(Isar isar) async {
    final hasCustomers = await isar.customerEntitys.count() > 0;
    final hasInvoices = await isar.invoiceEntitys.count() > 0;
    if (hasCustomers || hasInvoices) {
      return;
    }

    final now = DateTime.now();
    final customerSeeds = <CustomerEntity>[
      // _seedCustomer(
      //   name: 'BET23085 S.G.N.N.Bandara',
      //   email: 'bet23085@std.uwu.ac.lk',
      //   phone: 'ff',
      //   address: 'ff',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: 'BET23085 S.G.N.N.Bandara',
      //   email: 'bet23085+1@std.uwu.ac.lk',
      //   phone: '9i98',
      //   address: '9i98',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: '444',
      //   email: '444rr',
      //   phone: '44',
      //   address: '44',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: '44',
      //   email: '44a@example.com',
      //   phone: '44',
      //   address: '44',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: '44',
      //   email: '444@example.com',
      //   phone: '44',
      //   address: '44',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: 'BET23085 S.G.N.N.Bandara',
      //   email: 'bet23085+2@std.uwu.ac.lk',
      //   phone: '444',
      //   address: '444',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: '44',
      //   email: '44b@example.com',
      //   phone: '44',
      //   address: '44',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: 'BET23085 S.G.N.N.Bandara',
      //   email: 'bet23085+3@std.uwu.ac.lk',
      //   phone: '44',
      //   address: '44',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: 'BET23085 S.G.N.N.Bandara',
      //   email: 'bet23085+4@std.uwu.ac.lk',
      //   phone: '444',
      //   address: '444',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: 'BET23085 S.G.N.N.Bandara',
      //   email: 'bet23085+5@std.uwu.ac.lk',
      //   phone: '444',
      //   address: '444',
      //   joinDate: now.subtract(const Duration(days: 2)),
      // ),
      // _seedCustomer(
      //   name: 'Kasun Perera',
      //   email: 'kasun@gmail.com',
      //   phone: '0711234567',
      //   address: 'Kandy',
      //   joinDate: now.subtract(const Duration(days: 1)),
      // ),
      // _seedCustomer(
      //   name: 'Nadee Silva',
      //   email: 'nadee@gmail.com',
      //   phone: '0779876543',
      //   address: 'Colombo',
      //   joinDate: now,
      // ),
    ];

    late final List<int> customerIds;
    await isar.writeTxn(() async {
      customerIds = await isar.customerEntitys.putAll(customerSeeds);
    });

    final invoiceSeeds = <InvoiceEntity>[
      // _seedInvoice(
      //   invoiceNumber: 'INV-000002',
      //   customerId: customerIds[0],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 18)),
      //   totalAmount: 2399.70,
      //   itemsCount: 3,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000001',
      //   customerId: customerIds[0],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 20)),
      //   totalAmount: 2399.70,
      //   itemsCount: 3,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000101',
      //   customerId: customerIds[4],
      //   customerName: '44',
      //   issuedAt: now.subtract(const Duration(hours: 16)),
      //   totalAmount: 4465.00,
      //   itemsCount: 1,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000222',
      //   customerId: customerIds[9],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 12)),
      //   totalAmount: 4799.40,
      //   itemsCount: 2,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000221',
      //   customerId: customerIds[9],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 13)),
      //   totalAmount: 0,
      //   itemsCount: 1,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000010',
      //   customerId: customerIds[10],
      //   customerName: 'Kasun Perera',
      //   issuedAt: now.subtract(const Duration(hours: 11)),
      //   totalAmount: 120.00,
      //   itemsCount: 4,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000005',
      //   customerId: customerIds[10],
      //   customerName: 'Kasun Perera',
      //   issuedAt: now.subtract(const Duration(hours: 10)),
      //   totalAmount: 140.00,
      //   itemsCount: 2,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000009',
      //   customerId: customerIds[11],
      //   customerName: 'Nadee Silva',
      //   issuedAt: now.subtract(const Duration(hours: 9)),
      //   totalAmount: 520.00,
      //   itemsCount: 5,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000301',
      //   customerId: customerIds[0],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 8)),
      //   totalAmount: 899.00,
      //   itemsCount: 2,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000302',
      //   customerId: customerIds[0],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 7)),
      //   totalAmount: 199.50,
      //   itemsCount: 1,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000303',
      //   customerId: customerIds[0],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 6)),
      //   totalAmount: 310.00,
      //   itemsCount: 2,
      // ),
      // _seedInvoice(
      //   invoiceNumber: 'INV-000304',
      //   customerId: customerIds[0],
      //   customerName: 'BET23085 S.G.N.N.Bandara',
      //   issuedAt: now.subtract(const Duration(hours: 5)),
      //   totalAmount: 450.25,
      //   itemsCount: 1,
      // ),
    ];

    await isar.writeTxn(() async {
      await isar.invoiceEntitys.putAll(invoiceSeeds);
    });
  }

  CustomerEntity _seedCustomer({
    required String name,
    required String email,
    required String phone,
    required String address,
    required DateTime joinDate,
  }) {
    return CustomerEntity()
      ..name = name
      ..email = email
      ..phone = phone
      ..address = address
      ..joinDate = joinDate
      ..createdAt = joinDate;
  }

  InvoiceEntity _seedInvoice({
    required String invoiceNumber,
    required int customerId,
    required String customerName,
    required DateTime issuedAt,
    required double totalAmount,
    required int itemsCount,
  }) {
    final item = InvoiceLineItemEmbedded()
      ..name = 'Item'
      ..quantity = itemsCount
      ..unitPrice = itemsCount == 0 ? 0 : totalAmount / itemsCount;

    return InvoiceEntity()
      ..invoiceNumber = invoiceNumber
      ..customerName = customerName
      ..customerCode = 'cust-$customerId'
      ..customerDbId = customerId
      ..issuedAt = issuedAt
      ..totalAmount = totalAmount
      ..status = InvoiceEntityStatus.paid
      ..paymentMethod = 'Cash'
      ..cashierName = 'Admin User'
      ..items = <InvoiceLineItemEmbedded>[item]
      ..createdAt = issuedAt;
  }

  Map<int, List<InvoiceEntity>> _groupInvoicesByCustomer(
    List<InvoiceEntity> invoices,
  ) {
    final map = <int, List<InvoiceEntity>>{};
    for (final invoice in invoices) {
      final customerId = invoice.customerDbId;
      if (customerId == null) {
        continue;
      }

      map.putIfAbsent(customerId, () => <InvoiceEntity>[]).add(invoice);
    }

    for (final entry in map.entries) {
      entry.value.sort(
        (left, right) => right.issuedAt.compareTo(left.issuedAt),
      );
    }

    return map;
  }

  Future<List<InvoiceEntity>> _fetchInvoicesForCustomer(
    Isar isar,
    CustomerEntity customer,
  ) async {
    final allInvoices = await isar.invoiceEntitys.where().findAll();
    final invoices = allInvoices.where((invoice) {
      return invoice.customerDbId == customer.id ||
          invoice.customerName.toLowerCase() == customer.name.toLowerCase();
    }).toList()..sort((left, right) => right.issuedAt.compareTo(left.issuedAt));

    return invoices;
  }

  CustomerRecord _mapCustomerEntityToRecord(
    CustomerEntity entity,
    List<InvoiceEntity> invoices,
  ) {
    return CustomerRecord(
      id: entity.id,
      cloudId: null,
      name: entity.name,
      email: entity.email,
      phone: entity.phone,
      address: entity.address,
      joinDate: _formatDate(entity.joinDate),
      invoices: invoices.map(_mapInvoiceEntityToCustomerInvoice).toList(),
    );
  }

  CustomerInvoice _mapInvoiceEntityToCustomerInvoice(InvoiceEntity entity) {
    return CustomerInvoice(
      invoiceNumber: entity.invoiceNumber,
      date: entity.issuedAt.toIso8601String(),
      itemsCount: entity.items.fold<int>(0, (sum, item) => sum + item.quantity),
      total: entity.totalAmount,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
