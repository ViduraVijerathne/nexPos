import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../../../core/widgets/invoice_preview.dart';
import '../../../../core/services/invoice_print_service.dart';
import '../../data/invoice_local_repository.dart';
import '../../data/invoice_remote_repository.dart';
import '../../data/invoice_repository.dart';
import '../../data/invoice_repository_factory.dart';
import '../../models/models.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final TextEditingController _amountLessController = TextEditingController();
  final TextEditingController _amountGreaterController =
      TextEditingController();

  InvoiceRepository? _repository;
  String _statusFilter = 'All Status';
  List<InvoiceRecord> _invoices = <InvoiceRecord>[];
  InvoiceSummary _summary = const InvoiceSummary(
    totalInvoices: 0,
    paidInvoices: 0,
    pendingInvoices: 0,
    overdueInvoices: 0,
  );
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isFilterExpanded = false;
  String? _viewingInvoiceId;
  String? _printingInvoiceId;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _invoiceIdController.dispose();
    _customerController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _amountLessController.dispose();
    _amountGreaterController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    try {
      final repository = await InvoiceRepositoryFactory.create();
      await repository.initialize();
      if (!mounted) {
        return;
      }
      _repository = repository;
      await _loadInvoices(repositoryOverride: repository);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load invoices: ${_readableError(error)}');
    }
  }

  Future<void> _loadInvoices({
    int? targetPage,
    InvoiceRepository? repositoryOverride,
  }) async {
    final repository = repositoryOverride ?? _repository;
    if (repository == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await repository.fetchInvoices(
        page: targetPage ?? _currentPage,
        invoiceIdQuery: _invoiceIdController.text.trim(),
        customerQuery: _customerController.text.trim(),
        dateFrom: _dateFromController.text.trim(),
        dateTo: _dateToController.text.trim(),
        amountLessThan: double.tryParse(_amountLessController.text.trim()),
        amountGreaterThan: double.tryParse(
          _amountGreaterController.text.trim(),
        ),
        statusFilter: _statusFilter,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invoices = result.invoices;
        _summary = result.summary;
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
      AppToast.error('Failed to load invoices: ${_readableError(error)}');
    }
  }

  void _refreshFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      _loadInvoices(targetPage: 1);
    });
  }

  Future<void> _showInvoiceDetails(InvoiceRecord invoice) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Invoice service is still loading. Please try again.');
      return;
    }

    setState(() => _viewingInvoiceId = invoice.invoiceId);
    try {
      final record = await repository.fetchInvoiceById(invoice.invoiceId);
      if (!mounted || record == null) {
        if (mounted) {
          setState(() => _viewingInvoiceId = null);
        }
        AppToast.error('Invoice details not found');
        return;
      }

      setState(() => _viewingInvoiceId = null);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InvoiceDetailsDialog(
          invoice: record,
          onPrint: () {
            Navigator.of(context).pop();
            _printInvoice(record);
          },
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _viewingInvoiceId = null);
      AppToast.error(
        'Failed to load invoice details: ${_readableError(error)}',
      );
    }
  }

  Future<void> _printInvoice(InvoiceRecord invoice) async {
    setState(() => _printingInvoiceId = invoice.invoiceId);
    try {
      final setupState = await SetupService.instance.loadState();
      final layoutSettings = await AppSettingsService.instance
          .loadInvoiceLayoutSettings();
      if (!mounted) {
        return;
      }

      final preview = InvoicePreviewData(
        invoiceNumber: invoice.invoiceId,
        customerName: invoice.customerName,
        customerMobile: invoice.customerCode == 'walk-in'
            ? ''
            : invoice.customerCode,
        dateTimeText: invoice.date,
        items: invoice.items
            .map(
              (item) => InvoicePreviewLine(
                name: item.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ),
            )
            .toList(),
        subtotal: invoice.subtotal,
        tax: invoice.tax,
        total: invoice.amount,
        paymentMethod: invoice.paymentMethod,
        paidAmount: invoice.amount,
        balance: 0,
      );

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InvoicePrintPreviewDialog(
          shopInfo: setupState.shopInfo,
          settings: layoutSettings,
          preview: preview,
          onPrint: () async {
            await InvoicePrintService.printInvoice(
              shopInfo: setupState.shopInfo,
              settings: layoutSettings,
              preview: preview,
            );
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop();
            AppToast.success('Invoice sent to printer');
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        AppToast.error('Failed to prepare invoice print: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _printingInvoiceId = null);
      }
    }
  }

  String _readableError(Object error) {
    if (error is InvoiceLocalRepositoryException) {
      return error.message;
    }
    if (error is InvoiceRemoteRepositoryException) {
      return error.message;
    }
    return '$error';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InvoiceHeader(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Invoices',
                  value: '${_summary.totalInvoices}',
                  valueColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'Paid',
                  value: '${_summary.paidInvoices}',
                  valueColor: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'Pending',
                  value: '${_summary.pendingInvoices}',
                  valueColor: const Color(0xFFDE9B1F),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  label: 'Overdue',
                  value: '${_summary.overdueInvoices}',
                  valueColor: const Color(0xFFE23A56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InvoiceFilterCard(
            isExpanded: _isFilterExpanded,
            invoiceIdController: _invoiceIdController,
            customerController: _customerController,
            dateFromController: _dateFromController,
            dateToController: _dateToController,
            amountLessController: _amountLessController,
            amountGreaterController: _amountGreaterController,
            selectedStatus: _statusFilter,
            onChanged: _refreshFilters,
            onToggleExpanded: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
            onStatusChanged: (value) {
              setState(() {
                _statusFilter = value;
              });
              _loadInvoices(targetPage: 1);
            },
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _isLoading
                ? const _InvoiceTableSkeleton()
                : _invoices.isEmpty
                ? const _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices found',
                    description:
                        'Try changing the filters to see matching invoices.',
                  )
                : _InvoiceTableCard(
                    invoices: _invoices,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    totalItems: _totalCount,
                    viewingInvoiceId: _viewingInvoiceId,
                    printingInvoiceId: _printingInvoiceId,
                    onPrevious: _currentPage <= 1
                        ? null
                        : () => _loadInvoices(targetPage: _currentPage - 1),
                    onNext: _currentPage >= _totalPages
                        ? null
                        : () => _loadInvoices(targetPage: _currentPage + 1),
                    onView: (invoice) {
                      _showInvoiceDetails(invoice);
                    },
                    onPrint: _printInvoice,
                  ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invoices',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage and track your sales invoices.',
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A97AA),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceFilterCard extends StatelessWidget {
  const _InvoiceFilterCard({
    required this.isExpanded,
    required this.invoiceIdController,
    required this.customerController,
    required this.dateFromController,
    required this.dateToController,
    required this.amountLessController,
    required this.amountGreaterController,
    required this.selectedStatus,
    required this.onChanged,
    required this.onToggleExpanded,
    required this.onStatusChanged,
  });

  final bool isExpanded;
  final TextEditingController invoiceIdController;
  final TextEditingController customerController;
  final TextEditingController dateFromController;
  final TextEditingController dateToController;
  final TextEditingController amountLessController;
  final TextEditingController amountGreaterController;
  final String selectedStatus;
  final VoidCallback onChanged;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    'Search & Filter Invoices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _FieldGroup(
                        label: 'Invoice ID',
                        child: TextField(
                          controller: invoiceIdController,
                          onChanged: (_) => onChanged(),
                          decoration: _fieldDecoration(
                            hintText: 'Search by ID...',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FieldGroup(
                        label: 'Customer',
                        child: TextField(
                          controller: customerController,
                          onChanged: (_) => onChanged(),
                          decoration: _fieldDecoration(
                            hintText: 'Search by customer...',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FieldGroup(
                        label: 'Date From',
                        child: AppDateField(
                          controller: dateFromController,
                          onChanged: (_) => onChanged(),
                          hintText: 'yyyy-mm-dd',
                          decoration: _fieldDecoration(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FieldGroup(
                        label: 'Date To',
                        child: AppDateField(
                          controller: dateToController,
                          onChanged: (_) => onChanged(),
                          hintText: 'yyyy-mm-dd',
                          decoration: _fieldDecoration(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FieldGroup(
                        label: 'Amount Less Than',
                        child: TextField(
                          controller: amountLessController,
                          onChanged: (_) => onChanged(),
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(hintText: 'e.g. 100.00'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FieldGroup(
                        label: 'Amount Greater Than',
                        child: TextField(
                          controller: amountGreaterController,
                          onChanged: (_) => onChanged(),
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(hintText: 'e.g. 50.00'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FieldGroup(
                        label: 'Status',
                        child: DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: _fieldDecoration(),
                          items:
                              const ['All Status', 'Paid', 'Pending', 'Overdue']
                                  .map(
                                    (status) => DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              onStatusChanged(value);
                            }
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTableCard extends StatelessWidget {
  const _InvoiceTableCard({
    required this.invoices,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.viewingInvoiceId,
    required this.printingInvoiceId,
    required this.onPrevious,
    required this.onNext,
    required this.onView,
    required this.onPrint,
  });

  final List<InvoiceRecord> invoices;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final String? viewingInvoiceId;
  final String? printingInvoiceId;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<InvoiceRecord> onView;
  final ValueChanged<InvoiceRecord> onPrint;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : ((currentPage - 1) * 10) + 1;
    final end = totalItems == 0 ? 0 : start + invoices.length - 1;

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
                Expanded(flex: 18, child: _HeaderText('Invoice ID')),
                Expanded(flex: 28, child: _HeaderText('Customer')),
                Expanded(flex: 28, child: _HeaderText('Date')),
                Expanded(flex: 14, child: _HeaderText('Amount')),
                Expanded(flex: 10, child: _HeaderText('Status')),
                Expanded(flex: 10, child: _HeaderText('Actions')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 18,
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: AppColors.primaryTeal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                invoice.invoiceId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF435064),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 28,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF435064),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              invoice.customerCode,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9AA8BC),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 28,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Color(0xFF91A0B4),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                invoice.date,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6D7A90),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 14,
                        child: Text(
                          'Rs ${invoice.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF435064),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: _StatusBadge(status: invoice.status),
                      ),
                      Expanded(
                        flex: 10,
                        child: Row(
                          children: [
                            if (viewingInvoiceId == invoice.invoiceId)
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                onPressed: () => onView(invoice),
                                icon: Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                            if (printingInvoiceId == invoice.invoiceId)
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                onPressed: () => onPrint(invoice),
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 18,
                                  color: Color(0xFF64748B),
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
                  'Showing $start to $end of $totalItems invoices',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B99AD),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onPrevious,
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5EAF2)),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
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
                IconButton(
                  onPressed: onNext,
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5EAF2)),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTableSkeleton extends StatelessWidget {
  const _InvoiceTableSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: List<Widget>.generate(
          8,
          (_) => Container(
            height: 54,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class InvoiceDetailsDialog extends StatelessWidget {
  const InvoiceDetailsDialog({
    super.key,
    required this.invoice,
    required this.onPrint,
  });

  final InvoiceRecord invoice;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 860,
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
                          invoice.invoiceId,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sales invoice details',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onPrint,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.white.withValues(alpha: 0.33),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print Invoice'),
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
                            icon: Icons.person_outline_rounded,
                            label: 'Customer',
                            value: invoice.customerName,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.payments_outlined,
                            label: 'Amount',
                            value: 'Rs ${invoice.amount.toStringAsFixed(2)}',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.calendar_today_outlined,
                            label: 'Date',
                            value: invoice.date.substring(0, 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Invoice Information',
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
                            icon: Icons.receipt_long_outlined,
                            label: 'Invoice ID',
                            value: invoice.invoiceId,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.badge_outlined,
                            label: 'Status',
                            value: invoice.status.label,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.credit_card_outlined,
                            label: 'Payment Method',
                            value: invoice.paymentMethod,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _InfoBlock(
                            icon: Icons.person_outline_rounded,
                            label: 'Cashier',
                            value: invoice.cashierName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Invoice Items',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B4657),
                      ),
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
                                Expanded(flex: 46, child: _HeaderText('Item')),
                                Expanded(flex: 16, child: _HeaderText('Qty')),
                                Expanded(
                                  flex: 20,
                                  child: _HeaderText('Unit Price'),
                                ),
                                Expanded(
                                  flex: 18,
                                  child: _HeaderText('Subtotal'),
                                ),
                              ],
                            ),
                          ),
                          for (final item in invoice.items)
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
                                    flex: 46,
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF445166),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 16,
                                    child: Text('${item.quantity}'),
                                  ),
                                  Expanded(
                                    flex: 20,
                                    child: Text(
                                      'Rs ${item.unitPrice.toStringAsFixed(2)}',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 18,
                                    child: Text(
                                      'Rs ${item.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF445166),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFD),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _AmountRow(
                              label: 'Subtotal',
                              value:
                                  'Rs ${invoice.subtotal.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 8),
                            _AmountRow(
                              label: 'Tax',
                              value: 'Rs ${invoice.tax.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 12),
                            _AmountRow(
                              label: 'Total',
                              value: 'Rs ${invoice.amount.toStringAsFixed(2)}',
                              emphasize: true,
                            ),
                          ],
                        ),
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

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF6B7A90),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 16 : 14,
            fontWeight: FontWeight.w800,
            color: emphasize ? AppColors.primaryTeal : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      InvoiceStatus.paid => AppColors.primaryTeal,
      InvoiceStatus.pending => const Color(0xFFE3A72C),
      InvoiceStatus.overdue => const Color(0xFFE24B5E),
    };
    final background = switch (status) {
      InvoiceStatus.paid => AppColors.primaryLight,
      InvoiceStatus.pending => const Color(0xFFFFF3DA),
      InvoiceStatus.overdue => const Color(0xFFFFE8EC),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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

InputDecoration _fieldDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFA9B5C7),
      fontWeight: FontWeight.w600,
    ),
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
