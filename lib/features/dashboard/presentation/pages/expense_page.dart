import 'package:flutter/material.dart';

import '../../../../core/services/expense_report_print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';
import '../../data/expense_local_repository.dart';
import '../../data/expense_remote_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/expense_repository_factory.dart';
import '../../models/models.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  late final TextEditingController _fromDateController;
  late final TextEditingController _toDateController;

  ExpenseRepository? _repository;
  ExpensePageResult? _pageResult;
  ReportHeaderSettings _reportHeaderSettings = ReportHeaderSettings.defaults;
  ShopInfo _shopInfo = const ShopInfo(
    logoPath: '',
    shopName: '',
    contactEmail: '',
    contactNumber: '',
    address: '',
  );
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isPrinting = false;
  int? _loadingViewIndex;
  int? _loadingEditIndex;
  int? _loadingDeleteIndex;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final fromDate = DateTime(now.year, now.month, 1);
    final toDate = DateTime(now.year, now.month + 1, 0);
    _fromDateController = TextEditingController(text: formatAppDate(fromDate));
    _toDateController = TextEditingController(text: formatAppDate(toDate));
    _loadExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses({int? page}) async {
    setState(() {
      _isLoading = true;
      _currentPage = page ?? _currentPage;
    });

    try {
      final repository = _repository ?? await ExpenseRepositoryFactory.create();
      await repository.initialize();
      final results = await Future.wait([
        repository.fetchExpenses(
          page: _currentPage,
          searchQuery: _searchController.text,
          categoryQuery: _categoryController.text,
          fromDate: parseAppDate(_fromDateController.text),
          toDate: parseAppDate(_toDateController.text),
        ),
        AppSettingsService.instance.loadReportHeaderSettings(),
        SetupService.instance.loadState(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _pageResult = results[0] as ExpensePageResult;
        _reportHeaderSettings = results[1] as ReportHeaderSettings;
        _shopInfo = (results[2] as SetupState).shopInfo;
        _isLoading = false;
        _currentPage = _pageResult?.currentPage ?? 1;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load expenses: ${_readableError(error)}');
    }
  }

  String _readableError(Object error) {
    if (error is ExpenseLocalRepositoryException ||
        error is ExpenseRemoteRepositoryException) {
      return error.toString();
    }
    return '$error';
  }

  Future<void> _pickDate(
    TextEditingController controller, {
    DateTime? initialDate,
  }) async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate:
          parseAppDate(controller.text) ?? initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    controller.text = formatAppDate(selected);
    await _loadExpenses(page: 1);
  }

  Future<void> _showExpenseDialog({ExpenseRecord? initialExpense}) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExpenseDialog(
        repository: repository,
        initialExpense: initialExpense,
      ),
    );
    if (saved == true) {
      await _loadExpenses(page: 1);
    }
  }

  Future<void> _showExpenseDetails(ExpenseRecord expense, int index) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    setState(() => _loadingViewIndex = index);
    try {
      final details = await repository.fetchExpenseDetails(expense);
      if (!mounted) {
        return;
      }
      setState(() => _loadingViewIndex = null);
      if (details == null) {
        AppToast.error('Expense record not found');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => _ExpenseDetailsDialog(expense: details),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingViewIndex = null);
      AppToast.error(
        'Failed to load expense details: ${_readableError(error)}',
      );
    }
  }

  Future<void> _deactivateExpense(ExpenseRecord expense, int index) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    setState(() => _loadingDeleteIndex = index);
    try {
      await repository.deactivateExpense(expense);
      if (!mounted) {
        return;
      }
      AppToast.success('Expense deactivated successfully');
      setState(() => _loadingDeleteIndex = null);
      await _loadExpenses(page: _currentPage);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingDeleteIndex = null);
      AppToast.error('Failed to deactivate expense: ${_readableError(error)}');
    }
  }

  Future<void> _exportReport() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    setState(() => _isExporting = true);
    try {
      final report = await repository.fetchExpenseReport(
        fromDate: parseAppDate(_fromDateController.text) ?? DateTime.now(),
        toDate: parseAppDate(_toDateController.text) ?? DateTime.now(),
      );
      final path = await ExpenseReportPrintService.exportReport(
        shopInfo: _shopInfo,
        headerSettings: _reportHeaderSettings,
        report: report,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isExporting = false);
      if (path != null) {
        AppToast.success('Expense report exported successfully');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isExporting = false);
      AppToast.error(
        'Failed to export expense report: ${_readableError(error)}',
      );
    }
  }

  Future<void> _printReport() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final report = await repository.fetchExpenseReport(
        fromDate: parseAppDate(_fromDateController.text) ?? DateTime.now(),
        toDate: parseAppDate(_toDateController.text) ?? DateTime.now(),
      );
      await ExpenseReportPrintService.printReport(
        shopInfo: _shopInfo,
        headerSettings: _reportHeaderSettings,
        report: report,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isPrinting = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isPrinting = false);
      AppToast.error(
        'Failed to print expense report: ${_readableError(error)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _pageResult;
    if (!_isLoading && result == null) {
      return const Center(child: Text('No expense data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E3A4D),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manage business expenses and print range reports.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A8799),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportReport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(_isExporting ? 'Exporting...' : 'Export'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isPrinting ? null : _printReport,
                icon: _isPrinting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined, size: 18),
                label: Text(_isPrinting ? 'Printing...' : 'Print'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showExpenseDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Expense'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Total Expenses',
                  value: result == null
                      ? null
                      : '${result.summary.totalExpenses}',
                  note: 'All recorded expenses',
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  title: 'Active Expenses',
                  value: result == null
                      ? null
                      : '${result.summary.activeExpenses}',
                  note: 'Currently visible in reports',
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  title: 'Total Amount',
                  value: result == null
                      ? null
                      : 'Rs ${result.summary.totalAmount.toStringAsFixed(2)}',
                  note: 'Overall active expenses',
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  title: 'Range Amount',
                  value: result == null
                      ? null
                      : 'Rs ${result.summary.rangeAmount.toStringAsFixed(2)}',
                  note: 'For selected date range',
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FilterCard(
            searchController: _searchController,
            categoryController: _categoryController,
            fromDateController: _fromDateController,
            toDateController: _toDateController,
            onFromTap: () => _pickDate(_fromDateController),
            onToTap: () => _pickDate(_toDateController),
            onApply: () => _loadExpenses(page: 1),
          ),
          const SizedBox(height: 18),
          _ExpenseTable(
            result: result,
            isLoading: _isLoading,
            loadingViewIndex: _loadingViewIndex,
            loadingEditIndex: _loadingEditIndex,
            loadingDeleteIndex: _loadingDeleteIndex,
            onView: _showExpenseDetails,
            onEdit: (expense, index) async {
              setState(() => _loadingEditIndex = index);
              await _showExpenseDialog(initialExpense: expense);
              if (!mounted) {
                return;
              }
              setState(() => _loadingEditIndex = null);
            },
            onDelete: _deactivateExpense,
            onPageSelected: (page) => _loadExpenses(page: page),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.note,
    required this.isLoading,
  });

  final String title;
  final String? value;
  final String note;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A2B4B),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8694A7),
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const _InlineSkeleton(width: 120, height: 30)
          else
            Text(
              value ?? '-',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E3A4D),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E9BAD),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.searchController,
    required this.categoryController,
    required this.fromDateController,
    required this.toDateController,
    required this.onFromTap,
    required this.onToTap,
    required this.onApply,
  });

  final TextEditingController searchController;
  final TextEditingController categoryController;
  final TextEditingController fromDateController;
  final TextEditingController toDateController;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFBFCFE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF36B4AE), width: 1.4),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search & Filter Expenses',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E3A4D),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: decoration('Search by title, notes, or method'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: categoryController,
                  decoration: decoration('Search by category'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: onFromTap,
                  child: AbsorbPointer(
                    child: AppDateField(
                      controller: fromDateController,
                      hintText: 'From date',
                      decoration: decoration('From date'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: onToTap,
                  child: AbsorbPointer(
                    child: AppDateField(
                      controller: toDateController,
                      hintText: 'To date',
                      decoration: decoration('To date'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Apply'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(112, 50),
                  backgroundColor: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseTable extends StatelessWidget {
  const _ExpenseTable({
    required this.result,
    required this.isLoading,
    required this.loadingViewIndex,
    required this.loadingEditIndex,
    required this.loadingDeleteIndex,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onPageSelected,
  });

  final ExpensePageResult? result;
  final bool isLoading;
  final int? loadingViewIndex;
  final int? loadingEditIndex;
  final int? loadingDeleteIndex;
  final Future<void> Function(ExpenseRecord expense, int index) onView;
  final Future<void> Function(ExpenseRecord expense, int index) onEdit;
  final Future<void> Function(ExpenseRecord expense, int index) onDelete;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final currentPage = result?.currentPage ?? 1;
    final totalPages = result?.totalPages ?? 1;
    final totalCount = result?.totalCount ?? 0;
    final expenseCount = result?.expenses.length ?? 0;
    final expenses = result?.expenses ?? const <ExpenseRecord>[];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense Records',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E3A4D),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.8),
                2: FlexColumnWidth(1.3),
                3: FlexColumnWidth(1.1),
                4: FlexColumnWidth(1.1),
                5: FlexColumnWidth(1.6),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF5F8FC)),
                  children: [
                    _HeaderCell('Date'),
                    _HeaderCell('Title'),
                    _HeaderCell('Category'),
                    _HeaderCell('Method'),
                    _HeaderCell('Amount'),
                    _HeaderCell('Actions'),
                  ],
                ),
                if (isLoading)
                  for (var index = 0; index < 6; index++)
                    _buildSkeletonRow(index)
                else
                  for (var index = 0; index < expenses.length; index++)
                    _buildRow(expenses[index], index),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isLoading)
                const _InlineSkeleton(width: 220, height: 14)
              else
                Text(
                  'Showing ${expenseCount == 0 ? 0 : ((currentPage - 1) * (result?.pageSize ?? 10)) + 1}'
                  ' to ${((currentPage - 1) * (result?.pageSize ?? 10)) + expenseCount} of $totalCount expenses',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8492A6),
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: isLoading || currentPage <= 1
                    ? null
                    : () => onPageSelected(currentPage - 1),
                child: const Text('Previous'),
              ),
              const SizedBox(width: 10),
              if (isLoading)
                const _InlineSkeleton(width: 90, height: 16)
              else
                Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A4556),
                  ),
                ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: isLoading || currentPage >= totalPages
                    ? null
                    : () => onPageSelected(currentPage + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildRow(ExpenseRecord expense, int index) {
    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFCFDFE),
      ),
      children: [
        _BodyCell(formatAppDate(expense.date)),
        _BodyCell(expense.title),
        _BodyCell(expense.category),
        _BodyCell(expense.paymentMethod),
        _BodyCell('Rs ${expense.amount.toStringAsFixed(2)}'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loadingViewIndex == index
                    ? null
                    : () => onView(expense, index),
                icon: loadingViewIndex == index
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined, size: 16),
                label: Text(loadingViewIndex == index ? 'Loading...' : 'View'),
              ),
              OutlinedButton.icon(
                onPressed: loadingEditIndex == index
                    ? null
                    : () => onEdit(expense, index),
                icon: loadingEditIndex == index
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined, size: 16),
                label: Text(loadingEditIndex == index ? 'Loading...' : 'Edit'),
              ),
              OutlinedButton.icon(
                onPressed: loadingDeleteIndex == index
                    ? null
                    : () => onDelete(expense, index),
                icon: loadingDeleteIndex == index
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.block_outlined, size: 16),
                label: Text(
                  loadingDeleteIndex == index ? 'Loading...' : 'Deactivate',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE45858),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _buildSkeletonRow(int index) {
    Widget cell(double width) => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: _InlineSkeleton(width: 110, height: 14),
    );

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFCFDFE),
      ),
      children: [
        cell(80),
        cell(150),
        cell(120),
        cell(100),
        cell(90),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _InlineSkeleton(width: 76, height: 34),
              SizedBox(width: 8),
              _InlineSkeleton(width: 70, height: 34),
              SizedBox(width: 8),
              _InlineSkeleton(width: 102, height: 34),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7C8AA0),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({required this.repository, this.initialExpense});

  final ExpenseRepository repository;
  final ExpenseRecord? initialExpense;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  bool _paidFromDrawer = false;
  List<String> _categorySuggestions = const [];

  bool get _isEdit => widget.initialExpense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.initialExpense;
    _titleController = TextEditingController(text: expense?.title ?? '');
    _categoryController = TextEditingController(text: expense?.category ?? '');
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    _dateController = TextEditingController(
      text: formatAppDate(expense?.date ?? DateTime.now()),
    );
    _paymentMethodController = TextEditingController(
      text: expense?.paymentMethod ?? 'Cash',
    );
    _notesController = TextEditingController(text: expense?.notes ?? '');
    _paidFromDrawer = expense?.paidFromDrawer ?? false;
    _categoryController.addListener(_loadSuggestions);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _paymentMethodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final suggestions = await widget.repository.fetchCategorySuggestions(
      _categoryController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _categorySuggestions = suggestions);
  }

  Future<void> _pickDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: parseAppDate(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    setState(() => _dateController.text = formatAppDate(selected));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedDate = parseAppDate(_dateController.text);
    if (parsedDate == null) {
      AppToast.error('Please select a valid expense date');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.repository.saveExpense(
        ExpenseRecord(
          id: widget.initialExpense?.id,
          cloudId: widget.initialExpense?.cloudId,
          title: _titleController.text.trim(),
          category: _categoryController.text.trim(),
          amount: double.tryParse(_amountController.text.trim()) ?? 0,
          date: parsedDate,
          paymentMethod: _paymentMethodController.text.trim(),
          paidFromDrawer: _paidFromDrawer,
          notes: _notesController.text.trim(),
          status: widget.initialExpense?.status ?? ExpenseStatus.active,
          createdAt: widget.initialExpense?.createdAt ?? DateTime.now(),
          updatedAt: widget.initialExpense == null ? null : DateTime.now(),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      AppToast.success(
        _isEdit
            ? 'Expense updated successfully'
            : 'Expense created successfully',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      AppToast.error('Failed to save expense: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFBFCFE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E7F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF36B4AE), width: 1.4),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 18),
              child: Row(
                children: [
                  Text(
                    _isEdit ? 'Edit Expense' : 'Add New Expense',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3A4D),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: decoration('Expense title'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Expense title is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _categoryController,
                                  decoration: decoration('Category'),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Category is required'
                                      : null,
                                ),
                                if (_categorySuggestions.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FBFE),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE1E7F0),
                                      ),
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _categorySuggestions
                                          .map(
                                            (category) => ActionChip(
                                              label: Text(category),
                                              onPressed: () {
                                                setState(() {
                                                  _categoryController.text =
                                                      category;
                                                  _categoryController
                                                          .selection =
                                                      TextSelection.collapsed(
                                                        offset: category.length,
                                                      );
                                                });
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: decoration('Amount'),
                              validator: (value) {
                                final parsed = double.tryParse(
                                  value?.trim() ?? '',
                                );
                                if (parsed == null || parsed <= 0) {
                                  return 'Enter a valid amount';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickDate,
                              child: AbsorbPointer(
                                child: AppDateField(
                                  controller: _dateController,
                                  hintText: 'Expense date',
                                  decoration: decoration('Expense date'),
                                  validator: (value) =>
                                      parseAppDate(value) == null
                                      ? 'Select a valid date'
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _paymentMethodController,
                              decoration: decoration('Payment method'),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Payment method is required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _paidFromDrawer,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Paid from cashier drawer',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Enable this if the expense amount should reduce the cashier drawer balance at day end.',
                        ),
                        onChanged: (value) {
                          setState(() => _paidFromDrawer = value ?? false);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: decoration('Notes (optional)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _isSaving
                          ? (_isEdit ? 'Updating...' : 'Saving...')
                          : (_isEdit ? 'Update Expense' : 'Add Expense'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DAAA5),
                      foregroundColor: Colors.white,
                    ),
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

class _ExpenseDetailsDialog extends StatelessWidget {
  const _ExpenseDetailsDialog({required this.expense});

  final ExpenseRecord expense;

  @override
  Widget build(BuildContext context) {
    Widget tile(String title, String value) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8592A6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E3A4D),
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Expense Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3A4D),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.9,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  tile('Title', expense.title),
                  tile('Category', expense.category),
                  tile('Amount', 'Rs ${expense.amount.toStringAsFixed(2)}'),
                  tile('Date', formatAppDate(expense.date)),
                  tile('Payment Method', expense.paymentMethod),
                  tile(
                    'Paid from Drawer',
                    expense.paidFromDrawer ? 'Yes' : 'No',
                  ),
                  tile('Status', expense.status.label),
                ],
              ),
              const SizedBox(height: 12),
              tile('Notes', expense.notes.isEmpty ? '-' : expense.notes),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpensePageSkeleton extends StatelessWidget {
  const _ExpensePageSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(62),
          const SizedBox(height: 18),
          Row(
            children: List<Widget>.generate(
              4,
              (index) => Expanded(
                child: Container(
                  height: 118,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          block(132),
          const SizedBox(height: 18),
          block(420),
        ],
      ),
    );
  }
}

class _InlineSkeleton extends StatefulWidget {
  const _InlineSkeleton({
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<_InlineSkeleton> createState() => _InlineSkeletonState();
}

class _InlineSkeletonState extends State<_InlineSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = 0.35 + (_controller.value * 0.4);
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFDDE6F1),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
