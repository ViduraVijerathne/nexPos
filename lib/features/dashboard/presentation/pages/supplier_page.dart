import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../data/supplier_local_repository.dart';
import '../../data/supplier_remote_repository.dart';
import '../../data/supplier_repository.dart';
import '../../data/supplier_repository_factory.dart';
import '../../models/models.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final TextEditingController _searchController = TextEditingController();

  SupplierRepository? _repository;
  List<SupplierRecord> _suppliers = <SupplierRecord>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  int _pageSize = 10;
  bool _isLoading = true;
  String? _loadingSupplierCloudId;
  int? _loadingSupplierId;
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
    super.dispose();
  }

  Future<void> _initializePage() async {
    try {
      final repository = await SupplierRepositoryFactory.create();
      await repository.initialize();
      if (!mounted) {
        return;
      }
      _repository = repository;
      await _loadSuppliers(repositoryOverride: repository);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load suppliers: ${_readableError(error)}');
    }
  }

  Future<void> _loadSuppliers({
    int? targetPage,
    SupplierRepository? repositoryOverride,
  }) async {
    final repository = repositoryOverride ?? _repository;
    if (repository == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await repository.fetchSuppliers(
        page: targetPage ?? _currentPage,
        searchQuery: _searchController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _suppliers = result.suppliers;
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
      AppToast.error('Failed to load suppliers: ${_readableError(error)}');
    }
  }

  void _handleSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      _loadSuppliers(targetPage: 1);
    });
  }

  Future<void> _openSupplierDialog({SupplierRecord? supplier}) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Supplier service is still loading. Please try again.');
      return;
    }

    final result = await showDialog<SupplierRecord>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          SupplierFormDialog(initialSupplier: supplier, repository: repository),
    );

    if (result == null) {
      return;
    }

    await _loadSuppliers(targetPage: supplier == null ? 1 : _currentPage);

    AppToast.success(
      supplier == null
          ? 'Supplier added successfully'
          : 'Supplier updated successfully',
    );
  }

  Future<void> _openSupplierDetails(SupplierRecord supplier) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Supplier service is still loading. Please try again.');
      return;
    }

    setState(() {
      _loadingSupplierCloudId = supplier.cloudId;
      _loadingSupplierId = supplier.id;
    });

    SupplierRecord? record;
    try {
      record = await repository.fetchSupplierDetails(supplier);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingSupplierCloudId = null;
          _loadingSupplierId = null;
        });
        AppToast.error(
          'Failed to load supplier details: ${_readableError(error)}',
        );
      }
      return;
    }

    if (!mounted || record == null) {
      if (mounted) {
        setState(() {
          _loadingSupplierCloudId = null;
          _loadingSupplierId = null;
        });
      }
      AppToast.error('Supplier details not found');
      return;
    }

    setState(() {
      _loadingSupplierCloudId = null;
      _loadingSupplierId = null;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SupplierDetailsDialog(
        supplier: record!,
        onToggleStatus: () async {
          try {
            final updated = await repository.toggleSupplierStatus(record!);
            Navigator.of(context).pop();
            await _loadSuppliers(targetPage: _currentPage);

            if (updated == null || !mounted) {
              AppToast.error('Failed to update supplier status');
              return;
            }

            AppToast.success(
              updated.isActive
                  ? 'Supplier activated successfully'
                  : 'Supplier deactivated successfully',
            );

            _openSupplierDetails(updated);
          } catch (error) {
            if (mounted) {
              AppToast.error(
                'Failed to update supplier status: ${_readableError(error)}',
              );
            }
            return;
          }
        },
        onPayDue: (grn) => _openPayDueDialog(record!, grn),
      ),
    );
  }

  void _openPayDueDialog(SupplierRecord supplier, SupplierGrnRecord grn) {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Supplier service is still loading. Please try again.');
      return;
    }

    showDialog<PaySupplierDueResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SupplierPayDueDialog(grn: grn),
    ).then((result) async {
      if (result == null) {
        return;
      }

      try {
        final updated = await repository.recordDuePayment(
          supplier: supplier,
          grnId: grn.grnId,
          amount: result.amount,
          method: result.method,
        );
        await _loadSuppliers(targetPage: _currentPage);

        if (!mounted || updated == null) {
          AppToast.error('Failed to record supplier payment');
          return;
        }

        AppToast.success('Supplier payment recorded successfully');
        _openSupplierDetails(updated);
      } catch (error) {
        AppToast.error(
          'Failed to record supplier payment: ${_readableError(error)}',
        );
      }
    });
  }

  String _readableError(Object error) {
    if (error is SupplierLocalRepositoryException) {
      return error.message;
    }
    if (error is SupplierRemoteRepositoryException) {
      return error.message;
    }
    return error.toString();
  }

  String get _footerText {
    if (_totalCount == 0) {
      return 'Showing 0 to 0 of 0 suppliers';
    }

    final start = ((_currentPage - 1) * _pageSize) + 1;
    final end = (start + _suppliers.length) - 1;
    return 'Showing $start to $end of $_totalCount suppliers';
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
              const Expanded(child: _SupplierHeader()),
              const SizedBox(width: 16),
              _SupplierActionButton(
                label: 'Add Supplier',
                icon: Icons.add,
                onPressed: _repository == null
                    ? null
                    : () => _openSupplierDialog(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SupplierSearchCard(
            controller: _searchController,
            onChanged: _handleSearchChanged,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _isLoading
                ? const _SupplierTableSkeleton()
                : _suppliers.isEmpty
                ? const _SupplierEmptyState()
                : _SupplierTableCard(
                    suppliers: _suppliers,
                    onViewDetails: _openSupplierDetails,
                    onEditSupplier: _openSupplierDialog,
                    loadingSupplierCloudId: _loadingSupplierCloudId,
                    loadingSupplierId: _loadingSupplierId,
                    footerText: _footerText,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    onPreviousPage: _currentPage > 1
                        ? () => _loadSuppliers(targetPage: _currentPage - 1)
                        : null,
                    onNextPage: _currentPage < _totalPages
                        ? () => _loadSuppliers(targetPage: _currentPage + 1)
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupplierHeader extends StatelessWidget {
  const _SupplierHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suppliers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage your supplier relationships and contacts.',
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

class _SupplierSearchCard extends StatelessWidget {
  const _SupplierSearchCard({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText:
              'Search suppliers by name, contact person, email, or company...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9AA8BC),
            size: 21,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5EBF3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5EBF3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryTeal, width: 1.8),
          ),
        ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier, required this.onViewDetails});

  final SupplierRecord supplier;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4FFFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.primaryTeal,
                  size: 20,
                ),
              ),
              const Spacer(),
              _StatusPill(
                label: supplier.isActive ? 'Active' : 'Inactive',
                active: supplier.isActive,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            supplier.supplierName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            supplier.companyName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7F8CA1),
            ),
          ),
          const SizedBox(height: 14),
          _ContactRow(icon: Icons.call_outlined, value: supplier.contactNumber),
          const SizedBox(height: 8),
          _ContactRow(icon: Icons.mail_outline_rounded, value: supplier.email),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE8EDF4)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Total GRNs',
                  value: '${supplier.grns.length}',
                ),
              ),
              Expanded(
                child: _StatColumn(
                  label: 'Paid Amount',
                  value: _formatCurrency(supplier.totalPaid),
                  valueColor: const Color(0xFF36B4AE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatColumn(
            label: 'Due Amount',
            value: _formatCurrency(supplier.totalDue),
            valueColor: const Color(0xFFF35E5E),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewDetails,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                side: const BorderSide(color: Color(0xFFE3E9F2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.visibility_outlined,
                size: 16,
                color: Color(0xFF485568),
              ),
              label: const Text(
                'View Details',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF39475B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierTableCard extends StatelessWidget {
  const _SupplierTableCard({
    required this.suppliers,
    required this.onViewDetails,
    required this.onEditSupplier,
    required this.loadingSupplierCloudId,
    required this.loadingSupplierId,
    required this.footerText,
    required this.currentPage,
    required this.totalPages,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final List<SupplierRecord> suppliers;
  final Future<void> Function(SupplierRecord) onViewDetails;
  final Future<void> Function({SupplierRecord? supplier}) onEditSupplier;
  final String? loadingSupplierCloudId;
  final int? loadingSupplierId;
  final String footerText;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 22, child: _TableHeaderText('Supplier')),
                Expanded(flex: 24, child: _TableHeaderText('Company')),
                Expanded(flex: 14, child: _TableHeaderText('Contact')),
                Expanded(flex: 20, child: _TableHeaderText('Email')),
                Expanded(flex: 8, child: _TableHeaderText('GRNs')),
                Expanded(flex: 12, child: _TableHeaderText('Paid')),
                Expanded(flex: 12, child: _TableHeaderText('Due')),
                Expanded(flex: 10, child: _TableHeaderText('Status')),
                Expanded(flex: 18, child: _TableHeaderText('Actions')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: suppliers.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                final isLoading =
                    (loadingSupplierCloudId != null &&
                        loadingSupplierCloudId == supplier.cloudId) ||
                    (loadingSupplierCloudId == null &&
                        loadingSupplierId == supplier.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 22,
                        child: Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4FFFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.local_shipping_outlined,
                                color: AppColors.primaryTeal,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                supplier.supplierName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF364255),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 24,
                        child: Text(
                          supplier.companyName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7B889E),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 14,
                        child: Text(
                          supplier.contactNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF556276),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 20,
                        child: Text(
                          supplier.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7B889E),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 8,
                        child: Text(
                          '${supplier.grns.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF364255),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: Text(
                          _formatCurrency(supplier.totalPaid),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF36B4AE),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 12,
                        child: Text(
                          _formatCurrency(supplier.totalDue),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: supplier.totalDue > 0
                                ? const Color(0xFFF45D5D)
                                : const Color(0xFF36B4AE),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: _StatusPill(
                          label: supplier.isActive ? 'Active' : 'Inactive',
                          active: supplier.isActive,
                        ),
                      ),
                      Expanded(
                        flex: 18,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        onViewDetails(supplier);
                                      },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(86, 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE3E9F2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
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
                                label: Text(
                                  isLoading ? 'Loading...' : 'View',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF39475B),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        onEditSupplier(supplier: supplier);
                                      },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(84, 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE3E9F2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  foregroundColor: const Color(0xFF39475B),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F4F8))),
            ),
            child: Row(
              children: [
                Text(
                  footerText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8492A6),
                  ),
                ),
                const Spacer(),
                _SupplierPaginationButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: onPreviousPage != null,
                  onTap: onPreviousPage,
                ),
                const SizedBox(width: 8),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4EAF2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Page $currentPage of $totalPages',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF526177),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SupplierPaginationButton(
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

class SupplierFormDialog extends StatefulWidget {
  const SupplierFormDialog({
    super.key,
    this.initialSupplier,
    required this.repository,
    this.prefilledSupplierName,
    this.prefilledContactNumber,
  });

  final SupplierRecord? initialSupplier;
  final SupplierRepository repository;
  final String? prefilledSupplierName;
  final String? prefilledContactNumber;

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  late final TextEditingController _supplierNameController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _companyContactController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  late String _status;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialSupplier != null;

  @override
  void initState() {
    super.initState();
    final supplier = widget.initialSupplier;
    _supplierNameController = TextEditingController(
      text: supplier?.supplierName ?? widget.prefilledSupplierName ?? '',
    );
    _companyNameController = TextEditingController(
      text: supplier?.companyName ?? '',
    );
    _contactNumberController = TextEditingController(
      text: supplier?.contactNumber ?? widget.prefilledContactNumber ?? '',
    );
    _companyContactController = TextEditingController(
      text: supplier?.companyContact ?? '',
    );
    _emailController = TextEditingController(text: supplier?.email ?? '');
    _addressController = TextEditingController(text: supplier?.address ?? '');
    _status = supplier?.isActive == false ? 'Inactive' : 'Active';
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _companyNameController.dispose();
    _contactNumberController.dispose();
    _companyContactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (_supplierNameController.text.trim().isEmpty ||
        _companyNameController.text.trim().isEmpty ||
        _contactNumberController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      AppToast.error('Fill all required supplier fields');
      return;
    }

    setState(() => _isSubmitting = true);
    final supplier = SupplierRecord(
      id: widget.initialSupplier?.id ?? 0,
      cloudId: widget.initialSupplier?.cloudId,
      supplierName: _supplierNameController.text.trim(),
      companyName: _companyNameController.text.trim(),
      contactNumber: _contactNumberController.text.trim(),
      companyContact: _companyContactController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      isActive: _status == 'Active',
      grns: widget.initialSupplier?.grns ?? const [],
    );

    try {
      final saved = await widget.repository.saveSupplier(supplier);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error('Failed to save supplier: $error');
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 740,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              title: _isEditing ? 'Edit Supplier' : 'Add New Supplier',
              onClose: _isSubmitting ? null : () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'Supplier Name *',
                          child: _DialogInputField(
                            controller: _supplierNameController,
                            hintText: 'Enter supplier name',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'Company Name *',
                          child: _DialogInputField(
                            controller: _companyNameController,
                            hintText: 'Enter company name',
                            prefixIcon: Icons.business_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'Contact Number *',
                          child: _DialogInputField(
                            controller: _contactNumberController,
                            hintText: '+1 234 567 8900',
                            prefixIcon: Icons.call_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'Company Contact',
                          child: _DialogInputField(
                            controller: _companyContactController,
                            hintText: '+1 234 567 8900',
                            prefixIcon: Icons.call_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'Email *',
                          child: _DialogInputField(
                            controller: _emailController,
                            hintText: 'email@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'Status',
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: _fieldDecoration(),
                            items: const ['Active', 'Inactive']
                                .map(
                                  (status) => DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _FormFieldGroup(
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
              primaryLabel: _isEditing ? 'Update Supplier' : 'Add Supplier',
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

class SupplierDetailsDialog extends StatefulWidget {
  const SupplierDetailsDialog({
    super.key,
    required this.supplier,
    required this.onToggleStatus,
    required this.onPayDue,
  });

  final SupplierRecord supplier;
  final Future<void> Function() onToggleStatus;
  final ValueChanged<SupplierGrnRecord> onPayDue;

  @override
  State<SupplierDetailsDialog> createState() => _SupplierDetailsDialogState();
}

class _SupplierDetailsDialogState extends State<SupplierDetailsDialog> {
  String _statusFilter = 'All Status';

  List<SupplierGrnRecord> get _filteredGrns {
    if (_statusFilter == 'All Status') {
      return widget.supplier.grns;
    }
    if (_statusFilter == 'Paid') {
      return widget.supplier.grns
          .where((grn) => grn.status == SupplierGrnStatus.paid)
          .toList();
    }
    if (_statusFilter == 'Partial') {
      return widget.supplier.grns
          .where((grn) => grn.status == SupplierGrnStatus.partial)
          .toList();
    }
    return widget.supplier.grns
        .where((grn) => grn.status == SupplierGrnStatus.due)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredGrns = _filteredGrns;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 790,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF36B4AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.supplier.supplierName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.supplier.companyName,
                        style: const TextStyle(
                          color: Color(0xFFE5FFFA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FBFD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EDF4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9FFFB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.toggle_on_outlined,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Supplier Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3D4A5D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.supplier.isActive
                                      ? 'Currently Active'
                                      : 'Currently Inactive',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF8A97AA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              widget.onToggleStatus();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.supplier.isActive
                                  ? const Color(0xFFF45050)
                                  : const Color(0xFF36B4AE),
                              foregroundColor: AppColors.white,
                              minimumSize: const Size(110, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              widget.supplier.isActive
                                  ? 'Deactivate'
                                  : 'Activate',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Supplier Information',
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
                            icon: Icons.business_outlined,
                            label: 'Company Name',
                            value: widget.supplier.companyName,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.person_outline_rounded,
                            label: 'Contact Person',
                            value: widget.supplier.supplierName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email',
                            value: widget.supplier.email,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.call_outlined,
                            label: 'Phone',
                            value: widget.supplier.contactNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoBlock(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: widget.supplier.address,
                    ),
                    const SizedBox(height: 14),
                    _InfoBlock(
                      icon: Icons.call_outlined,
                      label: 'Company Contact',
                      value: widget.supplier.companyContact.isEmpty
                          ? 'N/A'
                          : widget.supplier.companyContact,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Goods Received Notes (${widget.supplier.grns.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B4657),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: _fieldDecoration(),
                            items:
                                const ['All Status', 'Paid', 'Partial', 'Due']
                                    .map(
                                      (status) => DropdownMenuItem<String>(
                                        value: status,
                                        child: Text(status),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _statusFilter = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filteredGrns.isEmpty)
                      Container(
                        height: 118,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8EDF4)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 38,
                              color: Color(0xFFD2DBE8),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No GRN records available for this supplier',
                              style: TextStyle(
                                color: Color(0xFF8F9CB0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8EDF4)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
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
                                    flex: 26,
                                    child: _TableHeaderText('GRN ID'),
                                  ),
                                  Expanded(
                                    flex: 12,
                                    child: _TableHeaderText('Date'),
                                  ),
                                  Expanded(
                                    flex: 10,
                                    child: _TableHeaderText('Items'),
                                  ),
                                  Expanded(
                                    flex: 12,
                                    child: _TableHeaderText('Total'),
                                  ),
                                  Expanded(
                                    flex: 12,
                                    child: _TableHeaderText('Paid'),
                                  ),
                                  Expanded(
                                    flex: 12,
                                    child: _TableHeaderText('Due'),
                                  ),
                                  Expanded(
                                    flex: 12,
                                    child: _TableHeaderText('Status'),
                                  ),
                                  Expanded(
                                    flex: 14,
                                    child: _TableHeaderText('Actions'),
                                  ),
                                ],
                              ),
                            ),
                            for (final grn in filteredGrns)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
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
                                      flex: 26,
                                      child: Text(
                                        grn.grnId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4A5568),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 12,
                                      child: Text(
                                        grn.date,
                                        style: const TextStyle(
                                          color: Color(0xFF7F8DA1),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 10,
                                      child: Text('${grn.itemsCount}'),
                                    ),
                                    Expanded(
                                      flex: 12,
                                      child: Text(_formatCurrency(grn.total)),
                                    ),
                                    Expanded(
                                      flex: 12,
                                      child: Text(
                                        _formatCurrency(grn.paid),
                                        style: const TextStyle(
                                          color: Color(0xFF36B4AE),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 12,
                                      child: Text(
                                        _formatCurrency(grn.due),
                                        style: TextStyle(
                                          color: grn.due > 0
                                              ? const Color(0xFFF45D5D)
                                              : const Color(0xFF36B4AE),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 12,
                                      child: _StatusPill(
                                        label: grn.status.label,
                                        active:
                                            grn.status != SupplierGrnStatus.due,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 14,
                                      child: grn.due <= 0
                                          ? const SizedBox.shrink()
                                          : ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                widget.onPayDue(grn);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF36B4AE,
                                                ),
                                                foregroundColor:
                                                    AppColors.white,
                                                minimumSize: const Size(82, 38),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.attach_money,
                                                size: 16,
                                              ),
                                              label: const Text('Pay'),
                                            ),
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

class SupplierPayDueDialog extends StatefulWidget {
  const SupplierPayDueDialog({super.key, required this.grn});

  final SupplierGrnRecord grn;

  @override
  State<SupplierPayDueDialog> createState() => _SupplierPayDueDialogState();
}

class _SupplierPayDueDialogState extends State<SupplierPayDueDialog> {
  late final TextEditingController _paymentAmountController;
  String _paymentMethod = 'Cash';

  double get _amount =>
      double.tryParse(_paymentAmountController.text.trim()) ?? 0;
  double get _finalBalance =>
      (widget.grn.due - _amount).clamp(0, double.infinity).toDouble();

  @override
  void initState() {
    super.initState();
    _paymentAmountController = TextEditingController();
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    super.dispose();
  }

  void _pay() {
    if (_amount <= 0) {
      AppToast.error('Enter a valid payment amount');
      return;
    }
    if (_amount > widget.grn.due) {
      AppToast.error('Payment amount exceeds due amount');
      return;
    }

    Navigator.of(
      context,
    ).pop(PaySupplierDueResult(amount: _amount, method: _paymentMethod));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF36B4AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay Due Amount',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Supplier payment settlement',
                          style: TextStyle(
                            color: Color(0xFFE6FFFA),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Due Amount',
                          style: TextStyle(
                            color: Color(0xFFEE6C6C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCurrency(widget.grn.due),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'GRN ID',
                          child: _DialogInputField(
                            controller: TextEditingController(
                              text: widget.grn.grnId,
                            ),
                            enabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormFieldGroup(
                          label: 'Due Amount',
                          child: _DialogInputField(
                            controller: TextEditingController(
                              text: widget.grn.due.toStringAsFixed(2),
                            ),
                            enabled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormFieldGroup(
                    label: 'Payment Amount *',
                    child: TextField(
                      controller: _paymentAmountController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormFieldGroup(
                    label: 'Payment Method',
                    child: DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: _fieldDecoration(),
                      items: const ['Cash', 'Card', 'Bank Transfer']
                          .map(
                            (method) => DropdownMenuItem<String>(
                              value: method,
                              child: Text(method),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _paymentMethod = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDFBF6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Final Balance to Pay',
                          style: TextStyle(
                            color: Color(0xFF4AAEA6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCurrency(_finalBalance),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _DialogFooter(
              primaryLabel: 'Pay',
              primaryIcon: Icons.attach_money,
              onPrimaryPressed: _pay,
              onSecondaryPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierActionButton extends StatelessWidget {
  const _SupplierActionButton({
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
        backgroundColor: const Color(0xFF36B4AE),
        foregroundColor: AppColors.white,
        minimumSize: const Size(114, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SupplierTableSkeleton extends StatelessWidget {
  const _SupplierTableSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 22, child: _TableHeaderText('Supplier')),
                Expanded(flex: 24, child: _TableHeaderText('Company')),
                Expanded(flex: 14, child: _TableHeaderText('Contact')),
                Expanded(flex: 20, child: _TableHeaderText('Email')),
                Expanded(flex: 8, child: _TableHeaderText('GRNs')),
                Expanded(flex: 12, child: _TableHeaderText('Paid')),
                Expanded(flex: 12, child: _TableHeaderText('Due')),
                Expanded(flex: 10, child: _TableHeaderText('Status')),
                Expanded(flex: 12, child: _TableHeaderText('Actions')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: 8,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Expanded(flex: 22, child: _SupplierSkeletonBlock(0.75)),
                    SizedBox(width: 12),
                    Expanded(flex: 24, child: _SupplierSkeletonBlock(0.82)),
                    SizedBox(width: 12),
                    Expanded(flex: 14, child: _SupplierSkeletonBlock(0.7)),
                    SizedBox(width: 12),
                    Expanded(flex: 20, child: _SupplierSkeletonBlock(0.9)),
                    SizedBox(width: 12),
                    Expanded(flex: 8, child: _SupplierSkeletonBlock(0.4)),
                    SizedBox(width: 12),
                    Expanded(flex: 12, child: _SupplierSkeletonBlock(0.6)),
                    SizedBox(width: 12),
                    Expanded(flex: 12, child: _SupplierSkeletonBlock(0.6)),
                    SizedBox(width: 12),
                    Expanded(flex: 10, child: _SupplierSkeletonBlock(0.7)),
                    SizedBox(width: 12),
                    Expanded(flex: 12, child: _SupplierSkeletonBlock(0.75)),
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

class _SupplierSkeletonBlock extends StatelessWidget {
  const _SupplierSkeletonBlock(this.widthFactor);

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

class _SupplierPaginationButton extends StatelessWidget {
  const _SupplierPaginationButton({
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4EAF2)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF526177) : const Color(0xFFC1CAD6),
        ),
      ),
    );
  }
}

class _SupplierEmptyState extends StatelessWidget {
  const _SupplierEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 48,
            color: Color(0xFFD4DCE7),
          ),
          SizedBox(height: 12),
          Text(
            'No suppliers found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF526174),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try adjusting the search query or add a new supplier.',
            style: TextStyle(
              color: Color(0xFF8A97AA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8D9CB0)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF738196),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF334155),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A0B3),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7FCF8) : const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? const Color(0xFF45C2B6) : const Color(0xFFF05E5E),
        ),
      ),
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
    this.primaryIcon,
    this.isPrimaryLoading = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final IconData? primaryIcon;
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
          if (primaryIcon != null)
            ElevatedButton.icon(
              onPressed: onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF36B4AE),
                foregroundColor: AppColors.white,
              ),
              icon: isPrimaryLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(primaryIcon, size: 16),
              label: Text(isPrimaryLoading ? 'Please wait...' : primaryLabel),
            )
          else
            ElevatedButton(
              onPressed: onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF36B4AE),
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

class _FormFieldGroup extends StatelessWidget {
  const _FormFieldGroup({required this.label, required this.child});

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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF445166),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DialogInputField extends StatelessWidget {
  const _DialogInputField({
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hintText;
  final IconData? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: _fieldDecoration(hintText: hintText, prefixIcon: prefixIcon),
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

class _TableHeaderText extends StatelessWidget {
  const _TableHeaderText(this.text);

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

InputDecoration _fieldDecoration({String? hintText, IconData? prefixIcon}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFA9B5C7),
      fontWeight: FontWeight.w600,
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
      borderSide: BorderSide(color: AppColors.primaryTeal, width: 1.7),
    ),
  );
}

BoxDecoration _dialogDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(
        color: Color(0x330F172A),
        blurRadius: 28,
        offset: Offset(0, 18),
      ),
    ],
  );
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE8EDF4)),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );
}

String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';
