import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/widgets/adaptive_data_layout.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../data/customer_local_repository.dart';
import '../../data/customer_remote_repository.dart';
import '../../data/customer_repository.dart';
import '../../data/customer_repository_factory.dart';
import '../../models/models.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _spentLessController = TextEditingController();
  final TextEditingController _spentGreaterController = TextEditingController();

  CustomerRepository? _repository;
  List<CustomerRecord> _customers = <CustomerRecord>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  int _pageSize = 10;
  bool _isLoading = true;
  String? _loadingCustomerCloudId;
  int? _loadingCustomerId;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _spentLessController.dispose();
    _spentGreaterController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    try {
      final repository = await CustomerRepositoryFactory.create();
      await repository.initialize();
      if (!mounted) {
        return;
      }
      _repository = repository;
      await _loadCustomers(repositoryOverride: repository);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load customers: ${_readableError(error)}');
    }
  }

  Future<void> _loadCustomers({
    int? targetPage,
    CustomerRepository? repositoryOverride,
  }) async {
    final repository = repositoryOverride ?? _repository;
    if (repository == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await repository.fetchCustomers(
        page: targetPage ?? _currentPage,
        searchQuery: _searchController.text.trim(),
        spentLessThan: double.tryParse(_spentLessController.text.trim()),
        spentGreaterThan: double.tryParse(_spentGreaterController.text.trim()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = result.customers;
        _currentPage = result.currentPage;
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _pageSize = result.pageSize;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load customers: ${_readableError(error)}');
    }
  }

  void _handleFiltersChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      _loadCustomers(targetPage: 1);
    });
  }

  Future<void> _openCustomerDialog({CustomerRecord? customer}) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Customer service is still loading. Please try again.');
      return;
    }

    final result = await showDialog<CustomerRecord>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          CustomerFormDialog(initialCustomer: customer, repository: repository),
    );

    if (result == null) {
      return;
    }

    await _loadCustomers(targetPage: customer == null ? 1 : _currentPage);

    AppToast.success(
      customer == null
          ? 'Customer added successfully'
          : 'Customer updated successfully',
    );
  }

  Future<void> _openCustomerDetails(CustomerRecord customer) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Customer service is still loading. Please try again.');
      return;
    }

    setState(() {
      _loadingCustomerCloudId = customer.cloudId;
      _loadingCustomerId = customer.id;
    });

    CustomerRecord? record;
    try {
      record = await repository.fetchCustomerDetails(customer);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingCustomerCloudId = null;
          _loadingCustomerId = null;
        });
        AppToast.error(
          'Failed to load customer details: ${_readableError(error)}',
        );
      }
      return;
    }

    if (!mounted || record == null) {
      if (mounted) {
        setState(() {
          _loadingCustomerCloudId = null;
          _loadingCustomerId = null;
        });
      }
      AppToast.error('Customer details not found');
      return;
    }

    setState(() {
      _loadingCustomerCloudId = null;
      _loadingCustomerId = null;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomerDetailsDialog(
        customer: record!,
        onEdit: () {
          Navigator.of(context).pop();
          _openCustomerDialog(customer: record!);
        },
      ),
    );
  }

  String _readableError(Object error) {
    if (error is CustomerLocalRepositoryException) {
      return error.message;
    }
    if (error is CustomerRemoteRepositoryException) {
      return error.message;
    }
    return error.toString();
  }

  String get _footerText {
    if (_totalCount == 0) {
      return 'Showing 0 to 0 of 0 customers';
    }

    final start = ((_currentPage - 1) * _pageSize) + 1;
    final end = (start + _customers.length) - 1;
    return 'Showing $start to $end of $_totalCount customers';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _CustomerHeader()),
              const SizedBox(width: 16),
              _PageActionButton(
                label: 'Add Customer',
                icon: Icons.add,
                onPressed: _repository == null
                    ? null
                    : () => _openCustomerDialog(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CustomerFilterCard(
            searchController: _searchController,
            spentLessController: _spentLessController,
            spentGreaterController: _spentGreaterController,
            onChanged: _handleFiltersChanged,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _isLoading
                ? const _CustomerTableSkeleton()
                : _customers.isEmpty
                ? const _EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No customers found',
                    description:
                        'Try changing the filters or add a new customer.',
                  )
                : _CustomerTableCard(
                    customers: _customers,
                    footerText: _footerText,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    loadingCustomerCloudId: _loadingCustomerCloudId,
                    loadingCustomerId: _loadingCustomerId,
                    onView: _openCustomerDetails,
                    onEdit: (customer) =>
                        _openCustomerDialog(customer: customer),
                    onPreviousPage: _currentPage > 1
                        ? () => _loadCustomers(targetPage: _currentPage - 1)
                        : null,
                    onNextPage: _currentPage < _totalPages
                        ? () => _loadCustomers(targetPage: _currentPage + 1)
                        : null,
                  ),
          ),
        ],
      ),
    ).withAdaptivePageViewport();
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage your customer database and interactions.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CustomerFilterCard extends StatelessWidget {
  const _CustomerFilterCard({
    required this.searchController,
    required this.spentLessController,
    required this.spentGreaterController,
    required this.onChanged,
  });

  final TextEditingController searchController;
  final TextEditingController spentLessController;
  final TextEditingController spentGreaterController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search & Filter Customers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          AdaptiveRow(
            children: [
              Expanded(
                child: _FieldGroup(
                  label: 'Customer Name / Mobile',
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => onChanged(),
                    decoration: _fieldDecoration(
                      hintText: 'Search by name or mobile...',
                      prefixIcon: Icons.search_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FieldGroup(
                  label: 'Total Spend Less Than',
                  child: TextField(
                    controller: spentLessController,
                    onChanged: (_) => onChanged(),
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      hintText: 'e.g. 1000.00',
                      prefixText: '\$  ',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FieldGroup(
                  label: 'Total Spend Greater Than',
                  child: TextField(
                    controller: spentGreaterController,
                    onChanged: (_) => onChanged(),
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      hintText: 'e.g. 500.00',
                      prefixText: '\$  ',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerTableCard extends StatelessWidget {
  const _CustomerTableCard({
    required this.customers,
    required this.footerText,
    required this.currentPage,
    required this.totalPages,
    required this.loadingCustomerCloudId,
    required this.loadingCustomerId,
    required this.onView,
    required this.onEdit,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final List<CustomerRecord> customers;
  final String footerText;
  final int currentPage;
  final int totalPages;
  final String? loadingCustomerCloudId;
  final int? loadingCustomerId;
  final Future<void> Function(CustomerRecord) onView;
  final Future<void> Function(CustomerRecord) onEdit;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 28, child: _HeaderText('Name')),
                Expanded(flex: 22, child: _HeaderText('Contact')),
                Expanded(flex: 8, child: _HeaderText('Orders')),
                Expanded(flex: 12, child: _HeaderText('Total Spent')),
                Expanded(flex: 10, child: _HeaderText('Join Date')),
                Expanded(flex: 14, child: _HeaderText('Actions')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: customers.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (context, index) {
                final customer = customers[index];
                final isLoading =
                    (loadingCustomerCloudId != null &&
                        loadingCustomerCloudId == customer.cloudId) ||
                    (loadingCustomerCloudId == null &&
                        loadingCustomerId == customer.id);

                return Container(
                  color: index == 2 ? AppColors.primaryLight : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 28,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.primaryTeal,
                              child: Text(
                                customer.avatarText,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3A4657),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 22,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ContactItem(
                              icon: Icons.mail_outline_rounded,
                              value: customer.email,
                            ),
                            const SizedBox(height: 4),
                            _ContactItem(
                              icon: Icons.call_outlined,
                              value: customer.phone,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 8,
                        child: Text(
                          '${customer.ordersCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: Text(
                          _currency(customer.totalSpent),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: Text(
                          customer.joinDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 14,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        onView(customer);
                                      },
                                style: _tableActionStyle(),
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF485568),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.visibility_outlined,
                                        size: 15,
                                        color: Color(0xFF485568),
                                      ),
                                label: Text(isLoading ? 'Loading...' : 'View'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        onEdit(customer);
                                      },
                                style: _tableActionStyle(),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: Color(0xFF485568),
                                ),
                                label: const Text('Edit'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE9EEF5))),
            ),
            child: Row(
              children: [
                Text(
                  footerText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B99AD),
                  ),
                ),
                const Spacer(),
                _PaginationButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: onPreviousPage != null,
                  onTap: onPreviousPage,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5EAF2)),
                  ),
                  child: Text(
                    'Page $currentPage of $totalPages',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF566376),
                    ),
                  ),
                ),
                _PaginationButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: onNextPage != null,
                  onTap: onNextPage,
                ),
              ],
            ),
          ),
        ],
      ),
    ).withAdaptiveTable();
  }
}

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({
    super.key,
    this.initialCustomer,
    required this.repository,
  });

  final CustomerRecord? initialCustomer;
  final CustomerRepository repository;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialCustomer != null;

  @override
  void initState() {
    super.initState();
    final customer = widget.initialCustomer;
    _nameController = TextEditingController(text: customer?.name ?? '');
    _emailController = TextEditingController(text: customer?.email ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _addressController = TextEditingController(text: customer?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      AppToast.error('Fill all required customer fields');
      return;
    }

    setState(() => _isSubmitting = true);

    final customer = CustomerRecord(
      id: widget.initialCustomer?.id ?? 0,
      cloudId: widget.initialCustomer?.cloudId,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      joinDate: widget.initialCustomer?.joinDate ?? '',
      invoices: widget.initialCustomer?.invoices ?? const [],
    );

    try {
      final saved = await widget.repository.saveCustomer(customer);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error('Failed to save customer: $error');
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              title: _isEditing ? 'Edit Customer' : 'Add New Customer',
              onClose: _isSubmitting ? null : () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                children: [
                  _FieldGroup(
                    label: 'Customer Name *',
                    child: TextField(
                      controller: _nameController,
                      decoration: _fieldDecoration(
                        hintText: 'Enter customer name',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _FieldGroup(
                          label: 'Email *',
                          child: TextField(
                            controller: _emailController,
                            decoration: _fieldDecoration(
                              hintText: 'email@example.com',
                              prefixIcon: Icons.mail_outline_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FieldGroup(
                          label: 'Phone *',
                          child: TextField(
                            controller: _phoneController,
                            decoration: _fieldDecoration(
                              hintText: '+1 234 567 8900',
                              prefixIcon: Icons.call_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _FieldGroup(
                    label: 'Address *',
                    child: TextField(
                      controller: _addressController,
                      maxLines: 4,
                      decoration: _fieldDecoration(
                        hintText: 'Enter full address',
                        prefixIcon: Icons.location_on_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _DialogFooter(
              primaryLabel: _isEditing ? 'Update Customer' : 'Add Customer',
              primaryColor: AppColors.primaryTeal,
              onPrimaryPressed: _isSubmitting ? null : _submit,
              onSecondaryPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              isPrimaryLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerDetailsDialog extends StatefulWidget {
  const CustomerDetailsDialog({
    super.key,
    required this.customer,
    required this.onEdit,
  });

  final CustomerRecord customer;
  final VoidCallback onEdit;

  @override
  State<CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<CustomerDetailsDialog> {
  static const int _invoicePageSize = 5;

  final TextEditingController _invoiceSearchController =
      TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();

  int _invoicePage = 1;

  List<CustomerInvoice> get _filteredInvoices {
    final query = _invoiceSearchController.text.trim().toLowerCase();
    final dateQuery = _invoiceDateController.text.trim().toLowerCase();

    return widget.customer.invoices.where((invoice) {
      final matchesQuery =
          query.isEmpty || invoice.invoiceNumber.toLowerCase().contains(query);
      final matchesDate =
          dateQuery.isEmpty || invoice.date.toLowerCase().contains(dateQuery);
      return matchesQuery && matchesDate;
    }).toList();
  }

  List<CustomerInvoice> get _visibleInvoices {
    final filtered = _filteredInvoices;
    final start = (_invoicePage - 1) * _invoicePageSize;
    final end = (start + _invoicePageSize).clamp(0, filtered.length);
    if (start >= filtered.length) {
      return <CustomerInvoice>[];
    }
    return filtered.sublist(start, end);
  }

  int get _invoiceTotalPages {
    final count = _filteredInvoices.length;
    if (count == 0) {
      return 1;
    }
    return (count / _invoicePageSize).ceil();
  }

  @override
  void dispose() {
    _invoiceSearchController.dispose();
    _invoiceDateController.dispose();
    super.dispose();
  }

  void _refreshInvoiceFilters() {
    setState(() {
      _invoicePage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _filteredInvoices;
    final visibleInvoices = _visibleInvoices;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 900,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customer.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customer ID: ${widget.customer.id}',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.white.withValues(alpha: 0.33),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.assignment_outlined,
                            label: 'Total Orders',
                            value: '${widget.customer.ordersCount}',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.attach_money_rounded,
                            label: 'Total Spent',
                            value: _currency(widget.customer.totalSpent),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.calendar_today_outlined,
                            label: 'Member Since',
                            value: widget.customer.joinDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B4657),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.person_outline_rounded,
                            label: 'Customer Name',
                            value: widget.customer.name,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email',
                            value: widget.customer.email,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.call_outlined,
                            label: 'Phone',
                            value: widget.customer.phone,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.calendar_today_outlined,
                            label: 'Join Date',
                            value: widget.customer.joinDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoBlock(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: widget.customer.address,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Invoice History (${widget.customer.invoices.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B4657),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _invoiceSearchController,
                            onChanged: (_) => _refreshInvoiceFilters(),
                            decoration: _fieldDecoration(
                              hintText: 'Search by Invoice #...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AppDateField(
                            controller: _invoiceDateController,
                            onChanged: (_) => _refreshInvoiceFilters(),
                            hintText: 'yyyy-mm-dd',
                            decoration: _fieldDecoration(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EDF4)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FBFD),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 22,
                                  child: _HeaderText('Invoice #'),
                                ),
                                Expanded(flex: 46, child: _HeaderText('Date')),
                                Expanded(flex: 12, child: _HeaderText('Items')),
                                Expanded(flex: 20, child: _HeaderText('Total')),
                              ],
                            ),
                          ),
                          if (visibleInvoices.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                'No invoices found',
                                style: TextStyle(
                                  color: Color(0xFF8D9AB0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          for (final invoice in visibleInvoices)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFF0F4F8)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 22,
                                    child: Text(
                                      invoice.invoiceNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF445166),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 46,
                                    child: Text(
                                      invoice.date,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF718096),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 12,
                                    child: Text('${invoice.itemsCount}'),
                                  ),
                                  Expanded(
                                    flex: 20,
                                    child: Text(
                                      _currency(invoice.total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF445166),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFF0F4F8)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  filteredInvoices.isEmpty
                                      ? 'Showing 0 to 0 of 0 invoices'
                                      : 'Showing ${((_invoicePage - 1) * _invoicePageSize) + 1} to ${((_invoicePage - 1) * _invoicePageSize) + visibleInvoices.length} of ${filteredInvoices.length} invoices',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8B99AD),
                                  ),
                                ),
                                const Spacer(),
                                _PaginationButton(
                                  icon: Icons.chevron_left_rounded,
                                  enabled: _invoicePage > 1,
                                  onTap: () {
                                    setState(() {
                                      _invoicePage -= 1;
                                    });
                                  },
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE5EAF2),
                                    ),
                                  ),
                                  child: Text(
                                    'Page $_invoicePage of $_invoiceTotalPages',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF566376),
                                    ),
                                  ),
                                ),
                                _PaginationButton(
                                  icon: Icons.chevron_right_rounded,
                                  enabled: _invoicePage < _invoiceTotalPages,
                                  onTap: () {
                                    setState(() {
                                      _invoicePage += 1;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageActionButton extends StatelessWidget {
  const _PageActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: AppColors.white,
        minimumSize: const Size(124, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF526177) : const Color(0xFFC1CAD6),
        ),
      ),
    );
  }
}

class _CustomerTableSkeleton extends StatelessWidget {
  const _CustomerTableSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 28, child: _HeaderText('Name')),
                Expanded(flex: 22, child: _HeaderText('Contact')),
                Expanded(flex: 8, child: _HeaderText('Orders')),
                Expanded(flex: 12, child: _HeaderText('Total Spent')),
                Expanded(flex: 10, child: _HeaderText('Join Date')),
                Expanded(flex: 14, child: _HeaderText('Actions')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: 8,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Expanded(flex: 28, child: _CustomerSkeletonBlock(0.8)),
                    SizedBox(width: 12),
                    Expanded(flex: 22, child: _CustomerSkeletonBlock(0.85)),
                    SizedBox(width: 12),
                    Expanded(flex: 8, child: _CustomerSkeletonBlock(0.4)),
                    SizedBox(width: 12),
                    Expanded(flex: 12, child: _CustomerSkeletonBlock(0.55)),
                    SizedBox(width: 12),
                    Expanded(flex: 10, child: _CustomerSkeletonBlock(0.6)),
                    SizedBox(width: 12),
                    Expanded(flex: 14, child: _CustomerSkeletonBlock(0.85)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSkeletonBlock extends StatelessWidget {
  const _CustomerSkeletonBlock(this.widthFactor);

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: const Color(0xFFD4DCE7)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF526174),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF8A97AA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8A97AA),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8D9AB0),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B889E),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              size: 29,
              color: Color(0xFF7E8CA2),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
    this.primaryColor = const Color(0xFF36B4AE),
    this.isPrimaryLoading = false,
  });

  final String primaryLabel;
  final Color primaryColor;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final bool isPrimaryLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FBFD),
        border: Border(top: BorderSide(color: Color(0xFFE8EDF4))),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onSecondaryPressed,
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onPrimaryPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: AppColors.white,
            ),
            child: isPrimaryLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(primaryLabel),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF91A0B4)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8C99AD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF364255),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryTeal, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _tableActionStyle() {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(80, 38),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    side: const BorderSide(color: Color(0xFFE3E9F2)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    foregroundColor: AppColors.textPrimary,
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

InputDecoration _fieldDecoration({
  String? hintText,
  IconData? prefixIcon,
  String? prefixText,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixText: prefixText,
    hintStyle: const TextStyle(
      color: Color(0xFFA9B5C7),
      fontWeight: FontWeight.w600,
    ),
    prefixStyle: const TextStyle(
      color: Color(0xFF94A3B8),
      fontWeight: FontWeight.w700,
    ),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 20, color: const Color(0xFF91A0B4)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.primaryTeal, width: 1.8),
    ),
  );
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE7EDF5)),
    boxShadow: const [
      BoxShadow(color: Color(0x120F172A), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

BoxDecoration _dialogDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 38,
        offset: Offset(0, 16),
      ),
    ],
  );
}

String _currency(double value) => '\$${value.toStringAsFixed(2)}';
