import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_date_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../data/grn_local_repository.dart';
import '../../data/grn_remote_repository.dart';
import '../../data/grn_repository.dart';
import '../../data/grn_repository_factory.dart';
import '../../models/models.dart';

class GrnPage extends StatefulWidget {
  const GrnPage({super.key});

  @override
  State<GrnPage> createState() => _GrnPageState();
}

class _GrnPageState extends State<GrnPage> {
  final TextEditingController _supplierSearchController =
      TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final TextEditingController _dueAboveController = TextEditingController();
  GrnRepository? _repository;
  List<String> _productSuggestions = <String>[];
  List<String> _supplierSuggestions = <String>[];
  List<GrnRecord> _grns = <GrnRecord>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  int _pageSize = 10;
  bool _isLoading = true;
  String? _loadingGrnId;
  Timer? _filterDebounce;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _supplierSearchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _dueAboveController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    try {
      final repository = await GrnRepositoryFactory.create();
      await repository.initialize();
      if (!mounted) {
        return;
      }
      _repository = repository;
      await _reloadSuggestions();
      await _loadGrns(repositoryOverride: repository);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load GRNs: ${_readableError(error)}');
    }
  }

  Future<void> _reloadSuggestions() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    final products = await repository.fetchProductSuggestions();
    final suppliers = await repository.fetchSupplierSuggestions();

    if (!mounted) {
      return;
    }

    setState(() {
      _productSuggestions = products;
      _supplierSuggestions = suppliers;
    });
  }

  Future<void> _loadGrns({
    int? targetPage,
    GrnRepository? repositoryOverride,
  }) async {
    final repository = repositoryOverride ?? _repository;
    if (repository == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await repository.fetchGrns(
        page: targetPage ?? _currentPage,
        supplierQuery: _supplierSearchController.text.trim(),
        dateFrom: _dateFromController.text.trim(),
        dateTo: _dateToController.text.trim(),
        dueAbove: double.tryParse(_dueAboveController.text.trim()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _grns = result.records;
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
      AppToast.error('Failed to load GRNs: ${_readableError(error)}');
    }
  }

  void _applyFiltersDebounced() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      _loadGrns(targetPage: 1);
    });
  }

  Future<void> _openCreateGrnDialog() async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('GRN service is still loading. Please try again.');
      return;
    }

    final result = await showDialog<GrnDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateGrnDialog(
        repository: repository,
        productSuggestions: _productSuggestions,
        supplierSuggestions: _supplierSuggestions,
      ),
    );

    if (result == null) {
      return;
    }

    await _reloadSuggestions();
    await _loadGrns(targetPage: 1);

    AppToast.success(
      result.addToStock
          ? 'GRN saved and stock added successfully'
          : 'GRN created successfully',
    );
  }

  Future<void> _showGrnDetails(GrnRecord record) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('GRN service is still loading. Please try again.');
      return;
    }

    setState(() => _loadingGrnId = record.id);
    GrnRecord? freshRecord;
    try {
      freshRecord = await repository.fetchGrnById(record.id);
    } catch (error) {
      if (mounted) {
        setState(() => _loadingGrnId = null);
        AppToast.error('Failed to load GRN details: ${_readableError(error)}');
      }
      return;
    }

    if (!mounted || freshRecord == null) {
      if (mounted) {
        setState(() => _loadingGrnId = null);
      }
      AppToast.error('GRN details not found');
      return;
    }

    final resolvedRecord = freshRecord;
    setState(() => _loadingGrnId = null);

    showDialog<void>(
      context: context,
      builder: (context) => GrnDetailsDialog(
        record: resolvedRecord,
        onPayDue: () => _showPayDueDialog(resolvedRecord),
        onAddPendingToStock: () => _addPendingItemsToStock(resolvedRecord),
      ),
    );
  }

  Future<void> _addPendingItemsToStock(GrnRecord record) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('GRN service is still loading. Please try again.');
      return;
    }

    try {
      final updated = await repository.addPendingItemsToStock(record.id);
      await _loadGrns(targetPage: _currentPage);
      if (!mounted || updated == null) {
        AppToast.error('Failed to add GRN items to stock');
        return;
      }

      AppToast.success('Pending GRN items added to stock');
      await Navigator.of(context).maybePop();
      if (!mounted) {
        return;
      }
      _showGrnDetails(updated);
    } catch (error) {
      AppToast.error('Failed to add items to stock: ${_readableError(error)}');
    }
  }

  Future<void> _showPayDueDialog(GrnRecord record) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('GRN service is still loading. Please try again.');
      return;
    }

    final result = await showDialog<PayDueResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PayDueDialog(record: record),
    );
    if (result == null) {
      return;
    }

    try {
      final updated = await repository.recordDuePayment(
        grnId: record.id,
        amount: result.amount,
        method: result.method,
      );
      await _loadGrns(targetPage: _currentPage);
      if (!mounted || updated == null) {
        AppToast.error('Failed to update GRN payment');
        return;
      }

      AppToast.success('Payment recorded successfully');
      await Navigator.of(context).maybePop();
      if (!mounted) {
        return;
      }
      _showGrnDetails(updated);
    } catch (error) {
      AppToast.error('Failed to record payment: ${_readableError(error)}');
    }
  }

  String _readableError(Object error) {
    if (error is GrnLocalRepositoryException) {
      return error.message;
    }
    if (error is GrnRemoteRepositoryException) {
      return error.message;
    }
    return error.toString();
  }

  String get _footerText {
    if (_totalCount == 0) {
      return 'Showing 0 to 0 of 0 GRNs';
    }

    final start = ((_currentPage - 1) * _pageSize) + 1;
    final end = (start + _grns.length) - 1;
    return 'Showing $start to $end of $_totalCount GRNs';
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
              const Expanded(child: _GrnHeader()),
              const SizedBox(width: 16),
              _ActionButton(
                label: 'New GRN',
                icon: Icons.add,
                onPressed: _repository == null ? null : _openCreateGrnDialog,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _GrnFilterCard(
            supplierController: _supplierSearchController,
            dateFromController: _dateFromController,
            dateToController: _dateToController,
            dueAboveController: _dueAboveController,
            onApply: () => _loadGrns(targetPage: 1),
            onChanged: _applyFiltersDebounced,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _isLoading
                ? const _GrnTableSkeleton()
                : _GrnTableCard(
                    records: _grns,
                    footerText: _footerText,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    loadingGrnId: _loadingGrnId,
                    onView: _showGrnDetails,
                    onPreviousPage: _currentPage > 1
                        ? () => _loadGrns(targetPage: _currentPage - 1)
                        : null,
                    onNextPage: _currentPage < _totalPages
                        ? () => _loadGrns(targetPage: _currentPage + 1)
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _GrnTableSkeleton extends StatelessWidget {
  const _GrnTableSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.35, end: 0.9),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: Column(
          children: [
            const SizedBox(height: 4),
            for (var index = 0; index < 7; index++) ...[
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FB),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              if (index != 6) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class CreateGrnDialog extends StatefulWidget {
  const CreateGrnDialog({
    super.key,
    required this.repository,
    required this.productSuggestions,
    required this.supplierSuggestions,
  });

  final GrnRepository repository;
  final List<String> productSuggestions;
  final List<String> supplierSuggestions;

  @override
  State<CreateGrnDialog> createState() => _CreateGrnDialogState();
}

class _CreateGrnDialogState extends State<CreateGrnDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _stockBarcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyingPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  final TextEditingController _maxDiscountController = TextEditingController();

  String _paymentMethod = 'Cash';
  bool _showSupplierSuggestions = false;
  bool _showProductSuggestions = false;
  final List<GrnItem> _items = [];
  bool _isSaving = false;

  List<String> get _matchingSuppliers {
    final query = _supplierController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.supplierSuggestions.take(6).toList();
    }

    return widget.supplierSuggestions
        .where((supplier) => supplier.toLowerCase().contains(query))
        .take(6)
        .toList();
  }

  List<String> get _matchingProducts {
    final query = _productController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.productSuggestions.take(6).toList();
    }

    return widget.productSuggestions
        .where((product) => product.toLowerCase().contains(query))
        .take(6)
        .toList();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  double get _paidAmount =>
      double.tryParse(_paidAmountController.text.trim()) ?? 0;
  double get _total => _subtotal - _discount;
  double get _dueAmount => _total - _paidAmount;

  @override
  void dispose() {
    _supplierController.dispose();
    _dateController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _productController.dispose();
    _stockBarcodeController.dispose();
    _quantityController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_productController.text.trim().isEmpty) {
      AppToast.error('Select a product first');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final buyingPrice =
        double.tryParse(_buyingPriceController.text.trim()) ?? 0;
    final sellingPrice =
        double.tryParse(_sellingPriceController.text.trim()) ?? 0;

    if (quantity <= 0 || buyingPrice < 0 || sellingPrice < 0) {
      AppToast.error('Enter valid item values');
      return;
    }

    final stockBarcode = _stockBarcodeController.text.trim().isEmpty
        ? _generateStockBarcode()
        : _stockBarcodeController.text.trim();

    final item = GrnItem(
      product: _productController.text.trim(),
      stockBarcode: stockBarcode,
      quantity: quantity,
      buyingPrice: buyingPrice,
      sellingPrice: sellingPrice,
      maxDiscount: double.tryParse(_maxDiscountController.text.trim()) ?? 0,
      inStock: false,
    );

    setState(() {
      _items.add(item);
      _productController.clear();
      _stockBarcodeController.clear();
      _quantityController.clear();
      _buyingPriceController.clear();
      _sellingPriceController.clear();
      _maxDiscountController.clear();
      _showProductSuggestions = false;
    });
  }

  Future<void> _saveGrn({required bool addToStock}) async {
    if (_isSaving) {
      return;
    }

    if (_supplierController.text.trim().isEmpty || _items.isEmpty) {
      AppToast.error('Add supplier and at least one GRN item');
      return;
    }

    final record = GrnRecord(
      id: 'GRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      supplier: _supplierController.text.trim(),
      date: _dateController.text.trim(),
      subTotal: _subtotal,
      discount: _discount,
      paidAmount: _paidAmount,
      items: _items.map((item) => item.copyWithInStock(addToStock)).toList(),
      paymentHistory: const [],
      paymentMethod: _paymentMethod,
    );

    setState(() => _isSaving = true);
    try {
      final saved = await widget.repository.saveGrn(
        record,
        addToStock: addToStock,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pop(GrnDialogResult(record: saved, addToStock: addToStock));
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error('Failed to save GRN: $error');
      setState(() => _isSaving = false);
    }
  }

  String _generateStockBarcode() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    return 'STK-${timestamp.substring(timestamp.length - 10)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 850,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              title: 'Create New GRN',
              onClose: _isSaving ? null : () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF4)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _LabeledField(
                              label: 'Supplier *',
                              child: _SuggestionField(
                                controller: _supplierController,
                                hintText:
                                    'Type supplier name, company or contact...',
                                suggestions: _matchingSuppliers,
                                showSuggestions: _showSupplierSuggestions,
                                onChanged: (_) {
                                  setState(
                                    () => _showSupplierSuggestions = true,
                                  );
                                },
                                onTap: () {
                                  setState(
                                    () => _showSupplierSuggestions = true,
                                  );
                                },
                                onSelect: (value) {
                                  setState(() {
                                    _supplierController.text = value;
                                    _showSupplierSuggestions = false;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LabeledField(
                              label: 'Date *',
                              child: AppDateField(
                                controller: _dateController,
                                hintText: 'Select GRN date',
                                decoration: _dialogFieldDecoration(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _LabeledField(
                              label: 'Discount (\$)',
                              child: _DialogTextField(
                                controller: _discountController,
                                hintText: '0',
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LabeledField(
                              label: 'Paid Amount (\$)',
                              child: _DialogTextField(
                                controller: _paidAmountController,
                                hintText: '0',
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _LabeledField(
                        label: 'Payment Method',
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _paymentMethod = value);
                            }
                          },
                          decoration: _dialogFieldDecoration(),
                          items: const ['Cash', 'Card', 'Bank Transfer']
                              .map(
                                (method) => DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(method),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE7EDF5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Item',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF445166),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _LabeledField(
                              label: 'Product *',
                              child: _SuggestionField(
                                controller: _productController,
                                hintText:
                                    'Type product name, barcode or category...',
                                suggestions: _matchingProducts,
                                showSuggestions: _showProductSuggestions,
                                onChanged: (_) {
                                  setState(
                                    () => _showProductSuggestions = true,
                                  );
                                },
                                onTap: () {
                                  setState(
                                    () => _showProductSuggestions = true,
                                  );
                                },
                                onSelect: (value) {
                                  setState(() {
                                    _productController.text = value;
                                    _showProductSuggestions = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledField(
                                    label: 'Stock Barcode',
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _DialogTextField(
                                            controller: _stockBarcodeController,
                                            hintText: 'Auto-generated if empty',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          height: 40,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _stockBarcodeController.text =
                                                    _generateStockBarcode();
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF36B4AE,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.view_stream_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Generate',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LabeledField(
                                    label: 'Quantity *',
                                    child: _DialogTextField(
                                      controller: _quantityController,
                                      hintText: '0',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledField(
                                    label: 'Buying Price (\$) *',
                                    child: _DialogTextField(
                                      controller: _buyingPriceController,
                                      hintText: '0.00',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LabeledField(
                                    label: 'Selling Price (\$) *',
                                    child: _DialogTextField(
                                      controller: _sellingPriceController,
                                      hintText: '0.00',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _LabeledField(
                              label: 'Maximum Discount Price (\$)',
                              child: _DialogTextField(
                                controller: _maxDiscountController,
                                hintText: '0.00',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _addItem,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF36B4AE),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text(
                                  'Add Item to GRN',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'GRN Items (${_items.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF445166),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE7EDF5)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FBFD),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 30,
                                    child: _HeaderText('Product'),
                                  ),
                                  Expanded(flex: 8, child: _HeaderText('Qty')),
                                  Expanded(
                                    flex: 14,
                                    child: _HeaderText('Buying Price'),
                                  ),
                                  Expanded(
                                    flex: 14,
                                    child: _HeaderText('Selling Price'),
                                  ),
                                  Expanded(
                                    flex: 14,
                                    child: _HeaderText('Subtotal'),
                                  ),
                                  Expanded(
                                    flex: 10,
                                    child: _HeaderText('Actions'),
                                  ),
                                ],
                              ),
                            ),
                            if (_items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text(
                                  'No items added yet',
                                  style: TextStyle(
                                    color: Color(0xFF92A0B4),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            for (var i = 0; i < _items.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 30,
                                      child: Text(_items[i].product),
                                    ),
                                    Expanded(
                                      flex: 8,
                                      child: Text('${_items[i].quantity}'),
                                    ),
                                    Expanded(
                                      flex: 14,
                                      child: Text(
                                        '\$${_items[i].buyingPrice.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 14,
                                      child: Text(
                                        '\$${_items[i].sellingPrice.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 14,
                                      child: Text(
                                        '\$${_items[i].subtotal.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 10,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() => _items.removeAt(i));
                                        },
                                        child: const Text(
                                          'Remove',
                                          style: TextStyle(
                                            color: Color(0xFFFA6A6A),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _SummaryValueRow(
                              label: 'Sub Total:',
                              value: '\$${_subtotal.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 8),
                            _SummaryValueRow(
                              label: 'Discount:',
                              value: '-\$${_discount.toStringAsFixed(2)}',
                              valueColor: const Color(0xFFFA6A6A),
                            ),
                            const SizedBox(height: 12),
                            _SummaryValueRow(
                              label: 'Total:',
                              value: '\$${_total.toStringAsFixed(2)}',
                              large: true,
                              valueColor: const Color(0xFF36B4AE),
                            ),
                            const SizedBox(height: 8),
                            _SummaryValueRow(
                              label: 'Paid Amount:',
                              value: '\$${_paidAmount.toStringAsFixed(2)}',
                              valueColor: const Color(0xFF36B4AE),
                            ),
                            const SizedBox(height: 8),
                            _SummaryValueRow(
                              label: 'Due Amount:',
                              value: '\$${_dueAmount.toStringAsFixed(2)}',
                              valueColor: const Color(0xFFFA6A6A),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FBFD),
                border: Border(top: BorderSide(color: Color(0xFFE8EDF4))),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _items.isEmpty || _isSaving
                        ? null
                        : () => _saveGrn(addToStock: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF36B4AE),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD6DDE7),
                      disabledForegroundColor: const Color(0xFF98A5B7),
                      elevation: 0,
                      minimumSize: const Size(110, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save GRN',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _items.isEmpty || _isSaving
                        ? null
                        : () => _saveGrn(addToStock: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2FAE87),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD6DDE7),
                      disabledForegroundColor: const Color(0xFF98A5B7),
                      elevation: 0,
                      minimumSize: const Size(178, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined, size: 16),
                    label: Text(
                      _isSaving ? 'Please wait...' : 'Save & Add to Stock',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

class GrnDetailsDialog extends StatefulWidget {
  const GrnDetailsDialog({
    super.key,
    required this.record,
    required this.onPayDue,
    required this.onAddPendingToStock,
  });

  final GrnRecord record;
  final Future<void> Function() onPayDue;
  final Future<void> Function() onAddPendingToStock;

  @override
  State<GrnDetailsDialog> createState() => _GrnDetailsDialogState();
}

class _GrnDetailsDialogState extends State<GrnDetailsDialog> {
  bool _isPayingDue = false;
  bool _isAddingStock = false;

  Future<void> _handlePayDue() async {
    if (_isPayingDue) {
      return;
    }
    setState(() => _isPayingDue = true);
    try {
      await widget.onPayDue();
    } finally {
      if (mounted) {
        setState(() => _isPayingDue = false);
      }
    }
  }

  Future<void> _handleAddPendingToStock() async {
    if (_isAddingStock) {
      return;
    }
    setState(() => _isAddingStock = true);
    try {
      await widget.onAddPendingToStock();
    } finally {
      if (mounted) {
        setState(() => _isAddingStock = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 720,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF36B4AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GRN Details',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${record.id}',
                        style: const TextStyle(
                          color: Color(0xFFE6FFFA),
                          fontWeight: FontWeight.w600,
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          label: 'Supplier',
                          value: record.supplier,
                          icon: Icons.local_shipping_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoTile(
                          label: 'Date',
                          value: record.date,
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AmountTile(
                          label: 'Sub Total',
                          value: record.subTotal,
                          positive: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AmountTile(
                          label: 'Discount',
                          value: record.discount,
                          positive: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AmountTile(
                          label: 'Total Amount',
                          value: record.total,
                          positive: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AmountTile(
                          label: 'Due Amount',
                          value: record.dueAmount,
                          positive: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (record.items.any((item) => !item.inStock)) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAddingStock
                                ? null
                                : _handleAddPendingToStock,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF48BB78),
                            ),
                            icon: _isAddingStock
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                  ),
                            label: Text(
                              _isAddingStock
                                  ? 'Adding to Stock...'
                                  : 'Add Pending Items to Stock',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: record.dueAmount <= 0 || _isPayingDue
                              ? null
                              : _handlePayDue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF36B4AE),
                          ),
                          icon: _isPayingDue
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.attach_money_rounded,
                                  size: 16,
                                ),
                          label: Text(
                            _isPayingDue ? 'Processing...' : 'Pay Due Amount',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Payment History',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF445166),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SimpleTable(
                    headers: const [
                      'Date/Time',
                      'Payment Amount',
                      'Payment Method',
                      'Remaining Balance',
                    ],
                    rows: record.paymentHistory
                        .map(
                          (payment) => [
                            payment.dateTime,
                            '\$${payment.amount.toStringAsFixed(2)}',
                            payment.method,
                            '\$${payment.remainingBalance.toStringAsFixed(2)}',
                          ],
                        )
                        .toList(),
                    emphasizeColumn: 1,
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'GRN Items',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF445166),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SimpleTable(
                    headers: const [
                      'Product',
                      'Stock Barcode',
                      'Quantity',
                      'Buying Price',
                      'Selling Price',
                      'Status',
                    ],
                    rows: record.items
                        .map(
                          (item) => [
                            item.product,
                            item.stockBarcode,
                            '${item.quantity}',
                            '\$${item.buyingPrice.toStringAsFixed(2)}',
                            '\$${item.sellingPrice.toStringAsFixed(2)}',
                            item.inStock ? 'In Stock' : 'Pending',
                          ],
                        )
                        .toList(),
                    statusColumn: 5,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 20, 20),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PayDueDialog extends StatefulWidget {
  const PayDueDialog({super.key, required this.record});

  final GrnRecord record;

  @override
  State<PayDueDialog> createState() => _PayDueDialogState();
}

class _PayDueDialogState extends State<PayDueDialog> {
  late final TextEditingController _amountController;
  String _method = 'Cash';

  double get _currentDue => widget.record.dueAmount;
  double get _enteredAmount => double.tryParse(_amountController.text) ?? 0;
  double get _remaining => math.max(0, _currentDue - _enteredAmount);

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.record.dueAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_enteredAmount <= 0 || _enteredAmount > _currentDue) {
      AppToast.error('Enter a valid payment amount');
      return;
    }

    Navigator.of(
      context,
    ).pop(PayDueResult(amount: _enteredAmount, method: _method));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 410,
        decoration: _dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF36B4AE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pay Due Amount',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supplier: ${widget.record.supplier}',
                        style: const TextStyle(
                          color: Color(0xFFE6FFFA),
                          fontWeight: FontWeight.w600,
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDADB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Due Amount',
                          style: TextStyle(
                            color: Color(0xFFF46A6A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_currentDue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334156),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FormLabel('Payment Amount *'),
                  const SizedBox(height: 8),
                  _DialogTextField(
                    controller: _amountController,
                    hintText: '0.00',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  const _FormLabel('Payment Method *'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _method,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _method = value);
                      }
                    },
                    decoration: _dialogFieldDecoration(),
                    items: const ['Cash', 'Card', 'Bank Transfer']
                        .map(
                          (method) => DropdownMenuItem<String>(
                            value: method,
                            child: Text(method),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF8F4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Final Balance to Pay',
                          style: TextStyle(
                            color: Color(0xFF36B4AE),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_remaining.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334156),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FBFD),
                border: Border(top: BorderSide(color: Color(0xFFE8EDF4))),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF36B4AE),
                    ),
                    icon: const Icon(Icons.attach_money_rounded, size: 16),
                    label: const Text('Pay'),
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

class _GrnHeader extends StatelessWidget {
  const _GrnHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goods Received Notes',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Track and manage incoming stock deliveries.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8492A6),
          ),
        ),
      ],
    );
  }
}

class _GrnFilterCard extends StatelessWidget {
  const _GrnFilterCard({
    required this.supplierController,
    required this.dateFromController,
    required this.dateToController,
    required this.dueAboveController,
    required this.onApply,
    required this.onChanged,
  });

  final TextEditingController supplierController;
  final TextEditingController dateFromController;
  final TextEditingController dateToController;
  final TextEditingController dueAboveController;
  final VoidCallback onApply;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search & Filter GRN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF344256),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Supplier Name',
                  child: _FilterTextField(
                    controller: supplierController,
                    hintText: 'Search by supplier...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'Date From',
                  child: AppDateField(
                    controller: dateFromController,
                    hintText: 'yyyy-mm-dd',
                    decoration: _filterFieldDecoration(),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'Date To',
                  child: AppDateField(
                    controller: dateToController,
                    hintText: 'yyyy-mm-dd',
                    decoration: _filterFieldDecoration(),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'Due Payment Above',
                  child: _FilterTextField(
                    controller: dueAboveController,
                    hintText: '0.00',
                    prefixText: '\$',
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF36B4AE),
              ),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrnTableCard extends StatelessWidget {
  const _GrnTableCard({
    required this.records,
    required this.footerText,
    required this.currentPage,
    required this.totalPages,
    required this.loadingGrnId,
    required this.onView,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final List<GrnRecord> records;
  final String footerText;
  final int currentPage;
  final int totalPages;
  final String? loadingGrnId;
  final Future<void> Function(GrnRecord) onView;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 20, child: _HeaderText('GRN ID')),
                Expanded(flex: 16, child: _HeaderText('Supplier')),
                Expanded(flex: 14, child: _HeaderText('Date')),
                Expanded(flex: 16, child: _HeaderText('Sub Total')),
                Expanded(flex: 14, child: _HeaderText('Discount')),
                Expanded(flex: 16, child: _HeaderText('Total')),
                Expanded(flex: 16, child: _HeaderText('Due Amount')),
                Expanded(flex: 14, child: _HeaderText('Actions')),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      'No GRNs found',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8492A6),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF0F4F8)),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final highlighted = index == 3;
                      final isLoading = loadingGrnId == record.id;
                      return Container(
                        color: highlighted ? const Color(0xFFF7FAFC) : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 20,
                              child: Text(
                                record.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 14,
                                    color: Color(0xFFAAB5C4),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(record.supplier)),
                                ],
                              ),
                            ),
                            Expanded(flex: 14, child: Text(record.date)),
                            Expanded(
                              flex: 16,
                              child: Text(
                                '\$${record.subTotal.toStringAsFixed(2)}',
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: Text(
                                '\$${record.discount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFFA6A6A),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Text(
                                '\$${record.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF36B4AE),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 16,
                              child: Text(
                                '\$${record.dueAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: record.dueAmount <= 0
                                      ? const Color(0xFF36B4AE)
                                      : const Color(0xFFFA6A6A),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          onView(record);
                                        },
                                  icon: isLoading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 14,
                                        ),
                                  label: Text(
                                    isLoading ? 'Loading...' : 'View',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(64, 32),
                                    side: const BorderSide(
                                      color: Color(0xFFE1E8F1),
                                    ),
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
          const Divider(color: Color(0xFFF0F4F8)),
          Row(
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
              _PagerButton(
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _PagerButton(
                icon: Icons.chevron_right_rounded,
                enabled: onNextPage != null,
                onTap: onNextPage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionField extends StatelessWidget {
  const _SuggestionField({
    required this.controller,
    required this.hintText,
    required this.suggestions,
    required this.showSuggestions,
    required this.onChanged,
    required this.onTap,
    required this.onSelect,
  });

  final TextEditingController controller;
  final String hintText;
  final List<String> suggestions;
  final bool showSuggestions;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogTextField(
          controller: controller,
          hintText: hintText,
          onChanged: onChanged,
          onTap: onTap,
        ),
        if (showSuggestions && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7EDF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final suggestion in suggestions)
                  InkWell(
                    onTap: () => onSelect(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF445166),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SimpleTable extends StatelessWidget {
  const _SimpleTable({
    required this.headers,
    required this.rows,
    this.emphasizeColumn,
    this.statusColumn,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final int? emphasizeColumn;
  final int? statusColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FBFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                for (final header in headers)
                  Expanded(child: _HeaderText(header)),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('No records yet'),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++)
                    Expanded(
                      child: statusColumn == i
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: row[i] == 'In Stock'
                                      ? const Color(0xFFE7FBF7)
                                      : const Color(0xFFF8FBFD),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  row[i],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: row[i] == 'In Stock'
                                        ? const Color(0xFF36B4AE)
                                        : const Color(0xFF8492A6),
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              row[i],
                              style: TextStyle(
                                fontWeight: emphasizeColumn == i
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: emphasizeColumn == i
                                    ? const Color(0xFF36B4AE)
                                    : const Color(0xFF5B687B),
                              ),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E9CAF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.positive,
  });

  final String label;
  final double value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFDDF8F4) : const Color(0xFFFFE3E3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: positive
                  ? const Color(0xFF36B4AE)
                  : const Color(0xFFF46A6A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334156),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValueRow extends StatelessWidget {
  const _SummaryValueRow({
    required this.label,
    required this.value,
    this.large = false,
    this.valueColor = const Color(0xFF445166),
  });

  final String label;
  final String value;
  final bool large;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 16 : 14,
            fontWeight: large ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF6B778C),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 16 : 14,
            fontWeight: large ? FontWeight.w800 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF36B4AE),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_FormLabel(label), const SizedBox(height: 8), child],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8B98AB),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8B98AB),
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.prefixText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final String? prefixText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: _filterFieldDecoration(
        hintText: hintText,
        prefixText: prefixText,
        prefixIcon: prefixIcon,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334156),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Color(0xFF8090A4)),
          ),
        ],
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.onChanged,
    this.onTap,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onTap: onTap,
      decoration: _dialogFieldDecoration(hintText: hintText),
    );
  }
}

InputDecoration _dialogFieldDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFA2AEBD),
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF36B4AE), width: 2),
    ),
  );
}

InputDecoration _filterFieldDecoration({
  String? hintText,
  IconData? prefixIcon,
  String? prefixText,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixText: prefixText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: const Color(0xFF95A2B5), size: 18),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF36B4AE), width: 1.6),
    ),
  );
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE7EDF5)),
    boxShadow: const [
      BoxShadow(color: Color(0x120F172A), blurRadius: 16, offset: Offset(0, 6)),
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
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
  );
}
