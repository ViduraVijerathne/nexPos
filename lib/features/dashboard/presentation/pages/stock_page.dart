import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../models/models.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _barcodeSearchController =
      TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _grnSearchController = TextEditingController();
  final TextEditingController _qtyLessController = TextEditingController();
  final TextEditingController _qtyGreaterController = TextEditingController();

  String _selectedStatusFilter = 'All';
  bool _isFilterExpanded = true;

  final List<String> _productSuggestions = [
    '444',
    'manchee super cream cracker',
    'apple',
    'dodam',
    'product5',
    'v',
  ];

  final List<String> _grnSuggestions = [
    'GRN-1001',
    'GRN-1002',
    'GRN-1003',
    'GRN-APPLE-24',
    'GRN-CRACKER-10',
  ];

  late final List<StockRecord> _stocks = [
    StockRecord(
      barcode: '120339',
      product: '444',
      initialQty: 10,
      availableQty: 4,
      buyingPrice: 4,
      sellingPrice: 55,
      maxDiscount: 1,
      status: StockStatus.inactive,
      grnId: 'Not Assigned',
    ),
    StockRecord(
      barcode: '120339',
      product: '444',
      initialQty: 10,
      availableQty: 0,
      buyingPrice: 4,
      sellingPrice: 55,
      maxDiscount: 1,
      status: StockStatus.active,
      grnId: 'GRN-1001',
    ),
    StockRecord(
      barcode: 'STK-1775491845683-pbfer7c31',
      product: 'manchee super cream cracker',
      initialQty: 7,
      availableQty: 7,
      buyingPrice: 99,
      sellingPrice: 88,
      maxDiscount: 0,
      status: StockStatus.active,
      grnId: 'GRN-CRACKER-10',
    ),
    StockRecord(
      barcode: 'STK-1775491815059-tj65mad17',
      product: 'manchee super cream cracker',
      initialQty: 8,
      availableQty: 5,
      buyingPrice: 88,
      sellingPrice: 99,
      maxDiscount: 0,
      status: StockStatus.active,
      grnId: 'GRN-1002',
    ),
    StockRecord(
      barcode: 'STK-1775491789360-ebphsyxbu',
      product: 'manchee super cream cracker',
      initialQty: 7,
      availableQty: 7,
      buyingPrice: 99,
      sellingPrice: 7,
      maxDiscount: 0,
      status: StockStatus.active,
      grnId: 'GRN-1003',
    ),
    StockRecord(
      barcode: 'v',
      product: 'manchee super cream cracker',
      initialQty: 8,
      availableQty: 3,
      buyingPrice: 8,
      sellingPrice: 88,
      maxDiscount: 88,
      status: StockStatus.active,
      grnId: 'GRN-CRACKER-10',
    ),
    StockRecord(
      barcode: 'STK-1775491714698-m3ffqvb3m',
      product: 'apple',
      initialQty: 99,
      availableQty: 95,
      buyingPrice: 77,
      sellingPrice: 888,
      maxDiscount: 0,
      status: StockStatus.active,
      grnId: 'GRN-APPLE-24',
      expiryDate: '2026-12-31',
    ),
    StockRecord(
      barcode: 'STK-1775491682558-3o5mmmzrt',
      product: 'dodam',
      initialQty: 77,
      availableQty: 60,
      buyingPrice: 77,
      sellingPrice: 88,
      maxDiscount: 0,
      status: StockStatus.active,
      grnId: 'GRN-1002',
    ),
    StockRecord(
      barcode: 'STK-1775491653682-qzy1v8xvu',
      product: 'product5',
      initialQty: 77,
      availableQty: 71,
      buyingPrice: 777,
      sellingPrice: 99,
      maxDiscount: 66,
      status: StockStatus.active,
      grnId: 'GRN-1003',
    ),
    StockRecord(
      barcode: 'STK-1775491617229-kdoqdami3',
      product: 'manchee super cream cracker',
      initialQty: 9,
      availableQty: 9,
      buyingPrice: 8,
      sellingPrice: 77,
      maxDiscount: 0,
      status: StockStatus.active,
      grnId: 'GRN-1001',
    ),
  ];

  @override
  void dispose() {
    _barcodeSearchController.dispose();
    _productSearchController.dispose();
    _grnSearchController.dispose();
    _qtyLessController.dispose();
    _qtyGreaterController.dispose();
    super.dispose();
  }

  List<StockRecord> get _filteredStocks {
    return _stocks.where((stock) {
      final barcodeQuery = _barcodeSearchController.text.trim().toLowerCase();
      final productQuery = _productSearchController.text.trim().toLowerCase();
      final grnQuery = _grnSearchController.text.trim().toLowerCase();
      final lessQty = int.tryParse(_qtyLessController.text.trim());
      final greaterQty = int.tryParse(_qtyGreaterController.text.trim());

      if (barcodeQuery.isNotEmpty &&
          !stock.barcode.toLowerCase().contains(barcodeQuery)) {
        return false;
      }
      if (productQuery.isNotEmpty &&
          !stock.product.toLowerCase().contains(productQuery)) {
        return false;
      }
      if (grnQuery.isNotEmpty &&
          !stock.grnId.toLowerCase().contains(grnQuery)) {
        return false;
      }
      if (_selectedStatusFilter != 'All' &&
          stock.status.label != _selectedStatusFilter) {
        return false;
      }
      if (lessQty != null && stock.availableQty >= lessQty) {
        return false;
      }
      if (greaterQty != null && stock.availableQty <= greaterQty) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openStockDialog({StockRecord? stock, int? index}) async {
    final result = await showDialog<StockRecord>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StockFormDialog(
          initialStock: stock,
          products: _productSuggestions,
          grns: _grnSuggestions,
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      if (!_productSuggestions.contains(result.product)) {
        _productSuggestions.add(result.product);
        _productSuggestions.sort();
      }
      if (result.grnId != 'Not Assigned' &&
          !_grnSuggestions.contains(result.grnId)) {
        _grnSuggestions.add(result.grnId);
        _grnSuggestions.sort();
      }

      if (index == null) {
        _stocks.insert(0, result);
      } else {
        _stocks[index] = result;
      }
    });

    AppToast.success(
      index == null ? 'Stock added successfully' : 'Stock updated successfully',
    );
  }

  void _showStockDetails(StockRecord stock) {
    showDialog<void>(
      context: context,
      builder: (context) => StockDetailsDialog(stock: stock),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStocks = _filteredStocks;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _StockHeader()),
              const SizedBox(width: 16),
              _ActionButton(
                label: 'Add New Stock',
                icon: Icons.add,
                onPressed: _openStockDialog,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _StockSummaryCards(),
          const SizedBox(height: 18),
          _StockFilterCard(
            barcodeController: _barcodeSearchController,
            productController: _productSearchController,
            grnController: _grnSearchController,
            qtyLessController: _qtyLessController,
            qtyGreaterController: _qtyGreaterController,
            selectedStatus: _selectedStatusFilter,
            isExpanded: _isFilterExpanded,
            onToggleExpanded: () {
              setState(() => _isFilterExpanded = !_isFilterExpanded);
            },
            onStatusChanged: (value) {
              setState(() => _selectedStatusFilter = value ?? 'All');
            },
            onApply: () => setState(() {}),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _StockTableCard(
              stocks: filteredStocks,
              onView: _showStockDetails,
              onEdit: (stock) {
                final index = _stocks.indexOf(stock);
                _openStockDialog(stock: stock, index: index);
              },
              onDelete: (stock) {
                setState(() => _stocks.remove(stock));
                AppToast.success('Stock deleted successfully');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StockFormDialog extends StatefulWidget {
  const StockFormDialog({
    super.key,
    this.initialStock,
    required this.products,
    required this.grns,
  });

  final StockRecord? initialStock;
  final List<String> products;
  final List<String> grns;

  @override
  State<StockFormDialog> createState() => _StockFormDialogState();
}

class _StockFormDialogState extends State<StockFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _barcodeController;
  late final TextEditingController _initialQtyController;
  late final TextEditingController _availableQtyController;
  late final TextEditingController _buyingPriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _productController;
  late final TextEditingController _grnController;
  late final TextEditingController _expiryDateController;

  bool _isActive = true;
  bool _showProductSuggestions = false;
  bool _showGrnSuggestions = false;

  bool get _isEditing => widget.initialStock != null;

  List<String> get _productMatches {
    final query = _productController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.products.take(6).toList();
    }
    return widget.products
        .where((product) => product.toLowerCase().contains(query))
        .toList();
  }

  List<String> get _grnMatches {
    final query = _grnController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.grns.take(6).toList();
    }
    return widget.grns
        .where((grn) => grn.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final stock = widget.initialStock;
    _barcodeController = TextEditingController(text: stock?.barcode ?? '');
    _initialQtyController = TextEditingController(
      text: stock?.initialQty.toString() ?? '0.00',
    );
    _availableQtyController = TextEditingController(
      text: stock?.availableQty.toString() ?? '0.00',
    );
    _buyingPriceController = TextEditingController(
      text: stock?.buyingPrice.toStringAsFixed(0) ?? '0.00',
    );
    _sellingPriceController = TextEditingController(
      text: stock?.sellingPrice.toStringAsFixed(0) ?? '0.00',
    );
    _maxDiscountController = TextEditingController(
      text: stock?.maxDiscount.toStringAsFixed(0) ?? '0.00',
    );
    _productController = TextEditingController(text: stock?.product ?? '');
    _grnController = TextEditingController(
      text: stock == null || stock.grnId == 'Not Assigned' ? '' : stock.grnId,
    );
    _expiryDateController = TextEditingController(
      text: stock?.expiryDate ?? '',
    );
    _isActive = stock?.status == StockStatus.active || stock == null;
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _initialQtyController.dispose();
    _availableQtyController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _maxDiscountController.dispose();
    _productController.dispose();
    _grnController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _barcodeController.text =
          'STK-${random.substring(math.max(0, random.length - 13))}';
    });
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    Navigator.of(context).pop(
      StockRecord(
        barcode: _barcodeController.text.trim(),
        product: _productController.text.trim(),
        initialQty: int.tryParse(_initialQtyController.text.trim()) ?? 0,
        availableQty: int.tryParse(_availableQtyController.text.trim()) ?? 0,
        buyingPrice: double.tryParse(_buyingPriceController.text.trim()) ?? 0,
        sellingPrice: double.tryParse(_sellingPriceController.text.trim()) ?? 0,
        maxDiscount: double.tryParse(_maxDiscountController.text.trim()) ?? 0,
        status: _isActive ? StockStatus.active : StockStatus.inactive,
        grnId: _grnController.text.trim().isEmpty
            ? 'Not Assigned'
            : _grnController.text.trim(),
        expiryDate: _expiryDateController.text.trim().isEmpty
            ? null
            : _expiryDateController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 700,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              child: Row(
                children: [
                  Text(
                    _isEditing ? 'Edit Stock' : 'Add New Stock',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334156),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8090A4),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormLabel('Stock Barcode *'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogTextField(
                            controller: _barcodeController,
                            hintText: 'Enter stock barcode',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Stock barcode is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: _generateBarcode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF36B4AE),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'Initial Quantity *',
                            child: _DialogTextField(
                              controller: _initialQtyController,
                              hintText: '0.00',
                              keyboardType: TextInputType.number,
                              validator: _requiredNumberValidator,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LabeledField(
                            label: 'Available Quantity *',
                            child: _DialogTextField(
                              controller: _availableQtyController,
                              hintText: '0.00',
                              keyboardType: TextInputType.number,
                              validator: _requiredNumberValidator,
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
                            label: 'Buying Price *',
                            child: _DialogTextField(
                              controller: _buyingPriceController,
                              hintText: '0.00',
                              keyboardType: TextInputType.number,
                              validator: _requiredNumberValidator,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LabeledField(
                            label: 'Selling Price *',
                            child: _DialogTextField(
                              controller: _sellingPriceController,
                              hintText: '0.00',
                              keyboardType: TextInputType.number,
                              validator: _requiredNumberValidator,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LabeledField(
                            label: 'Max Discount *',
                            child: _DialogTextField(
                              controller: _maxDiscountController,
                              hintText: '0.00',
                              keyboardType: TextInputType.number,
                              validator: _requiredNumberValidator,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'Product *',
                            child: _SuggestionField(
                              controller: _productController,
                              hintText: 'Search product...',
                              suggestions: _productMatches,
                              showSuggestions: _showProductSuggestions,
                              onChanged: (_) {
                                setState(() => _showProductSuggestions = true);
                              },
                              onTap: () {
                                setState(() => _showProductSuggestions = true);
                              },
                              onSelect: (value) {
                                setState(() {
                                  _productController.text = value;
                                  _showProductSuggestions = false;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Product is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LabeledField(
                            label: 'GRN (Optional)',
                            child: _SuggestionField(
                              controller: _grnController,
                              hintText: 'Select GRN',
                              suggestions: _grnMatches,
                              showSuggestions: _showGrnSuggestions,
                              onChanged: (_) {
                                setState(() => _showGrnSuggestions = true);
                              },
                              onTap: () {
                                setState(() => _showGrnSuggestions = true);
                              },
                              onSelect: (value) {
                                setState(() {
                                  _grnController.text = value;
                                  _showGrnSuggestions = false;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FormLabel('Expiry Date (Optional)'),
                    const SizedBox(height: 8),
                    _DialogTextField(
                      controller: _expiryDateController,
                      hintText: 'yyyy-mm-dd',
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => setState(() => _isActive = !_isActive),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value ?? false);
                            },
                            activeColor: const Color(0xFF4A86D9),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Mark as Active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF445166),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 40),
                      side: const BorderSide(color: Color(0xFFE0E7F0)),
                      foregroundColor: const Color(0xFF344256),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(130, 40),
                      backgroundColor: const Color(0xFF36B4AE),
                    ),
                    child: Text(
                      _isEditing ? 'Update Stock' : 'Add Stock',
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

  String? _requiredNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'Enter a valid number';
    }
    return null;
  }
}

class StockDetailsDialog extends StatelessWidget {
  const StockDetailsDialog({super.key, required this.stock});

  final StockRecord stock;

  @override
  Widget build(BuildContext context) {
    final utilization = stock.initialQty == 0
        ? 0.0
        : (stock.availableQty / stock.initialQty).clamp(0.0, 1.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 410,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
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
                  const Text(
                    'Stock Details',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
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
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DetailMetric(
                          label: 'Stock Barcode',
                          value: stock.barcode,
                        ),
                      ),
                      Expanded(
                        child: _DetailMetric(
                          label: 'Status',
                          value: stock.status.label,
                          pill: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailMetric(
                          label: 'Initial Quantity',
                          value: '${stock.initialQty}',
                        ),
                      ),
                      Expanded(
                        child: _DetailMetric(
                          label: 'Available Quantity',
                          value: '${stock.availableQty}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailMetric(
                          label: 'Buying Price',
                          value: '\$${stock.buyingPrice.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _DetailMetric(
                          label: 'Selling Price',
                          value: '\$${stock.sellingPrice.toStringAsFixed(2)}',
                          highlight: true,
                        ),
                      ),
                      Expanded(
                        child: _DetailMetric(
                          label: 'Max Discount',
                          value: '\$${stock.maxDiscount.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE8EDF4)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailMetric(
                          label: 'Product',
                          value: stock.product,
                        ),
                      ),
                      Expanded(
                        child: _DetailMetric(
                          label: 'GRN ID',
                          value: stock.grnId,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF8F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Utilization',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF36B4AE),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFBCEFE6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: utilization,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF36A7A0),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(utilization * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF36B4AE),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 18, 18),
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

class _StockHeader extends StatelessWidget {
  const _StockHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stock Management',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Track and manage inventory with complete stock lifecycle.',
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

class _StockSummaryCards extends StatelessWidget {
  const _StockSummaryCards();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total Stock Items',
            value: '12',
            icon: Icons.inventory_2_outlined,
            accent: Color(0xFF36B4AE),
            tint: Color(0xFFE8FBF7),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Active Stocks',
            value: '11',
            icon: Icons.check_circle_outline_rounded,
            accent: Color(0xFF36B4AE),
            tint: Color(0xFFE8FBF7),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Low Stock Items',
            value: '8',
            icon: Icons.warning_amber_rounded,
            accent: Color(0xFFF0AE42),
            tint: Color(0xFFFFF3DE),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Inactive Stocks',
            value: '1',
            icon: Icons.cancel_outlined,
            accent: Color(0xFFA4AEC0),
            tint: Color(0xFFFFF1F1),
          ),
        ),
      ],
    );
  }
}

class _StockFilterCard extends StatelessWidget {
  const _StockFilterCard({
    required this.barcodeController,
    required this.productController,
    required this.grnController,
    required this.qtyLessController,
    required this.qtyGreaterController,
    required this.selectedStatus,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onStatusChanged,
    required this.onApply,
  });

  final TextEditingController barcodeController;
  final TextEditingController productController;
  final TextEditingController grnController;
  final TextEditingController qtyLessController;
  final TextEditingController qtyGreaterController;
  final String selectedStatus;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  color: Color(0xFF445166),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Search & Filter Stocks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF344256),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF8090A4),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Stock Barcode',
                        child: _FilterTextField(
                          controller: barcodeController,
                          hintText: 'Search by barcode...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Product Name',
                        child: _FilterTextField(
                          controller: productController,
                          hintText: 'Search by product...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'GRN ID',
                        child: _FilterTextField(
                          controller: grnController,
                          hintText: 'Search by GRN...',
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
                        label: 'Status',
                        child: DropdownButtonFormField<String>(
                          value: selectedStatus,
                          onChanged: onStatusChanged,
                          decoration: _filterDecoration(),
                          items: const ['All', 'Active', 'Inactive']
                              .map(
                                (status) => DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Qty Less Than',
                        child: _FilterTextField(
                          controller: qtyLessController,
                          hintText: 'e.g. 50',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Qty Greater Than',
                        child: _FilterTextField(
                          controller: qtyGreaterController,
                          hintText: 'e.g. 100',
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text(
                      'Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
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

class _StockTableCard extends StatelessWidget {
  const _StockTableCard({
    required this.stocks,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<StockRecord> stocks;
  final ValueChanged<StockRecord> onView;
  final ValueChanged<StockRecord> onEdit;
  final ValueChanged<StockRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _panelDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Stock Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF344256),
                ),
              ),
              const Spacer(),
              Text(
                'Page 1 · Showing ${math.min(10, stocks.length)} items',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8794A8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _StockTableHeader(),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: stocks.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (context, index) {
                final stock = stocks[index];
                return _StockTableRow(
                  stock: stock,
                  onView: () => onView(stock),
                  onEdit: () => onEdit(stock),
                  onDelete: () => onDelete(stock),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PagerButton(
                label: 'Previous',
                icon: Icons.chevron_left_rounded,
                enabled: false,
                onTap: null,
              ),
              const Spacer(),
              const Text(
                'Page 1',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6D7C92),
                ),
              ),
              const Spacer(),
              _PagerButton(
                label: 'Next',
                icon: Icons.chevron_right_rounded,
                enabled: true,
                onTap: () {
                  AppToast.info('Pagination will be wired to data next');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockTableHeader extends StatelessWidget {
  const _StockTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 28, child: _HeaderText('Barcode')),
          Expanded(flex: 23, child: _HeaderText('Product')),
          Expanded(flex: 9, child: _HeaderText('Initial Qty')),
          Expanded(flex: 11, child: _HeaderText('Available Qty')),
          Expanded(flex: 12, child: _HeaderText('Buying Price')),
          Expanded(flex: 12, child: _HeaderText('Selling Price')),
          Expanded(flex: 12, child: _HeaderText('Max Discount')),
          Expanded(flex: 10, child: _HeaderText('Status')),
          Expanded(flex: 10, child: _HeaderText('Actions')),
        ],
      ),
    );
  }
}

class _StockTableRow extends StatelessWidget {
  const _StockTableRow({
    required this.stock,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final StockRecord stock;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = stock.status == StockStatus.active
        ? const Color(0xFF36B4AE)
        : const Color(0xFF98A4B7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: Row(
              children: [
                const Icon(
                  Icons.view_stream_rounded,
                  size: 14,
                  color: Color(0xFFAAB5C4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stock.barcode,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A586B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 23,
            child: Text(
              stock.product,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7E8CA1),
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: Text(
              '${stock.initialQty}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F7D92),
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: Text(
              '${stock.availableQty}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: stock.availableQty <= 5
                    ? const Color(0xFFF0AE42)
                    : const Color(0xFF6F7D92),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '\$${stock.buyingPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F7D92),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '\$${stock.sellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A586B),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '\$${stock.maxDiscount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF46C2BC),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stock.status.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Row(
              children: [
                _ActionIconButton(
                  icon: Icons.remove_red_eye_outlined,
                  color: const Color(0xFF36B4AE),
                  onTap: onView,
                ),
                const SizedBox(width: 8),
                _ActionIconButton(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF5E88FF),
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _ActionIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFFA6A6A),
                  onTap: onDelete,
                ),
              ],
            ),
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
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final List<String> suggestions;
  final bool showSuggestions;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final ValueChanged<String> onSelect;
  final String? Function(String?)? validator;

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
          validator: validator,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final suggestion in suggestions)
                  InkWell(
                    onTap: () => onSelect(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.hintText,
    this.validator,
    this.onChanged,
    this.onTap,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFA2AEBD),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
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
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: _filterDecoration(hintText: hintText),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF93A0B2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    this.pill = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool pill;
  final bool highlight;

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
            color: Color(0xFF93A0B2),
          ),
        ),
        const SizedBox(height: 6),
        if (pill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7C8AA0),
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? const Color(0xFF36B4AE)
                  : const Color(0xFF445166),
            ),
          ),
      ],
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
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF445166),
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
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8694A7),
      ),
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
  final VoidCallback onPressed;

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

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled
            ? const Color(0xFF526177)
            : const Color(0xFFC1CAD6),
        side: const BorderSide(color: Color(0xFFE4EAF2)),
      ),
    );
  }
}

InputDecoration _filterDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFA2AEBD),
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE4EAF2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF36B4AE)),
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
