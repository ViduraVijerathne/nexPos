import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../data/pos_local_repository.dart';
import '../../models/models.dart';

enum PosPaymentMethod { cash, card, upi }

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  static const double _taxRate = 0.10;

  final PosLocalRepository _repository = const PosLocalRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _customerFocusNode = FocusNode();

  Timer? _searchDebounce;
  Timer? _customerDebounce;

  List<String> _categories = const <String>['All'];
  List<PosCatalogItem> _catalogItems = <PosCatalogItem>[];
  List<PosCustomerOption> _customerSuggestions = <PosCustomerOption>[];
  final List<PosCartItem> _cartItems = <PosCartItem>[];

  String _selectedCategory = 'All';
  PosPaymentMethod _selectedPaymentMethod = PosPaymentMethod.cash;
  PosCustomerOption _selectedCustomer = PosLocalRepository.walkInCustomer;
  int? _selectedStockId;
  bool _showCustomerSuggestions = false;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _customerController.text = _selectedCustomer.searchLabel;
    _initializePage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _customerDebounce?.cancel();
    _searchController.dispose();
    _customerController.dispose();
    _amountController.dispose();
    _searchFocusNode.dispose();
    _customerFocusNode.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _cartItems.fold<double>(0, (sum, item) => sum + item.subtotal);
  double get _tax => _subtotal * _taxRate;
  double get _total => _subtotal + _tax;
  double get _amountPaid => double.tryParse(_amountController.text.trim()) ?? 0;
  double get _balance => _amountPaid - _total;
  bool get _canProcessPayment =>
      !_isProcessing && _cartItems.isNotEmpty && _amountPaid >= _total;

  Future<void> _initializePage() async {
    try {
      await _repository.initialize();
      await _loadCatalog();
      await _loadCustomers();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load POS data: $error');
    }
  }

  Future<void> _loadCatalog() async {
    final result = await _repository.fetchCatalog(
      searchQuery: _searchController.text.trim(),
      category: _selectedCategory,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = result.categories;
      if (!_categories.contains(_selectedCategory)) {
        _selectedCategory = 'All';
      }
      _catalogItems = result.items;
      _isLoading = false;
    });
  }

  Future<void> _loadCustomers() async {
    final customers = await _repository.searchCustomers(
      _customerController.text == PosLocalRepository.walkInCustomer.searchLabel
          ? ''
          : _customerController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _customerSuggestions = customers;
    });
  }

  void _handleSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), _loadCatalog);
  }

  void _handleCustomerChanged(String value) {
    setState(() {
      _showCustomerSuggestions = true;
      if (value.trim().isEmpty) {
        _selectedCustomer = PosLocalRepository.walkInCustomer;
      }
    });

    _customerDebounce?.cancel();
    _customerDebounce = Timer(
      const Duration(milliseconds: 180),
      _loadCustomers,
    );
  }

  Future<void> _handleSearchSubmitted(String value) async {
    final exactMatch = await _repository.findExactCatalogMatch(value);
    if (exactMatch == null) {
      return;
    }

    _addCatalogItemToCart(exactMatch);
  }

  void _selectCustomer(PosCustomerOption customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerController.text = customer.searchLabel;
      _showCustomerSuggestions = false;
    });
  }

  void _resetToWalkInCustomer() {
    setState(() {
      _selectedCustomer = PosLocalRepository.walkInCustomer;
      _customerController.text = _selectedCustomer.searchLabel;
      _showCustomerSuggestions = false;
    });
  }

  void _addCatalogItemToCart(PosCatalogItem item) {
    final existingIndex = _cartItems.indexWhere(
      (cartItem) => cartItem.stockId == item.stockId,
    );

    if (existingIndex >= 0) {
      final existingItem = _cartItems[existingIndex];
      if (existingItem.quantity >= item.availableQty) {
        AppToast.error('No more quantity available for ${item.productName}');
        return;
      }

      setState(() {
        _cartItems[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
          availableQty: item.availableQty,
        );
        _selectedStockId = item.stockId;
        _searchController.clear();
      });
    } else {
      setState(() {
        _cartItems.insert(
          0,
          PosCartItem(
            stockId: item.stockId,
            stockBarcode: item.stockBarcode,
            productBarcode: item.productBarcode,
            productName: item.productName,
            category: item.category,
            unitPrice: item.sellingPrice,
            availableQty: item.availableQty,
            quantity: 1,
          ),
        );
        _selectedStockId = item.stockId;
        _searchController.clear();
      });
    }

    _loadCatalog();
    _searchFocusNode.requestFocus();
  }

  void _changeCartQuantity(PosCartItem item, int delta) {
    final index = _cartItems.indexWhere(
      (cartItem) => cartItem.stockId == item.stockId,
    );
    if (index < 0) {
      return;
    }

    final updatedQuantity = item.quantity + delta;
    if (updatedQuantity <= 0) {
      setState(() {
        _cartItems.removeAt(index);
      });
      return;
    }

    if (updatedQuantity > item.availableQty) {
      AppToast.error('No more quantity available for ${item.productName}');
      return;
    }

    setState(() {
      _cartItems[index] = item.copyWith(quantity: updatedQuantity);
      _selectedStockId = item.stockId;
    });
  }

  void _removeCartItem(PosCartItem item) {
    setState(() {
      _cartItems.removeWhere((cartItem) => cartItem.stockId == item.stockId);
    });
    _searchFocusNode.requestFocus();
  }

  void _startNewTransaction() {
    setState(() {
      _cartItems.clear();
      _amountController.clear();
      _searchController.clear();
      _selectedCategory = 'All';
      _selectedPaymentMethod = PosPaymentMethod.cash;
      _selectedStockId = null;
    });
    _resetToWalkInCustomer();
    _loadCatalog();
    _searchFocusNode.requestFocus();
    AppToast.success('New transaction started');
  }

  Future<void> _processPayment() async {
    if (!_canProcessPayment) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await _repository.processSale(
        items: _cartItems,
        customer: _selectedCustomer,
        paymentMethod: _selectedPaymentMethod.label,
        amountPaid: _amountPaid,
        cashierName: 'Admin User',
      );

      if (!mounted) {
        return;
      }

      AppToast.success(
        'Payment processed successfully. Invoice ${result.invoiceNumber}',
      );

      setState(() {
        _cartItems.clear();
        _amountController.clear();
        _searchController.clear();
        _selectedCategory = 'All';
        _selectedPaymentMethod = PosPaymentMethod.cash;
        _selectedStockId = null;
        _isProcessing = false;
      });
      _resetToWalkInCustomer();
      await _loadCatalog();
      _searchFocusNode.requestFocus();
    } on PosLocalRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      AppToast.error(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      AppToast.error('Failed to process payment: $error');
    }
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
              const Expanded(child: _PosHeader()),
              const SizedBox(width: 16),
              _PrimaryActionButton(
                label: 'New Transaction',
                icon: Icons.add,
                onPressed: _startNewTransaction,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _ProductsPanel(
                          searchController: _searchController,
                          searchFocusNode: _searchFocusNode,
                          categories: _categories,
                          selectedCategory: _selectedCategory,
                          products: _catalogItems,
                          selectedStockId: _selectedStockId,
                          onSearchChanged: _handleSearchChanged,
                          onSearchSubmitted: _handleSearchSubmitted,
                          onCategorySelected: (category) {
                            setState(() => _selectedCategory = category);
                            _loadCatalog();
                            _searchFocusNode.requestFocus();
                          },
                          onProductSelected: _addCatalogItemToCart,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 372,
                        child: _CurrentOrderPanel(
                          items: _cartItems,
                          customerController: _customerController,
                          customerFocusNode: _customerFocusNode,
                          customerSuggestions: _customerSuggestions,
                          showCustomerSuggestions: _showCustomerSuggestions,
                          selectedCustomer: _selectedCustomer,
                          amountController: _amountController,
                          selectedPaymentMethod: _selectedPaymentMethod,
                          subtotal: _subtotal,
                          tax: _tax,
                          total: _total,
                          balance: _balance,
                          canProcessPayment: _canProcessPayment,
                          isProcessing: _isProcessing,
                          onPaymentMethodChanged: (method) {
                            setState(() => _selectedPaymentMethod = method);
                          },
                          onAmountChanged: (_) => setState(() {}),
                          onCustomerChanged: _handleCustomerChanged,
                          onCustomerTapped: () {
                            setState(() => _showCustomerSuggestions = true);
                          },
                          onCustomerSelected: _selectCustomer,
                          onResetCustomer: _resetToWalkInCustomer,
                          onIncreaseQuantity: (item) =>
                              _changeCartQuantity(item, 1),
                          onDecreaseQuantity: (item) =>
                              _changeCartQuantity(item, -1),
                          onRemoveItem: _removeCartItem,
                          onProcessPayment: _processPayment,
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

extension on PosPaymentMethod {
  String get label {
    switch (this) {
      case PosPaymentMethod.cash:
        return 'Cash';
      case PosPaymentMethod.card:
        return 'Card';
      case PosPaymentMethod.upi:
        return 'UPI';
    }
  }
}

class _PosHeader extends StatelessWidget {
  const _PosHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Point of Sale',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334156),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Process customer transactions and manage orders.',
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

class _ProductsPanel extends StatelessWidget {
  const _ProductsPanel({
    required this.searchController,
    required this.searchFocusNode,
    required this.categories,
    required this.selectedCategory,
    required this.products,
    required this.selectedStockId,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onCategorySelected,
    required this.onProductSelected,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<String> categories;
  final String selectedCategory;
  final List<PosCatalogItem> products;
  final int? selectedStockId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<PosCatalogItem> onProductSelected;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Products',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374457),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText:
                    'Search by product, product barcode, or stock barcode...',
                hintStyle: const TextStyle(
                  color: Color(0xFFA2AEBD),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF9CACBE),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 74),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                fillColor: const Color(0xFFFFFFFF),
                filled: true,
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
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryChip(
                  label: category,
                  isSelected: category == selectedCategory,
                  onTap: () => onCategorySelected(category),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      'No available stock found',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF93A0B2),
                      ),
                    ),
                  )
                : GridView.builder(
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.02,
                        ),
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return _ProductCard(
                        product: product,
                        isSelected: product.stockId == selectedStockId,
                        onTap: () => onProductSelected(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CurrentOrderPanel extends StatelessWidget {
  const _CurrentOrderPanel({
    required this.items,
    required this.customerController,
    required this.customerFocusNode,
    required this.customerSuggestions,
    required this.showCustomerSuggestions,
    required this.selectedCustomer,
    required this.amountController,
    required this.selectedPaymentMethod,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.balance,
    required this.canProcessPayment,
    required this.isProcessing,
    required this.onPaymentMethodChanged,
    required this.onAmountChanged,
    required this.onCustomerChanged,
    required this.onCustomerTapped,
    required this.onCustomerSelected,
    required this.onResetCustomer,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onRemoveItem,
    required this.onProcessPayment,
  });

  final List<PosCartItem> items;
  final TextEditingController customerController;
  final FocusNode customerFocusNode;
  final List<PosCustomerOption> customerSuggestions;
  final bool showCustomerSuggestions;
  final PosCustomerOption selectedCustomer;
  final TextEditingController amountController;
  final PosPaymentMethod selectedPaymentMethod;
  final double subtotal;
  final double tax;
  final double total;
  final double balance;
  final bool canProcessPayment;
  final bool isProcessing;
  final ValueChanged<PosPaymentMethod> onPaymentMethodChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCustomerTapped;
  final ValueChanged<String> onCustomerChanged;
  final ValueChanged<PosCustomerOption> onCustomerSelected;
  final VoidCallback onResetCustomer;
  final ValueChanged<PosCartItem> onIncreaseQuantity;
  final ValueChanged<PosCartItem> onDecreaseQuantity;
  final ValueChanged<PosCartItem> onRemoveItem;
  final VoidCallback onProcessPayment;

  @override
  Widget build(BuildContext context) {
    final hasShortPayment = items.isNotEmpty && balance < 0;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Order',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374457),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Scan or click a stock item to start billing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF93A0B2),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _OrderLineItem(
                        item: item,
                        onIncrease: () => onIncreaseQuantity(item),
                        onDecrease: () => onDecreaseQuantity(item),
                        onRemove: () => onRemoveItem(item),
                      );
                    },
                  ),
          ),
          const Divider(color: Color(0xFFEDF2F7), height: 18),
          const Text(
            'Customer',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A586B),
            ),
          ),
          const SizedBox(height: 10),
          _CustomerSearchField(
            controller: customerController,
            focusNode: customerFocusNode,
            onChanged: onCustomerChanged,
            onTap: onCustomerTapped,
          ),
          if (showCustomerSuggestions && customerSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CustomerSuggestionList(
              customers: customerSuggestions,
              onSelected: onCustomerSelected,
            ),
          ],
          const SizedBox(height: 10),
          _SelectedCustomerCard(
            customer: selectedCustomer,
            onClear: onResetCustomer,
          ),
          const SizedBox(height: 18),
          _SummaryRow(
            label: 'Subtotal',
            value: 'Rs ${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Tax (10%)',
            value: 'Rs ${tax.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDF2F7), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF344256),
                ),
              ),
              const Spacer(),
              Text(
                'Rs ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF41C0BC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A586B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodButton(
                  label: 'Cash',
                  icon: Icons.receipt_long_outlined,
                  isSelected: selectedPaymentMethod == PosPaymentMethod.cash,
                  onTap: () => onPaymentMethodChanged(PosPaymentMethod.cash),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaymentMethodButton(
                  label: 'Card',
                  icon: Icons.credit_card_outlined,
                  isSelected: selectedPaymentMethod == PosPaymentMethod.card,
                  onTap: () => onPaymentMethodChanged(PosPaymentMethod.card),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaymentMethodButton(
                  label: 'UPI',
                  icon: Icons.account_balance_wallet_outlined,
                  isSelected: selectedPaymentMethod == PosPaymentMethod.upi,
                  onTap: () => onPaymentMethodChanged(PosPaymentMethod.upi),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Amount Paid',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A586B),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: onAmountChanged,
              decoration: InputDecoration(
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 8, right: 2),
                  child: Icon(
                    Icons.attach_money_rounded,
                    size: 16,
                    color: Color(0xFF78889E),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF36B4AE)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: hasShortPayment
                  ? const Color(0xFFFFEFEF)
                  : const Color(0xFFD8F5F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasShortPayment
                    ? const Color(0xFFF2B5B5)
                    : const Color(0xFF7ED9D3),
              ),
            ),
            child: Row(
              children: [
                Text(
                  hasShortPayment ? 'Balance Due' : 'Change to Return',
                  style: const TextStyle(
                    color: Color(0xFF4A586B),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs ${balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: hasShortPayment
                        ? const Color(0xFFEA5A5A)
                        : const Color(0xFF36B4AE),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: canProcessPayment ? onProcessPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF36B4AE),
                disabledBackgroundColor: const Color(0xFF9ADCD8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.credit_card_rounded, size: 16),
              label: Text(
                isProcessing ? 'Processing...' : 'Process Payment',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
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
                : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : const Color(0xFF58677D),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final PosCatalogItem product;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF54D2CC)
                : const Color(0xFFE7EDF5),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1436B4AE),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 34,
                    color: Color(0xFFCBD6E4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF465366),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Stock: ${product.availableQty}  •  ${product.stockBarcode}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF96A3B6),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              product.productBarcode.isEmpty
                  ? product.category
                  : '${product.category} • ${product.productBarcode}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF96A3B6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs ${product.sellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF36B4AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderLineItem extends StatelessWidget {
  const _OrderLineItem({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final PosCartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF465366),
                  ),
                ),
              ),
              InkWell(
                onTap: onRemove,
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFB6A6A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.stockBarcode} • Available ${item.availableQty}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF93A0B2),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: onDecrease),
              Container(
                width: 38,
                height: 30,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF465366),
                  ),
                ),
              ),
              _QtyButton(icon: Icons.add, onTap: onIncrease),
              const SizedBox(width: 10),
              Text(
                'x Rs ${item.unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF93A0B2),
                ),
              ),
              const Spacer(),
              Text(
                'Rs ${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF36B4AE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchField extends StatelessWidget {
  const _CustomerSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: 'Search customer by name or mobile...',
          hintStyle: const TextStyle(
            color: Color(0xFF9BA8B9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.person_outline_rounded,
            size: 17,
            color: Color(0xFF7D8BA0),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1E8F1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE1E8F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF36B4AE)),
          ),
        ),
      ),
    );
  }
}

class _CustomerSuggestionList extends StatelessWidget {
  const _CustomerSuggestionList({
    required this.customers,
    required this.onSelected,
  });

  final List<PosCustomerOption> customers;
  final ValueChanged<PosCustomerOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: customers
            .map(
              (customer) => InkWell(
                onTap: () => onSelected(customer),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: Color(0xFF7B8AA0),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF465366),
                              ),
                            ),
                            Text(
                              customer.phone,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF93A0B2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  const _SelectedCustomerCard({required this.customer, required this.onClear});

  final PosCustomerOption customer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F5F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF65D4CC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: Color(0xFF37AFA9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    color: Color(0xFF465366),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  customer.phone,
                  style: const TextStyle(
                    color: Color(0xFF6B7A8F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!customer.isWalkIn)
            InkWell(
              onTap: onClear,
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: Color(0xFFFB6A6A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF526275),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A879A),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF36B4AE) : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF36B4AE)
                : const Color(0xFFE1E8F1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.white : const Color(0xFF627086),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.white : const Color(0xFF556479),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F9FC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1E8F1)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF5B6A7F)),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
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
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF36B4AE),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
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

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
