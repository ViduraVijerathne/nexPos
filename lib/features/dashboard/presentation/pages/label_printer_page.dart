import 'package:flutter/material.dart';

import '../../../../core/services/label_print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../data/label_printer_repository.dart';
import '../../data/label_printer_repository_factory.dart';
import '../../models/models.dart';

class LabelPrinterPage extends StatefulWidget {
  const LabelPrinterPage({super.key});

  @override
  State<LabelPrinterPage> createState() => _LabelPrinterPageState();
}

class _LabelPrinterPageState extends State<LabelPrinterPage> {
  final TextEditingController _searchController = TextEditingController();

  LabelPrinterRepository? _repository;
  LabelPrinterPageResult? _result;
  LabelPrinterSource _selectedSource = LabelPrinterSource.product;
  bool _isLoading = true;
  bool _isSearching = false;
  int _currentPage = 1;
  int? _printingRowIndex;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems({int? page, bool isSearchAction = false}) async {
    if (_repository == null) {
      setState(() {
        _isLoading = true;
        _currentPage = page ?? _currentPage;
      });
    } else {
      setState(() {
        _isSearching = isSearchAction;
        _currentPage = page ?? _currentPage;
      });
    }

    try {
      final repository =
          _repository ?? await LabelPrinterRepositoryFactory.create();
      await repository.initialize();
      final result = await repository.fetchItems(
        source: _selectedSource,
        page: _currentPage,
        searchQuery: _searchController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _result = result;
        _currentPage = result.currentPage;
        _isLoading = false;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isSearching = false;
      });
      AppToast.error('Failed to load label printer data: $error');
    }
  }

  Future<void> _printItem(LabelPrinterItem item, int rowIndex) async {
    final quantity = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PrintQuantityDialog(item: item),
    );
    if (quantity == null || quantity <= 0) {
      return;
    }

    setState(() => _printingRowIndex = rowIndex);
    try {
      await LabelPrintService.printLabels(item: item, quantity: quantity);
      if (!mounted) {
        return;
      }
      setState(() => _printingRowIndex = null);
      AppToast.success('Labels sent to printer successfully');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _printingRowIndex = null);
      AppToast.error('Failed to print labels: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Label Printer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search products or stocks and print barcode labels quickly.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8291A6),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6EDF5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                _selectedSource == LabelPrinterSource.product
                                ? 'Search by product name, barcode, or category...'
                                : 'Search by product name, stock barcode, product barcode, or GRN...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF8A99AD),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) =>
                              _loadItems(page: 1, isSearchAction: true),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _SourceSelector(
                        selected: _selectedSource,
                        onChanged: (value) {
                          setState(() {
                            _selectedSource = value;
                            _currentPage = 1;
                          });
                          _loadItems(page: 1, isSearchAction: true);
                        },
                      ),
                      const SizedBox(width: 14),
                      FilledButton.icon(
                        onPressed: _isSearching
                            ? null
                            : () => _loadItems(page: 1, isSearchAction: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(124, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isSearching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search_rounded),
                        label: Text(_isSearching ? 'Loading...' : 'Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE7EDF5)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE9EEF4)),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 3,
                                  child: _TableHeader('Name'),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: _TableHeader('Barcode'),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _selectedSource ==
                                            LabelPrinterSource.product
                                        ? 'Details'
                                        : 'Stock Details',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A99AD),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _selectedSource ==
                                            LabelPrinterSource.product
                                        ? 'Qty'
                                        : 'Available Qty',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A99AD),
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: _TableHeader('Actions'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _isLoading
                                ? const _LabelTableSkeleton()
                                : (result == null || result.items.isEmpty)
                                ? const _EmptyState()
                                : ListView.separated(
                                    itemCount: result.items.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      color: Color(0xFFF0F4F8),
                                    ),
                                    itemBuilder: (context, index) {
                                      final item = result.items[index];
                                      final isPrinting =
                                          _printingRowIndex == index;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.title,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.source.label,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF8B98AB),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                item.barcode,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                item.secondaryText,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF748298),
                                                  height: 1.45,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                item.quantity?.toString() ??
                                                    '-',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F766E),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: OutlinedButton.icon(
                                                  onPressed: isPrinting
                                                      ? null
                                                      : () => _printItem(
                                                          item,
                                                          index,
                                                        ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.primaryTeal,
                                                    side: const BorderSide(
                                                      color: Color(0xFFBFEAE2),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  icon: isPrinting
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons.print_outlined,
                                                          size: 18,
                                                        ),
                                                  label: Text(
                                                    isPrinting
                                                        ? 'Printing...'
                                                        : 'Print',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (!_isLoading && result != null) ...[
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                12,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE9EEF4)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Showing ${result.items.isEmpty ? 0 : ((_currentPage - 1) * result.pageSize) + 1} to ${((_currentPage - 1) * result.pageSize) + result.items.length} of ${result.totalCount} items',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7B899D),
                                    ),
                                  ),
                                  const Spacer(),
                                  _PaginationButton(
                                    label: 'Previous',
                                    onTap: result.currentPage > 1
                                        ? () =>
                                              _loadItems(page: _currentPage - 1)
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'Page ${result.currentPage} of ${result.totalPages}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF5B687C),
                                      ),
                                    ),
                                  ),
                                  _PaginationButton(
                                    label: 'Next',
                                    onTap:
                                        result.currentPage < result.totalPages
                                        ? () =>
                                              _loadItems(page: _currentPage + 1)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceSelector extends StatelessWidget {
  const _SourceSelector({required this.selected, required this.onChanged});

  final LabelPrinterSource selected;
  final ValueChanged<LabelPrinterSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LabelPrinterSource>(
      segments: LabelPrinterSource.values
          .map(
            (source) => ButtonSegment<LabelPrinterSource>(
              value: source,
              label: Text(source.label),
            ),
          )
          .toList(),
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return Colors.white;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryTeal;
          }
          return const Color(0xFF64748B);
        }),
        side: WidgetStatePropertyAll(
          const BorderSide(color: Color(0xFFD7E2EC)),
        ),
      ),
    );
  }
}

class _PrintQuantityDialog extends StatefulWidget {
  const _PrintQuantityDialog({required this.item});

  final LabelPrinterItem item;

  @override
  State<_PrintQuantityDialog> createState() => _PrintQuantityDialogState();
}

class _PrintQuantityDialogState extends State<_PrintQuantityDialog> {
  late final TextEditingController _quantityController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      AppToast.error('Please enter a valid print quantity');
      return;
    }
    setState(() => _isSubmitting = true);
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Print Labels',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5EDF4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Barcode Preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A99AD),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BarcodePreview(data: widget.item.barcode, height: 72),
                    const SizedBox(height: 10),
                    SelectableText(
                      widget.item.barcode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Print Quantity',
                  hintText: 'Enter number of labels',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(_isSubmitting ? 'Preparing...' : 'Print'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodePreview extends StatelessWidget {
  const _BarcodePreview({required this.data, this.height = 72});

  final String data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final units = data.codeUnits;
    final bars = <Widget>[];
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      final thickness = (unit % 3) + 1;
      final gap = (unit % 2) + 1;
      final barHeight = height - ((unit % 5) * 4);

      bars.add(
        Container(
          width: thickness.toDouble(),
          height: barHeight.clamp(28, height),
          color: const Color(0xFF111827),
        ),
      );
      bars.add(SizedBox(width: gap.toDouble()));
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 3,
                height: height,
                color: const Color(0xFF111827),
              ),
              const SizedBox(width: 2),
              ...bars,
              Container(
                width: 3,
                height: height,
                color: const Color(0xFF111827),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8A99AD),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF5B687C),
        side: const BorderSide(color: Color(0xFFDCE6EE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_print_shop_outlined,
            size: 40,
            color: Color(0xFFB6C2D1),
          ),
          SizedBox(height: 12),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try another search or switch the source type.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8B98AB),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelTableSkeleton extends StatelessWidget {
  const _LabelTableSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 10,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFF0F4F8)),
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 3, child: _SkeletonBox(width: 180, height: 18)),
            SizedBox(width: 12),
            Expanded(flex: 2, child: _SkeletonBox(width: 120, height: 16)),
            SizedBox(width: 12),
            Expanded(flex: 3, child: _SkeletonBox(width: 220, height: 16)),
            SizedBox(width: 12),
            Expanded(flex: 2, child: _SkeletonBox(width: 60, height: 16)),
            SizedBox(width: 12),
            Expanded(flex: 2, child: _SkeletonBox(width: 88, height: 38)),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
