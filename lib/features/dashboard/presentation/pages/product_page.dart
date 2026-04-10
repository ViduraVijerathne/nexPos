import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../data/product_local_repository.dart';
import '../../data/product_remote_repository.dart';
import '../../data/product_repository.dart';
import '../../data/product_repository_factory.dart';
import '../../data/grn_repository.dart';
import '../../data/grn_repository_factory.dart';
import '../../data/stock_local_repository.dart';
import '../../data/stock_remote_repository.dart';
import '../../data/stock_repository.dart';
import '../../data/stock_repository_factory.dart';
import '../../models/models.dart';
import 'stock_page.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController _searchController = TextEditingController();

  ProductRepository? _repository;
  StockRepository? _stockRepository;
  GrnRepository? _grnRepository;
  ProductFilter _selectedFilter = ProductFilter.name;
  List<ProductRecord> _products = <ProductRecord>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  int _pageSize = 10;
  bool _isLoading = true;
  String? _viewingProductKey;
  String? _deactivatingProductKey;
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
      final repository = await ProductRepositoryFactory.create();
      final stockRepository = await StockRepositoryFactory.create();
      final grnRepository = await GrnRepositoryFactory.create();
      await repository.initialize();
      await stockRepository.initialize();
      await grnRepository.initialize();
      if (!mounted) {
        return;
      }

      _repository = repository;
      _stockRepository = stockRepository;
      _grnRepository = grnRepository;
      await _loadProducts(repositoryOverride: repository);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load products: $error');
    }
  }

  Future<void> _loadProducts({
    int? targetPage,
    ProductRepository? repositoryOverride,
  }) async {
    final repository = repositoryOverride ?? _repository;
    if (repository == null) {
      return;
    }

    setState(() => _isLoading = true);

    final query = _searchController.text.trim();
    try {
      final result = await repository.fetchProducts(
        page: targetPage ?? _currentPage,
        nameQuery: _selectedFilter == ProductFilter.name ? query : null,
        categoryQuery: _selectedFilter == ProductFilter.category ? query : null,
        barcodeQuery: _selectedFilter == ProductFilter.barcode ? query : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _products = result.products;
        _totalCount = result.totalCount;
        _currentPage = result.currentPage;
        _totalPages = result.totalPages;
        _pageSize = result.pageSize;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      AppToast.error('Failed to load products: ${_readableError(error)}');
    }
  }

  void _handleSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      _loadProducts(targetPage: 1);
    });
  }

  Future<void> _openProductDialog({ProductRecord? product}) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Product service is still loading. Please try again.');
      return;
    }

    final result = await showDialog<ProductDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ProductFormDialog(
          repository: repository,
          initialProduct: product,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      final savedProduct = await repository.saveProduct(result.product);
      if (result.openingStock != null) {
        final stockRepository = await StockRepositoryFactory.create();
        await stockRepository.initialize();
        await stockRepository.saveStock(
          result.openingStock!.copyWith(product: savedProduct.name),
        );
      }
      await _loadProducts(targetPage: product == null ? 1 : _currentPage);

      if (result.createdCategory) {
        AppToast.success('New category "${result.product.category}" created');
      }

      AppToast.success(
        product == null
            ? result.openingStock == null
                  ? 'Product added successfully'
                  : 'Product and opening stock created successfully'
            : 'Product updated successfully',
      );
    } catch (error) {
      AppToast.error('Failed to save product: ${_readableError(error)}');
    }
  }

  Future<void> _showProductDetails(ProductRecord product) async {
    final stockRepository = _stockRepository;
    final grnRepository = _grnRepository;
    if (stockRepository == null || grnRepository == null) {
      AppToast.error(
        'Product details service is still loading. Please try again.',
      );
      return;
    }

    final productKey = product.cloudId ?? '${product.id ?? product.barcode}';
    setState(() => _viewingProductKey = productKey);
    try {
      if (!mounted) {
        return;
      }

      setState(() => _viewingProductKey = null);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProductDetailsDialog(
          product: product,
          stockRepository: stockRepository,
          grnRepository: grnRepository,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _viewingProductKey = null);
      AppToast.error(
        'Failed to load product details: ${_readableError(error)}',
      );
    }
  }

  Future<void> _deactivateProduct(ProductRecord product) async {
    final repository = _repository;
    if (repository == null) {
      AppToast.error('Product service is still loading. Please try again.');
      return;
    }

    final productKey = product.cloudId ?? '${product.id ?? product.barcode}';
    setState(() => _deactivatingProductKey = productKey);
    try {
      await repository.saveProduct(
        product.copyWith(status: ProductStatus.inactive),
      );
      await _loadProducts(targetPage: _currentPage);
      AppToast.success('Product deactivated successfully');
    } catch (error) {
      AppToast.error('Failed to deactivate product: ${_readableError(error)}');
    } finally {
      if (mounted) {
        setState(() => _deactivatingProductKey = null);
      }
    }
  }

  String _readableError(Object error) {
    if (error is ProductLocalRepositoryException) {
      return error.message;
    }
    if (error is ProductRemoteRepositoryException) {
      return error.message;
    }
    if (error is StockLocalRepositoryException) {
      return error.message;
    }
    if (error is StockRemoteRepositoryException) {
      return error.message;
    }
    return error.toString();
  }

  String get _footerText {
    if (_totalCount == 0) {
      return 'Showing 0 to 0 of 0 products';
    }

    final start = ((_currentPage - 1) * _pageSize) + 1;
    final end = (start + _products.length) - 1;
    return 'Showing $start to $end of $_totalCount products';
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
              const Expanded(child: _ProductsHeader()),
              const SizedBox(width: 16),
              _ActionButton(
                label: 'Add Product',
                icon: Icons.add,
                onPressed: _repository == null ? null : _openProductDialog,
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
                            _loadProducts(targetPage: 1);
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
                      onChanged: _handleSearchChanged,
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
                    child: _isLoading
                        ? const _ProductTableSkeleton()
                        : _products.isEmpty
                        ? const Center(
                            child: Text(
                              'No products found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8492A6),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _products.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: Color(0xFFF0F4F8),
                            ),
                            itemBuilder: (context, index) {
                              final product = _products[index];

                              return _ProductTableRow(
                                product: product,
                                isHighlighted: index.isEven,
                                isViewLoading:
                                    _viewingProductKey ==
                                    (product.cloudId ??
                                        '${product.id ?? product.barcode}'),
                                isDeactivateLoading:
                                    _deactivatingProductKey ==
                                    (product.cloudId ??
                                        '${product.id ?? product.barcode}'),
                                onView: () => _showProductDetails(product),
                                onEdit: () =>
                                    _openProductDialog(product: product),
                                onDeactivate: () => _deactivateProduct(product),
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
                        enabled: _currentPage > 1,
                        onTap: () =>
                            _loadProducts(targetPage: _currentPage - 1),
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
                          'Page $_currentPage of $_totalPages',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF526177),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PaginationButton(
                        icon: Icons.chevron_right_rounded,
                        enabled: _currentPage < _totalPages,
                        onTap: () =>
                            _loadProducts(targetPage: _currentPage + 1),
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
    required this.repository,
    this.initialProduct,
  });

  final ProductRepository repository;
  final ProductRecord? initialProduct;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _categoryFocusNode = FocusNode();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _categoryController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _openingStockBarcodeController;
  late final TextEditingController _openingStockQtyController;
  late final TextEditingController _openingStockBuyingPriceController;
  late final TextEditingController _openingStockSellingPriceController;
  late final TextEditingController _openingStockMaxDiscountController;

  late String _selectedUnit;
  late ProductStatus _selectedStatus;

  List<String> _categorySuggestions = <String>[];
  bool _showCategorySuggestions = false;
  bool _isLoadingSuggestions = false;
  bool _isCreatingCategory = false;
  bool _createdCategory = false;
  bool _isSubmitting = false;
  bool _createOpeningStock = false;

  bool get _isEditing => widget.initialProduct != null;

  bool get _shouldOfferCreateCategory {
    final value = _categoryController.text.trim();
    if (value.isEmpty) {
      return false;
    }

    return !_categorySuggestions.any(
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
    _openingStockBarcodeController = TextEditingController();
    _openingStockQtyController = TextEditingController();
    _openingStockBuyingPriceController = TextEditingController();
    _openingStockSellingPriceController = TextEditingController();
    _openingStockMaxDiscountController = TextEditingController();
    _selectedUnit = initial?.unit ?? 'ITEMS';
    _selectedStatus = initial?.status ?? ProductStatus.active;

    _categoryFocusNode.addListener(() {
      if (!_categoryFocusNode.hasFocus) {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (!mounted || _categoryFocusNode.hasFocus) {
            return;
          }

          setState(() => _showCategorySuggestions = false);
        });
      }
    });

    _loadCategorySuggestions(_categoryController.text);
  }

  @override
  void dispose() {
    _categoryFocusNode.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _lowStockController.dispose();
    _openingStockBarcodeController.dispose();
    _openingStockQtyController.dispose();
    _openingStockBuyingPriceController.dispose();
    _openingStockSellingPriceController.dispose();
    _openingStockMaxDiscountController.dispose();
    super.dispose();
  }

  Future<void> _loadCategorySuggestions(String query) async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final suggestions = await widget.repository.fetchCategorySuggestions(
        query,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _categorySuggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categorySuggestions = <String>[];
        _isLoadingSuggestions = false;
      });
    }
  }

  void _generateBarcode() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _barcodeController.text =
          '890${timestamp.substring(timestamp.length - 10)}';
    });
  }

  void _generateOpeningStockBarcode() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _openingStockBarcodeController.text =
          'STK-${timestamp.substring(timestamp.length - 12)}';
    });
  }

  Future<void> _createCategory() async {
    final categoryName = _categoryController.text.trim();
    if (categoryName.isEmpty || _isCreatingCategory) {
      return;
    }

    setState(() => _isCreatingCategory = true);
    try {
      final savedCategory = await widget.repository.createCategory(
        categoryName,
      );
      final suggestions = await widget.repository.fetchCategorySuggestions(
        savedCategory,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _createdCategory = true;
        _categoryController.text = savedCategory;
        _categorySuggestions = suggestions;
        _showCategorySuggestions = false;
      });
    } on ProductLocalRepositoryException catch (error) {
      AppToast.error(error.message);
    } catch (error) {
      AppToast.error('Failed to create category: $error');
    } finally {
      if (mounted) {
        setState(() => _isCreatingCategory = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSubmitting = true);
    final categoryName = _categoryController.text.trim();
    try {
      final categoryExists = await widget.repository.categoryExists(
        categoryName,
      );
      if (!categoryExists) {
        await widget.repository.createCategory(categoryName);
        _createdCategory = true;
      }

      final product = ProductRecord(
        id: widget.initialProduct?.id,
        cloudId: widget.initialProduct?.cloudId,
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim(),
        category: categoryName,
        unit: _selectedUnit,
        lowStock: int.parse(_lowStockController.text.trim()),
        status: _selectedStatus,
      );

      StockRecord? openingStock;
      if (!_isEditing && _createOpeningStock) {
        final openingQty = int.tryParse(_openingStockQtyController.text.trim());
        final buyingPrice = double.tryParse(
          _openingStockBuyingPriceController.text.trim(),
        );
        final sellingPrice = double.tryParse(
          _openingStockSellingPriceController.text.trim(),
        );
        final maxDiscount = double.tryParse(
          _openingStockMaxDiscountController.text.trim(),
        );

        if (_openingStockBarcodeController.text.trim().isEmpty) {
          throw ProductLocalRepositoryException(
            'Opening stock barcode is required',
          );
        }
        if (openingQty == null || openingQty <= 0) {
          throw ProductLocalRepositoryException(
            'Enter a valid opening stock quantity',
          );
        }
        if (buyingPrice == null || buyingPrice < 0) {
          throw ProductLocalRepositoryException(
            'Enter a valid opening buying price',
          );
        }
        if (sellingPrice == null || sellingPrice < 0) {
          throw ProductLocalRepositoryException(
            'Enter a valid opening selling price',
          );
        }
        if (maxDiscount == null || maxDiscount < 0) {
          throw ProductLocalRepositoryException(
            'Enter a valid opening max discount',
          );
        }

        openingStock = StockRecord(
          barcode: _openingStockBarcodeController.text.trim(),
          product: _nameController.text.trim(),
          initialQty: openingQty,
          availableQty: openingQty,
          buyingPrice: buyingPrice,
          sellingPrice: sellingPrice,
          maxDiscount: maxDiscount,
          status: StockStatus.active,
          grnId: 'Not Assigned',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        ProductDialogResult(
          product: product,
          createdCategory: _createdCategory,
          openingStock: openingStock,
        ),
      );
    } catch (error) {
      AppToast.error('Failed to prepare product: $error');
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 760),
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
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8090A4),
                    ),
                  ),
                ],
              ),
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
                        focusNode: _categoryFocusNode,
                        suggestions: _categorySuggestions,
                        showSuggestions: _showCategorySuggestions,
                        isLoadingSuggestions: _isLoadingSuggestions,
                        shouldOfferCreate: _shouldOfferCreateCategory,
                        isCreatingCategory: _isCreatingCategory,
                        onChanged: (value) async {
                          setState(() => _showCategorySuggestions = true);
                          await _loadCategorySuggestions(value);
                        },
                        onTap: () async {
                          setState(() => _showCategorySuggestions = true);
                          await _loadCategorySuggestions(
                            _categoryController.text,
                          );
                        },
                        onSelectSuggestion: (category) {
                          setState(() {
                            _categoryController.text = category;
                            _showCategorySuggestions = false;
                          });
                        },
                        onCreateCategory: _createCategory,
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
                      if (!_isEditing) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _createOpeningStock = !_createOpeningStock;
                                    if (_createOpeningStock &&
                                        _openingStockBarcodeController.text
                                            .trim()
                                            .isEmpty) {
                                      _generateOpeningStockBarcode();
                                    }
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(42),
                                  side: BorderSide(
                                    color: _createOpeningStock
                                        ? const Color(0xFF36B4AE)
                                        : const Color(0xFFE0E7F0),
                                  ),
                                  foregroundColor: _createOpeningStock
                                      ? const Color(0xFF36B4AE)
                                      : const Color(0xFF344256),
                                ),
                                icon: Icon(
                                  _createOpeningStock
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.add_box_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _createOpeningStock
                                      ? 'Opening Stock Enabled'
                                      : 'Create Opening Stock',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_createOpeningStock) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FCFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFDCEEEB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Opening Stock Details',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334156),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _FormLabel('Stock Barcode *'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DialogTextField(
                                        controller:
                                            _openingStockBarcodeController,
                                        hintText: 'Enter stock barcode',
                                        prefixIcon: Icons.qr_code_2_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 40,
                                      child: ElevatedButton.icon(
                                        onPressed: _generateOpeningStockBarcode,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF36B4AE,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.qr_code_rounded,
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
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _FormLabel('Initial Quantity *'),
                                          const SizedBox(height: 8),
                                          _DialogTextField(
                                            controller:
                                                _openingStockQtyController,
                                            hintText: 'Enter quantity',
                                            keyboardType: TextInputType.number,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _FormLabel('Buying Price *'),
                                          const SizedBox(height: 8),
                                          _DialogTextField(
                                            controller:
                                                _openingStockBuyingPriceController,
                                            hintText: 'Enter buying price',
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _FormLabel('Selling Price *'),
                                          const SizedBox(height: 8),
                                          _DialogTextField(
                                            controller:
                                                _openingStockSellingPriceController,
                                            hintText: 'Enter selling price',
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _FormLabel('Max Discount *'),
                                          const SizedBox(height: 8),
                                          _DialogTextField(
                                            controller:
                                                _openingStockMaxDiscountController,
                                            hintText: 'Enter max discount',
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
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
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(140, 40),
                      backgroundColor: const Color(0xFF36B4AE),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
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
          Expanded(flex: 28, child: _HeaderText('Product Name')),
          Expanded(flex: 18, child: _HeaderText('Barcode')),
          Expanded(flex: 12, child: _HeaderText('Category')),
          Expanded(flex: 10, child: _HeaderText('Unit')),
          Expanded(flex: 10, child: _HeaderText('Low Stock')),
          Expanded(flex: 8, child: _HeaderText('Status')),
          Expanded(flex: 20, child: _HeaderText('Actions')),
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
    required this.isViewLoading,
    required this.isDeactivateLoading,
    required this.onView,
    required this.onEdit,
    required this.onDeactivate,
  });

  final ProductRecord product;
  final bool isHighlighted;
  final bool isViewLoading;
  final bool isDeactivateLoading;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final isActive = product.status == ProductStatus.active;

    return Container(
      color: isHighlighted ? const Color(0xFFF7FAFC) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 28,
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
            flex: 18,
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
            flex: 10,
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
            flex: 10,
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
            flex: 8,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE7FBF7)
                      : const Color(0xFFFCE8E8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  product.status.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? const Color(0xFF36B4AE)
                        : const Color(0xFFF56565),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: isViewLoading ? null : onView,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(62, 32),
                      side: const BorderSide(color: Color(0xFFE1E8F1)),
                      foregroundColor: const Color(0xFF445166),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: isViewLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_outlined, size: 14),
                    label: Text(
                      isViewLoading ? 'Loading' : 'View',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
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
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isDeactivateLoading ? null : onDeactivate,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(72, 32),
                      side: const BorderSide(color: Color(0xFFF1D2D2)),
                      foregroundColor: const Color(0xFFF56565),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: isDeactivateLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF56565),
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 14),
                    label: Text(
                      isDeactivateLoading ? 'Removing' : 'Delete',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
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

class ProductDetailsDialog extends StatefulWidget {
  const ProductDetailsDialog({
    super.key,
    required this.product,
    required this.stockRepository,
    required this.grnRepository,
  });

  final ProductRecord product;
  final StockRepository stockRepository;
  final GrnRepository grnRepository;

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> {
  List<StockRecord> _stocks = <StockRecord>[];
  bool _isLoadingStocks = true;
  String? _viewingStockKey;

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    setState(() => _isLoadingStocks = true);
    try {
      final allStocks = <StockRecord>[];
      var page = 1;
      var totalPages = 1;

      do {
        final result = await widget.stockRepository.fetchStocks(
          page: page,
          productQuery: widget.product.name,
          statusFilter: 'Active',
        );
        allStocks.addAll(
          result.stocks.where(
            (stock) =>
                stock.status == StockStatus.active &&
                stock.product.trim().toLowerCase() ==
                    widget.product.name.trim().toLowerCase(),
          ),
        );
        totalPages = result.totalPages;
        page += 1;
      } while (page <= totalPages);

      if (!mounted) {
        return;
      }
      setState(() {
        _stocks = allStocks;
        _isLoadingStocks = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stocks = <StockRecord>[];
        _isLoadingStocks = false;
      });
    }
  }

  Future<void> _showGrnDetails(String grnId) async {
    if (grnId.trim().isEmpty || grnId == 'Not Assigned') {
      AppToast.error('This stock item is not linked to a GRN');
      return;
    }
    final record = await widget.grnRepository.fetchGrnById(grnId);
    if (!mounted || record == null) {
      AppToast.error('GRN details not found');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _ReadOnlyGrnDetailsDialog(record: record),
    );
  }

  Future<void> _showStockDetails(StockRecord stock) async {
    final stockKey = stock.cloudId ?? '${stock.id ?? stock.barcode}';
    setState(() => _viewingStockKey = stockKey);
    try {
      final freshStock = await widget.stockRepository.fetchStockDetails(stock);
      if (!mounted) {
        return;
      }
      setState(() => _viewingStockKey = null);
      if (freshStock == null) {
        AppToast.error('Stock details not found');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => StockDetailsDialog(
          stock: freshStock,
          onViewGrn: () => _showGrnDetails(freshStock.grnId),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _viewingStockKey = null);
      AppToast.error('Failed to load stock details: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isActive = product.status == ProductStatus.active;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 820,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 16),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ProductInfoTile(
                          label: 'Product Name',
                          value: product.name,
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProductInfoTile(
                          label: 'Barcode',
                          value: product.barcode,
                          icon: Icons.qr_code_2_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ProductInfoTile(
                          label: 'Category',
                          value: product.category,
                          icon: Icons.sell_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProductInfoTile(
                          label: 'Unit',
                          value: product.unit,
                          icon: Icons.straighten_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ProductInfoTile(
                          label: 'Low Stock Quantity',
                          value: '${product.lowStock}',
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProductInfoTile(
                          label: 'Status',
                          value: product.status.label,
                          icon: isActive
                              ? Icons.check_circle_outline_rounded
                              : Icons.block_outlined,
                          valueColor: isActive
                              ? const Color(0xFF36B4AE)
                              : const Color(0xFFF56565),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Active Stocks',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334156),
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
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 26, child: _HeaderText('Barcode')),
                              Expanded(flex: 12, child: _HeaderText('Qty')),
                              Expanded(flex: 16, child: _HeaderText('Buying')),
                              Expanded(flex: 16, child: _HeaderText('Selling')),
                              Expanded(flex: 14, child: _HeaderText('GRN')),
                              Expanded(flex: 16, child: _HeaderText('Actions')),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEFF3F8)),
                        if (_isLoadingStocks)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              color: Color(0xFF36B4AE),
                            ),
                          )
                        else if (_stocks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No active stocks found for this product',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8A98AD),
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _stocks.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: Color(0xFFF0F4F8),
                              ),
                              itemBuilder: (context, index) {
                                final stock = _stocks[index];
                                final stockKey =
                                    stock.cloudId ??
                                    '${stock.id ?? stock.barcode}';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 26,
                                        child: Text(
                                          stock.barcode,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF526177),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 12,
                                        child: Text(
                                          '${stock.availableQty}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF445166),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 16,
                                        child: Text(
                                          'Rs ${stock.buyingPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF7E8CA1),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 16,
                                        child: Text(
                                          'Rs ${stock.sellingPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF36B4AE),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 14,
                                        child: Text(
                                          stock.grnId,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF7E8CA1),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 16,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                _viewingStockKey == stockKey
                                                ? null
                                                : () =>
                                                      _showStockDetails(stock),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(60, 32),
                                              side: const BorderSide(
                                                color: Color(0xFFE1E8F1),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            icon: _viewingStockKey == stockKey
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 14,
                                                  ),
                                            label: Text(
                                              _viewingStockKey == stockKey
                                                  ? 'Loading'
                                                  : 'View',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
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
                      ],
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

class _ProductInfoTile extends StatelessWidget {
  const _ProductInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor = const Color(0xFF334156),
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF8A98AD)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A98AD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyGrnDetailsDialog extends StatelessWidget {
  const _ReadOnlyGrnDetailsDialog({required this.record});

  final GrnRecord record;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 720,
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
                        child: _ProductInfoTile(
                          label: 'Supplier',
                          value: record.supplier,
                          icon: Icons.local_shipping_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProductInfoTile(
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
                        child: _ProductInfoTile(
                          label: 'Sub Total',
                          value: 'Rs ${record.subTotal.toStringAsFixed(2)}',
                          icon: Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProductInfoTile(
                          label: 'Due Amount',
                          value: 'Rs ${record.dueAmount.toStringAsFixed(2)}',
                          icon: Icons.warning_amber_rounded,
                          valueColor: record.dueAmount > 0
                              ? const Color(0xFFF56565)
                              : const Color(0xFF36B4AE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8EDF4)),
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 30, child: _HeaderText('Product')),
                              Expanded(flex: 12, child: _HeaderText('Qty')),
                              Expanded(flex: 18, child: _HeaderText('Buying')),
                              Expanded(flex: 18, child: _HeaderText('Selling')),
                              Expanded(flex: 22, child: _HeaderText('Status')),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEFF3F8)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: record.items.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: Color(0xFFF0F4F8),
                            ),
                            itemBuilder: (context, index) {
                              final item = record.items[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 30,
                                      child: Text(
                                        item.product,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF526177),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 12,
                                      child: Text('${item.quantity}'),
                                    ),
                                    Expanded(
                                      flex: 18,
                                      child: Text(
                                        'Rs ${item.buyingPrice.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 18,
                                      child: Text(
                                        'Rs ${item.sellingPrice.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 22,
                                      child: Text(
                                        item.inStock ? 'In Stock' : 'Pending',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: item.inStock
                                              ? const Color(0xFF36B4AE)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
    );
  }
}

class _CategoryAutocompleteField extends StatelessWidget {
  const _CategoryAutocompleteField({
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.showSuggestions,
    required this.isLoadingSuggestions,
    required this.shouldOfferCreate,
    required this.isCreatingCategory,
    required this.onChanged,
    required this.onTap,
    required this.onSelectSuggestion,
    required this.onCreateCategory,
    required this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> suggestions;
  final bool showSuggestions;
  final bool isLoadingSuggestions;
  final bool shouldOfferCreate;
  final bool isCreatingCategory;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onTap;
  final ValueChanged<String> onSelectSuggestion;
  final Future<void> Function() onCreateCategory;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final trimmedValue = controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogTextField(
          controller: controller,
          focusNode: focusNode,
          hintText: 'Select or create category',
          prefixIcon: Icons.label_outline_rounded,
          onChanged: onChanged,
          onTap: onTap,
          validator: validator,
        ),
        if (showSuggestions &&
            (isLoadingSuggestions ||
                suggestions.isNotEmpty ||
                shouldOfferCreate)) ...[
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
                if (isLoadingSuggestions)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF36B4AE),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Loading categories...',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8190A5),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    onTap: isCreatingCategory ? null : onCreateCategory,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Text(
                        isCreatingCategory
                            ? 'Creating category...'
                            : '+ Create "$trimmedValue"',
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
    this.focusNode,
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.onTap,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Future<void> Function()? onTap;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap == null ? null : () => onTap!.call(),
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

class _ProductTableSkeleton extends StatelessWidget {
  const _ProductTableSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFF0F4F8)),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(flex: 33, child: _SkeletonBlock(widthFactor: 0.9)),
              SizedBox(width: 12),
              Expanded(flex: 21, child: _SkeletonBlock(widthFactor: 0.8)),
              SizedBox(width: 12),
              Expanded(flex: 12, child: _SkeletonBlock(widthFactor: 0.7)),
              SizedBox(width: 12),
              Expanded(flex: 12, child: _SkeletonBlock(widthFactor: 0.65)),
              SizedBox(width: 12),
              Expanded(flex: 12, child: _SkeletonBlock(widthFactor: 0.45)),
              SizedBox(width: 12),
              Expanded(flex: 10, child: _SkeletonBlock(widthFactor: 0.6)),
              SizedBox(width: 12),
              Expanded(flex: 12, child: _SkeletonBlock(widthFactor: 0.7)),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.widthFactor});

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

enum ProductFilter {
  name('By Name', Icons.inventory_2_outlined),
  category('By Category', Icons.label_outline_rounded),
  barcode('By Barcode', Icons.view_stream_rounded);

  const ProductFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}
