import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../data/customer_local_repository.dart';
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
  final CustomerLocalRepository _repository = const CustomerLocalRepository();

  List<CustomerRecord> _customers = <CustomerRecord>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isLoading = true;
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
      await _repository.initialize();
      await _loadCustomers();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load customers: $error');
    }
  }

  Future<void> _loadCustomers({int? targetPage}) async {
    setState(() => _isLoading = true);

    try {
      final result = await _repository.fetchCustomers(
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
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load customers: $error');
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
    final result = await showDialog<CustomerRecord>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomerFormDialog(initialCustomer: customer),
    );

    if (result == null) {
      return;
    }

    try {
      await _repository.saveCustomer(result);
      await _loadCustomers(targetPage: customer == null ? 1 : _currentPage);
    } on CustomerLocalRepositoryException catch (error) {
      AppToast.error(error.message);
      return;
    } catch (error) {
      AppToast.error('Failed to save customer: $error');
      return;
    }

    AppToast.success(
      customer == null
          ? 'Customer added successfully'
          : 'Customer updated successfully',
    );
  }

  Future<void> _openCustomerDetails(CustomerRecord customer) async {
    final record = await _repository.fetchCustomerById(customer.id);
    if (!mounted || record == null) {
      AppToast.error('Customer details not found');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomerDetailsDialog(
        customer: record,
        onEdit: () {
          Navigator.of(context).pop();
          _openCustomerDialog(customer: record);
        },
      ),
    );
  }

  String get _footerText {
    if (_totalCount == 0) {
      return 'Showing 0 to 0 of 0 customers';
    }

    final start = ((_currentPage - 1) * CustomerLocalRepository.pageSize) + 1;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _CustomerHeader()),
              const SizedBox(width: 16),
              _PageActionButton(
                label: 'Add Customer',
                icon: Icons.add,
                onPressed: () => _openCustomerDialog(),
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
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  )
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
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage your customer database and interactions.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8391A7),
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
          const Text(
            'Search & Filter Customers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF364255),
            ),
          ),
          const SizedBox(height: 14),
          Row(
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
    required this.onView,
    required this.onEdit,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final List<CustomerRecord> customers;
  final String footerText;
  final int currentPage;
  final int totalPages;
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

                return Container(
                  color: index == 2 ? const Color(0xFFF8FBFF) : null,
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
                              backgroundColor: const Color(0xFF36B4AE),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF36B4AE),
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
                                onPressed: () {
                                  onView(customer);
                                },
                                style: _tableActionStyle(),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 15,
                                  color: Color(0xFF485568),
                                ),
                                label: const Text('View'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
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
    );
  }
}

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({super.key, this.initialCustomer});

  final CustomerRecord? initialCustomer;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

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

  void _submit() {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      AppToast.error('Fill all required customer fields');
      return;
    }

    Navigator.of(context).pop(
      CustomerRecord(
        id: widget.initialCustomer?.id ?? 0,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        joinDate: widget.initialCustomer?.joinDate ?? '',
        invoices: widget.initialCustomer?.invoices ?? const [],
      ),
    );
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
              onClose: () => Navigator.of(context).pop(),
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
              primaryColor: _isEditing
                  ? const Color(0xFF36B4AE)
                  : const Color(0xFF8FDDD6),
              onPrimaryPressed: _submit,
              onSecondaryPressed: () => Navigator.of(context).pop(),
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
              decoration: const BoxDecoration(
                color: Color(0xFF36B4AE),
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
                          style: const TextStyle(
                            color: Color(0xFFE6FFFA),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0x55FFFFFF),
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
                          child: TextField(
                            controller: _invoiceDateController,
                            onChanged: (_) => _refreshInvoiceFilters(),
                            decoration: _fieldDecoration(
                              hintText: 'yyyy-mm-dd',
                            ),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF36B4AE),
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
  final VoidCallback onClose;

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
  });

  final String primaryLabel;
  final Color primaryColor;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

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
            child: Text(primaryLabel),
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
        color: const Color(0xFFDDFBF6),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4AAEA6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
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
    foregroundColor: const Color(0xFF39475B),
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
      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.8),
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
