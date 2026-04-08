import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../models/models.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController _searchController = TextEditingController();

  ProductFilter _selectedFilter = ProductFilter.name;
  final List<String> _categories = [
    '55',
    '444',
    'busicuts',
    '44',
    'd',
    '4',
    'cat1',
    'fruits',
  ];

  late final List<ProductRecord> _products = [
    ProductRecord(
      name: '555',
      barcode: '8908077319466',
      category: '55',
      unit: 'ITEMS',
      lowStock: 555,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: '444',
      barcode: '8909131772822',
      category: '444',
      unit: 'ITEMS',
      lowStock: 44,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: 'product5',
      barcode: '40440444',
      category: 'busicuts',
      unit: 'ITEMS',
      lowStock: 22,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: '444',
      barcode: '8903332598783',
      category: '44',
      unit: 'ITEMS',
      lowStock: 44,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: 'manchee super cream cracker',
      barcode: '40440444',
      category: 'busicuts',
      unit: 'PACKETS',
      lowStock: 20,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: 'dodam',
      barcode: '8907916638112',
      category: 'd',
      unit: 'ITEMS',
      lowStock: 2,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: '444',
      barcode: '8900439305666',
      category: '4',
      unit: 'ITEMS',
      lowStock: 44,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: '44',
      barcode: '8903800200289',
      category: '444',
      unit: 'ITEMS',
      lowStock: 44,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: '5555',
      barcode: '8907366713413',
      category: '55',
      unit: 'ITEMS',
      lowStock: 55,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: 'product1',
      barcode: '1992222',
      category: 'cat1',
      unit: 'ITEMS',
      lowStock: 22,
      status: ProductStatus.active,
    ),
    ProductRecord(
      name: 'apple',
      barcode: '8902723378806',
      category: 'fruits',
      unit: 'KG',
      lowStock: 10,
      status: ProductStatus.active,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductRecord> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _products;
    }

    return _products.where((product) {
      final value = switch (_selectedFilter) {
        ProductFilter.name => product.name,
        ProductFilter.category => product.category,
        ProductFilter.barcode => product.barcode,
      }.toLowerCase();

      return value.contains(query);
    }).toList();
  }

  Future<void> _openProductDialog({ProductRecord? product, int? index}) async {
    final result = await showDialog<ProductDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ProductFormDialog(
          existingCategories: _categories,
          initialProduct: product,
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      if (!_categories.any(
        (category) =>
            category.toLowerCase() == result.product.category.toLowerCase(),
      )) {
        _categories.add(result.product.category);
        _categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }

      if (index == null) {
        _products.insert(0, result.product);
      } else {
        _products[index] = result.product;
      }
    });

    if (result.createdCategory) {
      AppToast.success('New category "${result.product.category}" created');
    }

    AppToast.success(
      index == null
          ? 'Product added successfully'
          : 'Product updated successfully',
    );
  }

  String get _footerText {
    final count = math.min(_filteredProducts.length, 10);
    return 'Showing 1 to $count of ${_filteredProducts.length} products';
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _ProductsHeader()),
              const SizedBox(width: 16),
              _ActionButton(
                label: 'Add Product',
                icon: Icons.add,
                onPressed: _openProductDialog,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE7EDF5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final filter in ProductFilter.values) ...[
                        _FilterChipButton(
                          filter: filter,
                          isSelected: _selectedFilter == filter,
                          onTap: () {
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                        if (filter != ProductFilter.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: switch (_selectedFilter) {
                          ProductFilter.name => 'Search by name...',
                          ProductFilter.category => 'Search by category...',
                          ProductFilter.barcode => 'Search by barcode...',
                        },
                        hintStyle: const TextStyle(
                          color: Color(0xFFA2AEBD),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Color(0xFF9CACBE),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4EAF2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4EAF2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF36B4AE),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProductTableHeader(),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFF0F4F8)),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final actualIndex = _products.indexOf(product);

                        return _ProductTableRow(
                          product: product,
                          isHighlighted: product.name == 'dodam',
                          onEdit: () => _openProductDialog(
                            product: product,
                            index: actualIndex,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _footerText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8492A6),
                        ),
                      ),
                      const Spacer(),
                      _PaginationButton(
                        icon: Icons.chevron_left_rounded,
                        enabled: false,
                        onTap: null,
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
                        child: const Text(
                          'Page 1 of 2',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF526177),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PaginationButton(
                        icon: Icons.chevron_right_rounded,
                        enabled: true,
                        onTap: () {
                          AppToast.info(
                            'Pagination will be wired to data next',
                          );
                        },
                      ),
                    ],
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

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.existingCategories,
    this.initialProduct,
  });

  final List<String> existingCategories;
  final ProductRecord? initialProduct;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _lowStockController;

  late String _selectedUnit;
  late ProductStatus _selectedStatus;
  bool _showCategorySuggestions = false;

  bool get _isEditing => widget.initialProduct != null;

  List<String> get _matchingCategories {
    final query = _categoryController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.existingCategories.take(6).toList();
    }

    return widget.existingCategories
        .where((category) => category.toLowerCase().contains(query))
        .toList();
  }

  bool get _shouldOfferCreateCategory {
    final value = _categoryController.text.trim();
    if (value.isEmpty) {
      return false;
    }

    return !widget.existingCategories.any(
      (category) => category.toLowerCase() == value.toLowerCase(),
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProduct;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _barcodeController = TextEditingController(text: initial?.barcode ?? '');
    _categoryController = TextEditingController(text: initial?.category ?? '');
    _lowStockController = TextEditingController(
      text: initial?.lowStock.toString() ?? '50',
    );
    _selectedUnit = initial?.unit ?? 'ITEMS';
    _selectedStatus = initial?.status ?? ProductStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _barcodeController.text = '890${random.substring(random.length - 10)}';
    });
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final product = ProductRecord(
      name: _nameController.text.trim(),
      barcode: _barcodeController.text.trim(),
      category: _categoryController.text.trim(),
      unit: _selectedUnit,
      lowStock: int.parse(_lowStockController.text.trim()),
      status: _selectedStatus,
    );

    Navigator.of(context).pop(
      ProductDialogResult(
        product: product,
        createdCategory: _shouldOfferCreateCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _matchingCategories;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 540,
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
                    _isEditing ? 'Edit Product' : 'Add New Product',
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
                    _FormLabel('Product Name *'),
                    const SizedBox(height: 8),
                    _DialogTextField(
                      controller: _nameController,
                      hintText: 'Enter product name',
                      prefixIcon: Icons.inventory_2_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _FormLabel('Product Barcode *'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogTextField(
                            controller: _barcodeController,
                            hintText: 'Enter barcode number',
                            prefixIcon: Icons.view_stream_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Barcode is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
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
                    _FormLabel('Category *'),
                    const SizedBox(height: 8),
                    _CategoryAutocompleteField(
                      controller: _categoryController,
                      suggestions: suggestions,
                      showSuggestions: _showCategorySuggestions,
                      shouldOfferCreate: _shouldOfferCreateCategory,
                      onChanged: (_) {
                        setState(() {
                          _showCategorySuggestions = true;
                        });
                      },
                      onTap: () {
                        setState(() {
                          _showCategorySuggestions = true;
                        });
                      },
                      onSelectSuggestion: (category) {
                        setState(() {
                          _categoryController.text = category;
                          _showCategorySuggestions = false;
                        });
                      },
                      onCreateCategory: () {
                        setState(() {
                          _showCategorySuggestions = false;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Category is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _FormLabel('Unit *'),
                    const SizedBox(height: 8),
                    _DialogDropdown<String>(
                      value: _selectedUnit,
                      prefixIcon: Icons.inventory_2_outlined,
                      items: const ['ITEMS', 'KG', 'L', 'PACKETS', 'M'],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedUnit = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _FormLabel('Low Stock Quantity *'),
                    const SizedBox(height: 8),
                    _DialogTextField(
                      controller: _lowStockController,
                      hintText: '50',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Low stock quantity is required';
                        }
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _FormLabel('Active Status'),
                    const SizedBox(height: 8),
                    _DialogDropdown<ProductStatus>(
                      value: _selectedStatus,
                      prefixIcon: Icons.layers_outlined,
                      items: ProductStatus.values,
                      itemLabelBuilder: (status) => status.label,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStatus = value);
                        }
                      },
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
                      minimumSize: const Size(140, 40),
                      backgroundColor: const Color(0xFF36B4AE),
                    ),
                    child: Text(
                      _isEditing ? 'Update Product' : 'Add Product',
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

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Products',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage your product inventory and details.',
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

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final ProductFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF36B4AE) : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF36B4AE)
                : const Color(0xFFE3E9F1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              filter.icon,
              size: 15,
              color: isSelected ? AppColors.white : const Color(0xFF56657A),
            ),
            const SizedBox(width: 8),
            Text(
              filter.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.white : const Color(0xFF56657A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 33, child: _HeaderText('Product Name')),
          Expanded(flex: 21, child: _HeaderText('Barcode')),
          Expanded(flex: 12, child: _HeaderText('Category')),
          Expanded(flex: 12, child: _HeaderText('Unit')),
          Expanded(flex: 12, child: _HeaderText('Low Stock')),
          Expanded(flex: 10, child: _HeaderText('Status')),
          Expanded(flex: 12, child: _HeaderText('Actions')),
        ],
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

class _ProductTableRow extends StatelessWidget {
  const _ProductTableRow({
    required this.product,
    required this.isHighlighted,
    required this.onEdit,
  });

  final ProductRecord product;
  final bool isHighlighted;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isHighlighted ? const Color(0xFFF7FAFC) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 33,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7FBF7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF36B4AE),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF445166),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 21,
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
                    product.barcode,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8492A6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              product.category,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7E8CA1),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  product.unit,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6A778B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '${product.lowStock}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F7D92),
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
                  color: const Color(0xFFE7FBF7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  product.status.label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF36B4AE),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(60, 32),
                  side: const BorderSide(color: Color(0xFFE1E8F1)),
                  foregroundColor: const Color(0xFF445166),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryAutocompleteField extends StatelessWidget {
  const _CategoryAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.showSuggestions,
    required this.shouldOfferCreate,
    required this.onChanged,
    required this.onTap,
    required this.onSelectSuggestion,
    required this.onCreateCategory,
    required this.validator,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final bool showSuggestions;
  final bool shouldOfferCreate;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final ValueChanged<String> onSelectSuggestion;
  final VoidCallback onCreateCategory;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final trimmedValue = controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogTextField(
          controller: controller,
          hintText: 'Select or create category',
          prefixIcon: Icons.label_outline_rounded,
          onChanged: onChanged,
          onTap: onTap,
          validator: validator,
        ),
        if (showSuggestions &&
            (suggestions.isNotEmpty || shouldOfferCreate)) ...[
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
                    onTap: () => onSelectSuggestion(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
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
                if (shouldOfferCreate) ...[
                  if (suggestions.isNotEmpty)
                    const Divider(height: 1, color: Color(0xFFF1F5F8)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: const Text(
                      'No existing category found',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8190A5),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onCreateCategory,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Text(
                        '+ Create "$trimmedValue"',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF36B4AE),
                        ),
                      ),
                    ),
                  ),
                ],
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
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.onTap,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
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
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: const Color(0xFF8FA0B5)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
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

class _DialogDropdown<T> extends StatelessWidget {
  const _DialogDropdown({
    required this.value,
    required this.prefixIcon,
    required this.items,
    required this.onChanged,
    this.itemLabelBuilder,
  });

  final T value;
  final IconData prefixIcon;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T item)? itemLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF8FA0B5)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
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
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabelBuilder?.call(item) ?? item.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF445166),
                ),
              ),
            ),
          )
          .toList(),
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

enum ProductFilter {
  name('By Name', Icons.inventory_2_outlined),
  category('By Category', Icons.label_outline_rounded),
  barcode('By Barcode', Icons.view_stream_rounded);

  const ProductFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}
