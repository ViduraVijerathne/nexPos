import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/day_session_print_service.dart';
import '../../../../core/services/invoice_print_service.dart';
import '../../../../core/services/kot_print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/widgets/app_date_field.dart';
import '../../../../core/widgets/adaptive_data_layout.dart';
import '../../../../core/widgets/invoice_preview.dart';
import '../../data/customer_local_repository.dart';
import '../../data/customer_remote_repository.dart';
import '../../data/customer_repository.dart';
import '../../data/customer_repository_factory.dart';
import '../../data/expense_local_repository.dart';
import '../../data/expense_remote_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/expense_repository_factory.dart';
import '../../data/invoice_local_repository.dart';
import '../../data/invoice_remote_repository.dart';
import '../../data/invoice_repository.dart';
import '../../data/invoice_repository_factory.dart';
import '../../data/pos_local_repository.dart';
import '../../data/pos_remote_repository.dart';
import '../../data/pos_repository.dart';
import '../../data/sale_validation.dart';
import '../../data/pos_repository_factory.dart';
import '../../models/models.dart';
import '../../services/day_session_service.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';
import 'invoice_page.dart';
import 'package:printing/printing.dart';

enum PosPaymentMethod { cash, card, multiple }

enum PosPricingGroup { retail, wholesale }

class PosPage extends StatefulWidget {
  const PosPage({
    super.key,
    this.repository,
    this.customerRepository,
    this.invoiceRepository,
    this.expenseRepository,
  });
  final PosRepository? repository;
  final CustomerRepository? customerRepository;
  final InvoiceRepository? invoiceRepository;
  final ExpenseRepository? expenseRepository;

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  PosRepository? _repository;
  CustomerRepository? _customerRepository;
  InvoiceRepository? _invoiceRepository;
  ExpenseRepository? _expenseRepository;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _customerFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _cardAmountFocusNode = FocusNode();
  final FocusNode _discountFocusNode = FocusNode();

  Timer? _searchDebounce;
  Timer? _customerDebounce;

  List<String> _categories = const <String>['All'];
  List<PosCatalogItem> _catalogItems = <PosCatalogItem>[];
  List<PosCustomerOption> _customerSuggestions = <PosCustomerOption>[];
  final List<PosCartItem> _cartItems = <PosCartItem>[];

  String _selectedCategory = 'All';
  PosPaymentMethod _selectedPaymentMethod = PosPaymentMethod.cash;
  PosPricingGroup _selectedPricingGroup = PosPricingGroup.retail;
  PosCustomerOption _selectedCustomer = PosLocalRepository.walkInCustomer;
  String? _selectedStockKey;
  bool _showCustomerSuggestions = false;
  bool _isLoading = true;
  bool _isCatalogLoading = false;
  bool _isCustomerLoading = false;
  bool _isProcessing = false;
  bool _isOpeningCustomerDialog = false;
  bool _isRecentInvoicesLoading = false;
  bool _isDaySessionLoading = false;
  bool _isSavingQuickExpense = false;
  String? _viewingInvoiceId;
  String? _printingInvoiceId;
  PosTaxSettings _taxSettings = const PosTaxSettings(
    isTaxEnabled: false,
    taxPercent: 10,
  );
  PosCustomerSettings _customerSettings = const PosCustomerSettings(
    createCustomerOnlyContact: false,
  );
  PosCatalogSettings _catalogSettings = const PosCatalogSettings(
    defaultLoadMode: PosCatalogLoadMode.defaultOrder,
    defaultViewMode: PosCatalogViewMode.row,
  );
  PosShortcutSettings _shortcutSettings = PosShortcutSettings.defaults;
  bool _touchModeEnabled = false;
  bool _printReceipt = true;
  int _catalogRequest = 0;
  int _customerRequest = 0;
  DrawerSessionState _drawerSession = const DrawerSessionState.inactive();

  @override
  void initState() {
    super.initState();
    _customerController.text = _selectedCustomer.searchLabel;
    AppSettingsService.instance.posSettingsVersionNotifier.addListener(
      _handlePosSettingsChanged,
    );
    AppSettingsService.instance.touchModeNotifier.addListener(
      _handleTouchModeChanged,
    );
    DaySessionService.instance.sessionVersionNotifier.addListener(
      _handleDaySessionChanged,
    );
    _searchFocusNode.addListener(_handleActiveInputFocusChange);
    _amountFocusNode.addListener(_handleActiveInputFocusChange);
    _cardAmountFocusNode.addListener(_handleActiveInputFocusChange);
    _discountFocusNode.addListener(_handleActiveInputFocusChange);
    _initializePage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _customerDebounce?.cancel();
    AppSettingsService.instance.posSettingsVersionNotifier.removeListener(
      _handlePosSettingsChanged,
    );
    AppSettingsService.instance.touchModeNotifier.removeListener(
      _handleTouchModeChanged,
    );
    DaySessionService.instance.sessionVersionNotifier.removeListener(
      _handleDaySessionChanged,
    );
    _searchFocusNode.removeListener(_handleActiveInputFocusChange);
    _amountFocusNode.removeListener(_handleActiveInputFocusChange);
    _cardAmountFocusNode.removeListener(_handleActiveInputFocusChange);
    _discountFocusNode.removeListener(_handleActiveInputFocusChange);
    _searchController.dispose();
    _customerController.dispose();
    _amountController.dispose();
    _discountController.dispose();
    _cardAmountController.dispose();
    _searchFocusNode.dispose();
    _customerFocusNode.dispose();
    _amountFocusNode.dispose();
    _cardAmountFocusNode.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _cartItems.fold<double>(0, (sum, item) => sum + item.subtotal);
  double get _discount =>
      (double.tryParse(_discountController.text.trim()) ?? 0)
          .clamp(0, _subtotal)
          .toDouble();
  double get _discountedSubtotal =>
      (_subtotal - _discount).clamp(0, double.infinity).toDouble();
  double get _tax => _taxSettings.isTaxEnabled
      ? _discountedSubtotal * _taxSettings.taxRate
      : 0;
  double get _total => roundMoney(_discountedSubtotal + _tax);
  double get _enteredCashAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0;
  double get _enteredCardAmount =>
      double.tryParse(_cardAmountController.text.trim()) ?? 0;
  double get _cashPaidAmount => switch (_selectedPaymentMethod) {
    PosPaymentMethod.cash => _enteredCashAmount,
    PosPaymentMethod.card => 0,
    PosPaymentMethod.multiple => _enteredCashAmount,
  };
  double get _cardPaidAmount => switch (_selectedPaymentMethod) {
    PosPaymentMethod.cash => 0,
    PosPaymentMethod.card => _total,
    PosPaymentMethod.multiple => _enteredCardAmount,
  };
  double get _amountPaid => _cashPaidAmount + _cardPaidAmount;
  double get _balance => _amountPaid - _total;
  List<PosCatalogItem> get _visibleCatalogItems {
    return _catalogItems
        .map((item) {
          final inCartQty = _cartItems
              .where((cartItem) => cartItem.stockKey == item.stockKey)
              .fold<int>(0, (sum, cartItem) => sum + cartItem.quantity);
          final remainingQty = item.availableQty - inCartQty;
          return PosCatalogItem(
            stockId: item.stockId,
            stockCloudId: item.stockCloudId,
            stockBarcode: item.stockBarcode,
            productName: item.productName,
            productBarcode: item.productBarcode,
            category: item.category,
            availableQty: remainingQty,
            retailPrice: item.retailPrice,
            wholesalePrice: item.wholesalePrice,
          );
        })
        .where((item) => item.availableQty > 0)
        .toList();
  }

  bool get _canProcessPayment =>
      !_isProcessing &&
      !_isOpeningCustomerDialog &&
      validateSaleInput(
            items: _cartItems,
            amountPaid: _amountPaid,
            cashPaidAmount: _cashPaidAmount,
            cardPaidAmount: _cardPaidAmount,
            discountAmount: _discount,
            taxAmount: _tax,
          ) ==
          null;

  String? _pickSelectableStockKey({String? preferred}) {
    final items = _visibleCatalogItems;
    if (items.isEmpty) {
      return null;
    }

    if (preferred != null && items.any((item) => item.stockKey == preferred)) {
      return preferred;
    }

    if (_selectedStockKey != null &&
        items.any((item) => item.stockKey == _selectedStockKey)) {
      return _selectedStockKey;
    }

    return items.first.stockKey;
  }

  PosCatalogItem? _adjustCatalogItemForCart(PosCatalogItem item) {
    final inCartQty = _cartItems
        .where((cartItem) => cartItem.stockKey == item.stockKey)
        .fold<int>(0, (sum, cartItem) => sum + cartItem.quantity);
    final remainingQty = item.availableQty - inCartQty;
    if (remainingQty <= 0) {
      return null;
    }

    return PosCatalogItem(
      stockId: item.stockId,
      stockCloudId: item.stockCloudId,
      stockBarcode: item.stockBarcode,
      productName: item.productName,
      productBarcode: item.productBarcode,
      category: item.category,
      availableQty: remainingQty,
      retailPrice: item.retailPrice,
      wholesalePrice: item.wholesalePrice,
    );
  }

  double _catalogPriceForGroup(PosCatalogItem item) {
    return switch (_selectedPricingGroup) {
      PosPricingGroup.retail => item.retailPrice,
      PosPricingGroup.wholesale => item.wholesalePrice,
    };
  }

  double _cartPriceForGroup(PosCartItem item) {
    return switch (_selectedPricingGroup) {
      PosPricingGroup.retail => item.retailPrice,
      PosPricingGroup.wholesale => item.wholesalePrice,
    };
  }

  void _applyPricingGroup(PosPricingGroup group) {
    setState(() {
      _selectedPricingGroup = group;
      for (var index = 0; index < _cartItems.length; index += 1) {
        final item = _cartItems[index];
        _cartItems[index] = item.copyWith(unitPrice: _cartPriceForGroup(item));
      }
    });
    _searchFocusNode.requestFocus();
  }

  void _moveCatalogSelection(int delta) {
    final items = _visibleCatalogItems;
    if (items.isEmpty) {
      return;
    }

    final currentIndex = items.indexWhere(
      (item) => item.stockKey == _selectedStockKey,
    );
    final targetIndex = currentIndex < 0
        ? (delta > 0 ? 0 : items.length - 1)
        : (currentIndex + delta).clamp(0, items.length - 1);

    setState(() {
      _selectedStockKey = items[targetIndex].stockKey;
    });
  }

  Future<void> _handlePosSettingsChanged() async {
    final taxSettings = await AppSettingsService.instance.loadPosTaxSettings();
    final customerSettings = await AppSettingsService.instance
        .loadPosCustomerSettings();
    final catalogSettings = await AppSettingsService.instance
        .loadPosCatalogSettings();
    final printSettings = await AppSettingsService.instance
        .loadPosPrintSettings();
    final shortcutSettings = await AppSettingsService.instance
        .loadPosShortcutSettings();
    final touchSettings = await AppSettingsService.instance
        .loadTouchUiSettings();
    final drawerSession = await DaySessionService.instance.loadState();

    if (!mounted) {
      return;
    }

    setState(() {
      _taxSettings = taxSettings;
      _customerSettings = customerSettings;
      _catalogSettings = catalogSettings;
      _printReceipt =
          printSettings.invoicePrintMode != PosInvoicePrintMode.none;
      _shortcutSettings = shortcutSettings;
      _touchModeEnabled = touchSettings.isEnabled;
      _drawerSession = drawerSession;
    });

    _focusDefaultTouchFieldIfNeeded();
    await _loadCatalog();
  }

  void _handleTouchModeChanged() {
    if (!mounted) {
      return;
    }
    final enabled = AppSettingsService.instance.touchModeNotifier.value;
    setState(() => _touchModeEnabled = enabled);
    _focusDefaultTouchFieldIfNeeded();
  }

  Future<void> _handleDaySessionChanged() async {
    final state = await DaySessionService.instance.loadState();
    if (!mounted) {
      return;
    }
    setState(() => _drawerSession = state);
  }

  void _handleActiveInputFocusChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _initializePage() async {
    try {
      final repository =
          widget.repository ?? await PosRepositoryFactory.create();
      final customerRepository =
          widget.customerRepository ?? await CustomerRepositoryFactory.create();
      final invoiceRepository =
          widget.invoiceRepository ?? await InvoiceRepositoryFactory.create();
      final expenseRepository =
          widget.expenseRepository ?? await ExpenseRepositoryFactory.create();
      await repository.initialize();
      await customerRepository.initialize();
      await invoiceRepository.initialize();
      await expenseRepository.initialize();
      _repository = repository;
      _customerRepository = customerRepository;
      _invoiceRepository = invoiceRepository;
      _expenseRepository = expenseRepository;
      final taxSettings = await AppSettingsService.instance
          .loadPosTaxSettings();
      final customerSettings = await AppSettingsService.instance
          .loadPosCustomerSettings();
      final catalogSettings = await AppSettingsService.instance
          .loadPosCatalogSettings();
      final printSettings = await AppSettingsService.instance
          .loadPosPrintSettings();
      final shortcutSettings = await AppSettingsService.instance
          .loadPosShortcutSettings();
      final touchSettings = await AppSettingsService.instance
          .loadTouchUiSettings();
      final drawerSession = await DaySessionService.instance.loadState();
      if (mounted) {
        setState(() {
          _taxSettings = taxSettings;
          _customerSettings = customerSettings;
          _catalogSettings = catalogSettings;
          _printReceipt =
              printSettings.invoicePrintMode != PosInvoicePrintMode.none;
          _shortcutSettings = shortcutSettings;
          _touchModeEnabled = touchSettings.isEnabled;
          _drawerSession = drawerSession;
        });
      }
      await _loadCatalog();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_touchModeEnabled) {
            _focusDefaultTouchFieldIfNeeded();
          } else {
            _searchFocusNode.requestFocus();
          }
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error('Failed to load POS data: ${_readableError(error)}');
    }
  }

  void _focusDefaultTouchFieldIfNeeded() {
    if (!_touchModeEnabled || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!FocusScope.of(context).hasPrimaryFocus ||
          (!_searchFocusNode.hasFocus &&
              !_amountFocusNode.hasFocus &&
              !_cardAmountFocusNode.hasFocus &&
              !_discountFocusNode.hasFocus)) {
        _amountFocusNode.requestFocus();
      }
    });
  }

  TextEditingController get _activeTouchInputController {
    if (_searchFocusNode.hasFocus) {
      return _searchController;
    }
    if (_discountFocusNode.hasFocus) {
      return _discountController;
    }
    if (_cardAmountFocusNode.hasFocus) {
      return _cardAmountController;
    }
    return _amountController;
  }

  void _appendTouchDigit(String value) {
    final controller = _activeTouchInputController;
    if (value == '.') {
      if (_searchFocusNode.hasFocus) {
        return;
      }
      if (controller.text.contains('.')) {
        return;
      }
      if (controller.text.isEmpty) {
        controller.text = '0.';
      } else {
        controller.text = '${controller.text}.';
      }
    } else {
      controller.text = '${controller.text}$value';
    }
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    if (identical(controller, _searchController)) {
      _handleSearchChanged(controller.text);
    } else {
      setState(() {});
    }
  }

  void _removeTouchDigit() {
    final controller = _activeTouchInputController;
    if (controller.text.isEmpty) {
      return;
    }
    controller.text = controller.text.substring(0, controller.text.length - 1);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    if (identical(controller, _searchController)) {
      _handleSearchChanged(controller.text);
    } else {
      setState(() {});
    }
  }

  Future<void> _loadCatalog() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    final request = ++_catalogRequest;
    if (mounted) {
      setState(() => _isCatalogLoading = true);
    }
    try {
      final result = await repository.fetchCatalog(
        searchQuery: _searchController.text.trim(),
        category: _selectedCategory,
        loadMode: _catalogSettings.defaultLoadMode,
      );

      if (!mounted || request != _catalogRequest) {
        return;
      }

      setState(() {
        _categories = result.categories;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }
        _catalogItems = result.items;
        _selectedStockKey = _pickSelectableStockKey();
        _isLoading = false;
        _isCatalogLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _catalogRequest) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isCatalogLoading = false;
      });
      AppToast.error('Failed to load catalog: ${_readableError(error)}');
    }
  }

  Future<void> _loadCustomers() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    final request = ++_customerRequest;
    if (mounted) {
      setState(() => _isCustomerLoading = true);
    }
    try {
      final customers = await repository.searchCustomers(
        _customerController.text ==
                PosLocalRepository.walkInCustomer.searchLabel
            ? ''
            : _customerController.text,
      );

      if (!mounted || request != _customerRequest) {
        return;
      }

      setState(() {
        _customerSuggestions = customers;
        _isCustomerLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _customerRequest) {
        return;
      }
      setState(() => _isCustomerLoading = false);
      AppToast.error('Failed to load customers: ${_readableError(error)}');
    }
  }

  void _handleSearchChanged(String _) {
    _catalogRequest++;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), _loadCatalog);
  }

  void _handleCustomerChanged(String value) {
    _customerRequest++;
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
    if (_isProcessing) return;
    _searchDebounce?.cancel();
    final normalizedValue = value.trim().toLowerCase();
    if (normalizedValue.isNotEmpty) {
      final exactVisibleMatch = _visibleCatalogItems
          .where(
            (item) =>
                item.stockBarcode.toLowerCase() == normalizedValue ||
                item.productBarcode.toLowerCase() == normalizedValue,
          )
          .cast<PosCatalogItem?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (exactVisibleMatch != null) {
        _addCatalogItemToCart(exactVisibleMatch);
        return;
      }

      final repository = _repository;
      if (repository != null) {
        final exactMatch = await repository.findExactCatalogMatch(value);
        final adjustedMatch = exactMatch == null
            ? null
            : _adjustCatalogItemForCart(exactMatch);
        if (!mounted ||
            _isProcessing ||
            _searchController.text.trim().toLowerCase() != normalizedValue)
          return;
        if (adjustedMatch != null) {
          _addCatalogItemToCart(adjustedMatch);
          return;
        }
      }
    }

    await _loadCatalog();
    if (!mounted ||
        _isProcessing ||
        _searchController.text.trim().toLowerCase() != normalizedValue)
      return;
    final visibleItems = _visibleCatalogItems
        .where(
          (item) =>
              normalizedValue.isEmpty ||
              item.productName.toLowerCase().contains(normalizedValue) ||
              item.stockBarcode.toLowerCase().contains(normalizedValue) ||
              item.productBarcode.toLowerCase().contains(normalizedValue),
        )
        .toList();
    if (visibleItems.isEmpty && normalizedValue.isNotEmpty) {
      AppToast.error('No available product matches "$value"');
      return;
    }
    if (visibleItems.length == 1) {
      _addCatalogItemToCart(visibleItems.first);
      return;
    }

    final highlighted = visibleItems
        .where((item) => item.stockKey == _selectedStockKey)
        .cast<PosCatalogItem?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (highlighted != null) {
      _addCatalogItemToCart(highlighted);
    }
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

  bool get _hasManualCustomerEntry {
    final entered = _customerController.text.trim();
    if (entered.isEmpty) {
      return false;
    }
    if (entered == PosLocalRepository.walkInCustomer.searchLabel) {
      return false;
    }
    return entered != _selectedCustomer.searchLabel;
  }

  void _addCatalogItemToCart(PosCatalogItem item) {
    if (_isProcessing) return;
    _searchDebounce?.cancel();
    _catalogRequest++;
    final shouldReloadAfterAdd = _searchController.text.trim().isNotEmpty;

    final existingIndex = _cartItems.indexWhere(
      (cartItem) => cartItem.stockKey == item.stockKey,
    );

    if (existingIndex >= 0) {
      final existingItem = _cartItems[existingIndex];
      if (item.availableQty <= 0) {
        AppToast.error('No more quantity available for ${item.productName}');
        return;
      }

      setState(() {
        _cartItems[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + 1,
          availableQty: existingItem.quantity + item.availableQty,
        );
        _selectedStockKey = _pickSelectableStockKey(preferred: item.stockKey);
        _searchController.clear();
      });
    } else {
      setState(() {
        _cartItems.insert(
          0,
          PosCartItem(
            stockId: item.stockId,
            stockCloudId: item.stockCloudId,
            stockBarcode: item.stockBarcode,
            productBarcode: item.productBarcode,
            productName: item.productName,
            category: item.category,
            retailPrice: item.retailPrice,
            wholesalePrice: item.wholesalePrice,
            unitPrice: _catalogPriceForGroup(item),
            availableQty: item.availableQty,
            quantity: 1,
          ),
        );
        _selectedStockKey = _pickSelectableStockKey(preferred: item.stockKey);
        _searchController.clear();
      });
    }

    if (shouldReloadAfterAdd) {
      _loadCatalog();
    }
    _searchFocusNode.requestFocus();
  }

  void _changeCartQuantity(PosCartItem item, int delta) {
    if (_isProcessing) return;
    final index = _cartItems.indexWhere(
      (cartItem) => cartItem.stockKey == item.stockKey,
    );
    if (index < 0) {
      return;
    }

    final updatedQuantity = item.quantity + delta;
    if (updatedQuantity <= 0) {
      setState(() {
        _cartItems.removeAt(index);
        _selectedStockKey = _pickSelectableStockKey(preferred: item.stockKey);
        if (_discount > _subtotal) {
          _discountController.text = _subtotal.toStringAsFixed(2);
        }
      });
      return;
    }

    if (updatedQuantity > item.availableQty) {
      AppToast.error('No more quantity available for ${item.productName}');
      return;
    }

    setState(() {
      _cartItems[index] = item.copyWith(quantity: updatedQuantity);
      _selectedStockKey = _pickSelectableStockKey(preferred: item.stockKey);
      if (_discount > _subtotal) {
        _discountController.text = _subtotal.toStringAsFixed(2);
      }
    });
  }

  void _removeCartItem(PosCartItem item) {
    if (_isProcessing) return;
    setState(() {
      _cartItems.removeWhere((cartItem) => cartItem.stockKey == item.stockKey);
      _selectedStockKey = _pickSelectableStockKey(preferred: item.stockKey);
      if (_discount > _subtotal) {
        _discountController.text = _subtotal.toStringAsFixed(2);
      }
    });
    _searchFocusNode.requestFocus();
  }

  Future<void> _startNewTransaction() async {
    if (_isProcessing) return;
    if (_cartItems.isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this bill?'),
          content: const Text('The items in this unpaid bill will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep bill'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    _searchDebounce?.cancel();
    setState(() {
      _cartItems.clear();
      _amountController.clear();
      _discountController.clear();
      _cardAmountController.clear();
      _searchController.clear();
      _selectedCategory = 'All';
      _selectedPaymentMethod = PosPaymentMethod.cash;
      _selectedPricingGroup = PosPricingGroup.retail;
      _selectedStockKey = _pickSelectableStockKey();
    });
    _resetToWalkInCustomer();
    _searchFocusNode.requestFocus();
    _loadCatalog();
    AppToast.success('New transaction started');
  }

  Future<void> _processPayment() async {
    if (!_canProcessPayment) {
      return;
    }

    setState(() => _isProcessing = true);
    final items = List<PosCartItem>.unmodifiable(_cartItems);
    final subtotal = _subtotal,
        discount = _discount,
        tax = _tax,
        total = _total;
    final paid = _amountPaid, cash = _cashPaidAmount, card = _cardPaidAmount;
    final paymentMethod = _selectedPaymentMethod.label;
    final printReceipt = _printReceipt;

    try {
      final checkoutCustomer = await _resolveCheckoutCustomer();
      if (checkoutCustomer == null) {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }

      final result = await _repository!.processSale(
        items: items,
        customer: checkoutCustomer,
        paymentMethod: paymentMethod,
        amountPaid: paid,
        cashPaidAmount: cash,
        cardPaidAmount: card,
        cashierName: 'Admin User',
        discountAmount: discount,
        taxAmount: tax,
      );

      if (!mounted) {
        return;
      }

      final preview = InvoicePreviewData(
        invoiceNumber: result.invoiceNumber,
        customerName: checkoutCustomer.name,
        customerMobile: checkoutCustomer.isWalkIn ? '' : checkoutCustomer.phone,
        dateTimeText: DateTime.now()
            .toString()
            .replaceFirst('T', ' ')
            .substring(0, 16),
        items: items
            .map(
              (item) => InvoicePreviewLine(
                name: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ),
            )
            .toList(),
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        paymentMethod: paymentMethod,
        paidAmount: paid,
        cashPaidAmount: cash,
        cardPaidAmount: card,
        balance: result.changeAmount,
      );

      AppToast.success(
        'Payment processed successfully. Invoice ${result.invoiceNumber}',
      );

      setState(() {
        _cartItems.clear();
        _amountController.clear();
        _discountController.clear();
        _cardAmountController.clear();
        _searchController.clear();
        _selectedCategory = 'All';
        _selectedPaymentMethod = PosPaymentMethod.cash;
        _selectedStockKey = _pickSelectableStockKey();
        _isProcessing = false;
      });
      _resetToWalkInCustomer();
      await _loadCatalog();
      _searchFocusNode.requestFocus();
      try {
        final currentPrintSettings = await AppSettingsService.instance
            .loadPosPrintSettings();
        if (!mounted) return;
        if (!printReceipt) {
          if (currentPrintSettings.restaurantExtensionEnabled) {
            final setupState = await SetupService.instance.loadState();
            await _handlePostInvoiceRestaurantPrint(
              preview: preview,
              shopInfo: setupState.shopInfo,
              printSettings: currentPrintSettings,
            );
          }
        } else if (currentPrintSettings.invoicePrintMode ==
            PosInvoicePrintMode.instant) {
          await _printInstantly(preview);
        } else {
          await _showPrintPreview(preview);
        }
      } catch (_) {
        AppToast.error(
          'Bill saved. Printing failed; reprint it from Recent Invoices.',
        );
      }
    } on PosLocalRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessing = false);
      AppToast.error(error.message);
    } on PosRemoteRepositoryException catch (error) {
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

  Future<void> _showPrintPreview(InvoicePreviewData preview) async {
    final setupState = await SetupService.instance.loadState();
    final layoutSettings = await AppSettingsService.instance
        .loadInvoiceLayoutSettings();
    final printSettings = await AppSettingsService.instance
        .loadPosPrintSettings();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
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
            printer: await _resolveStoredPrinter(
              printSettings.invoicePrinterUrl,
            ),
          );
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pop();
          await _handlePostInvoiceRestaurantPrint(
            preview: preview,
            shopInfo: setupState.shopInfo,
            printSettings: printSettings,
          );
          AppToast.success(
            printSettings.restaurantExtensionEnabled
                ? 'Invoice and KOT sent to printer'
                : 'Invoice sent to printer',
          );
        },
      ),
    );
  }

  Future<void> _printInstantly(InvoicePreviewData preview) async {
    final setupState = await SetupService.instance.loadState();
    final layoutSettings = await AppSettingsService.instance
        .loadInvoiceLayoutSettings();
    final printSettings = await AppSettingsService.instance
        .loadPosPrintSettings();
    await InvoicePrintService.printInvoice(
      shopInfo: setupState.shopInfo,
      settings: layoutSettings,
      preview: preview,
      printer: await _resolveStoredPrinter(printSettings.invoicePrinterUrl),
    );
    await _handlePostInvoiceRestaurantPrint(
      preview: preview,
      shopInfo: setupState.shopInfo,
      printSettings: printSettings,
    );
    if (!mounted) {
      return;
    }
    AppToast.success(
      printSettings.restaurantExtensionEnabled
          ? 'Invoice and KOT sent to printer'
          : 'Invoice sent to printer',
    );
  }

  Future<void> _handlePostInvoiceRestaurantPrint({
    required InvoicePreviewData preview,
    required ShopInfo shopInfo,
    required PosPrintSettings printSettings,
  }) async {
    if (!printSettings.restaurantExtensionEnabled) {
      return;
    }

    if (printSettings.kotPreviewEnabled) {
      await _showKotPrintPreview(
        preview: preview,
        shopInfo: shopInfo,
        printSettings: printSettings,
      );
      return;
    }

    await KotPrintService.printKot(
      shopInfo: shopInfo,
      preview: preview,
      printer: await _resolveStoredPrinter(printSettings.kotPrinterUrl),
    );
  }

  Future<void> _showKotPrintPreview({
    required InvoicePreviewData preview,
    required ShopInfo shopInfo,
    required PosPrintSettings printSettings,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => KotPrintPreviewDialog(
        shopInfo: shopInfo,
        preview: preview,
        onPrint: () async {
          await KotPrintService.printKot(
            shopInfo: shopInfo,
            preview: preview,
            printer: await _resolveStoredPrinter(printSettings.kotPrinterUrl),
          );
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<Printer?> _resolveStoredPrinter(String printerUrl) async {
    final printers = await Printing.listPrinters();
    return _resolvePrinterByUrl(printers, printerUrl);
  }

  Printer? _resolvePrinterByUrl(List<Printer> printers, String printerUrl) {
    final normalizedUrl = printerUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    for (final printer in printers) {
      if (printer.url == normalizedUrl) {
        return printer;
      }
    }

    return null;
  }

  Future<PosCustomerOption?> _resolveCheckoutCustomer() async {
    if (!_hasManualCustomerEntry) {
      return _selectedCustomer;
    }

    final customerRepository = _customerRepository;
    if (customerRepository == null) {
      AppToast.error('Customer service is still loading. Please try again.');
      return null;
    }

    final enteredContact = _customerController.text.trim();
    final existingCustomer = await customerRepository.fetchCustomerByPhone(
      enteredContact,
    );

    if (existingCustomer != null) {
      final customer = PosCustomerOption(
        id: existingCustomer.id,
        cloudId: existingCustomer.cloudId,
        name: existingCustomer.name,
        phone: existingCustomer.phone,
        email: existingCustomer.email,
      );
      if (mounted) {
        setState(() {
          _selectedCustomer = customer;
          _customerController.text = customer.searchLabel;
          _showCustomerSuggestions = false;
        });
      }
      return customer;
    }

    if (_customerSettings.createCustomerOnlyContact) {
      final created = await customerRepository.saveCustomer(
        CustomerRecord(
          id: 0,
          name: enteredContact,
          email: '',
          phone: enteredContact,
          address: '',
          joinDate: '',
          invoices: const [],
        ),
      );

      final customer = PosCustomerOption(
        id: created.id,
        cloudId: created.cloudId,
        name: created.name,
        phone: created.phone,
        email: created.email,
      );
      if (mounted) {
        setState(() {
          _selectedCustomer = customer;
          _customerController.text = customer.searchLabel;
          _showCustomerSuggestions = false;
        });
      }

      AppToast.success('Customer created successfully');
      return customer;
    }

    setState(() => _isOpeningCustomerDialog = true);
    final created = await showDialog<CustomerRecord>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          PosCustomerCreateDialog(initialPhone: enteredContact),
    );
    if (mounted) {
      setState(() => _isOpeningCustomerDialog = false);
    }

    if (created == null) {
      return null;
    }

    final saved = await customerRepository.saveCustomer(created);
    final customer = PosCustomerOption(
      id: saved.id,
      cloudId: saved.cloudId,
      name: saved.name,
      phone: saved.phone,
      email: saved.email,
    );
    if (mounted) {
      setState(() {
        _selectedCustomer = customer;
        _customerController.text = customer.searchLabel;
        _showCustomerSuggestions = false;
      });
    }
    await _loadCustomers();
    AppToast.success('Customer created successfully');
    return customer;
  }

  String _readableError(Object error) {
    if (error is PosLocalRepositoryException) {
      return error.message;
    }
    if (error is PosRemoteRepositoryException) {
      return error.message;
    }
    if (error is CustomerLocalRepositoryException) {
      return error.message;
    }
    if (error is CustomerRemoteRepositoryException) {
      return error.message;
    }
    if (error is InvoiceLocalRepositoryException) {
      return error.message;
    }
    if (error is InvoiceRemoteRepositoryException) {
      return error.message;
    }
    if (error is ExpenseLocalRepositoryException) {
      return error.message;
    }
    if (error is ExpenseRemoteRepositoryException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _openRecentInvoicesDialog() async {
    final repository = _invoiceRepository;
    if (repository == null) {
      AppToast.error('Invoice service is still loading. Please try again.');
      return;
    }

    setState(() => _isRecentInvoicesLoading = true);
    try {
      final result = await repository.fetchInvoices(page: 1);
      if (!mounted) {
        return;
      }

      setState(() => _isRecentInvoicesLoading = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RecentInvoicesDialog(
          invoices: result.invoices.take(10).toList(),
          viewingInvoiceId: _viewingInvoiceId,
          printingInvoiceId: _printingInvoiceId,
          onView: _showRecentInvoiceDetails,
          onPrint: _printRecentInvoice,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isRecentInvoicesLoading = false);
      AppToast.error(
        'Failed to load recent invoices: ${_readableError(error)}',
      );
    }
  }

  Future<void> _openDaySessionAction() async {
    if (_drawerSession.isActive) {
      await _openDayEndDialog();
    } else {
      await _openDayStartDialog();
    }
  }

  Future<void> _openDayStartDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Day Start'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 360,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Opening Cash In Drawer',
                hintText: '0.00',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed < 0) {
                  return 'Enter a valid opening cash amount';
                }
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Start Day'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final openingCash = double.tryParse(controller.text.trim()) ?? 0;
    await DaySessionService.instance.startSession(
      openingCash: openingCash,
      cashierName: 'Admin User',
    );
    if (!mounted) {
      return;
    }
    AppToast.success('Day started successfully');
  }

  Future<void> _openDayEndDialog() async {
    final repository = _invoiceRepository;
    final expenseRepository = _expenseRepository;
    if (repository == null) {
      AppToast.error('Invoice service is still loading. Please try again.');
      return;
    }
    if (expenseRepository == null) {
      AppToast.error('Expense service is still loading. Please try again.');
      return;
    }

    setState(() => _isDaySessionLoading = true);
    try {
      final summary = await DaySessionService.instance.buildSummary(
        repository: repository,
        expenseRepository: expenseRepository,
        session: _drawerSession,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isDaySessionLoading = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DayEndSummaryDialog(
          summary: summary,
          onPrint: (actualCashInHand) async {
            final setupState = await SetupService.instance.loadState();
            await DaySessionPrintService.printSummary(
              shopInfo: setupState.shopInfo,
              summary: summary,
              actualCashInHand: actualCashInHand,
            );
            if (!mounted) {
              return;
            }
            AppToast.success('Day end summary sent to printer');
          },
          onEndDay: (actualCashInHand) async {
            await DaySessionService.instance.endSession();
            if (!mounted) {
              return;
            }
            AppToast.success(
              'Day ended. Drawer cash: Rs ${actualCashInHand.toStringAsFixed(2)}',
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isDaySessionLoading = false);
      AppToast.error(
        'Failed to load day end summary: ${_readableError(error)}',
      );
    }
  }

  Future<void> _showRecentInvoiceDetails(InvoiceRecord invoice) async {
    final repository = _invoiceRepository;
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

      if (!mounted) {
        return;
      }

      setState(() => _viewingInvoiceId = null);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InvoiceDetailsDialog(
          invoice: record,
          onPrint: () {
            Navigator.of(context).pop();
            _printRecentInvoice(record);
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

  Future<void> _openQuickExpenseDialog() async {
    final repository = _expenseRepository;
    if (repository == null) {
      AppToast.error('Expense service is still loading. Please try again.');
      return;
    }

    setState(() => _isSavingQuickExpense = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PosExpenseDialog(
          repository: repository,
          paidFromDrawerByDefault: true,
        ),
      );

      if (created != true || !mounted) {
        return;
      }

      AppToast.success('Expense recorded successfully');
    } finally {
      if (mounted) {
        setState(() => _isSavingQuickExpense = false);
      }
    }
  }

  Future<void> _printRecentInvoice(InvoiceRecord invoice) async {
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
        discount: invoice.discount,
        tax: invoice.tax,
        total: invoice.amount,
        paymentMethod: invoice.paymentMethod,
        paidAmount: invoice.paidAmount,
        cashPaidAmount: invoice.cashPaidAmount,
        cardPaidAmount: invoice.cardPaidAmount,
        balance: 0,
      );

      await showDialog<void>(
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

  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings() {
    return <ShortcutActivator, VoidCallback>{
      _shortcutSettings.productSearchKey.activator: () {
        _searchFocusNode.requestFocus();
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      },
      _shortcutSettings.customerSearchKey.activator: () {
        _customerFocusNode.requestFocus();
        _customerController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _customerController.text.length,
        );
      },
      _shortcutSettings.amountPaidKey.activator: () {
        _amountFocusNode.requestFocus();
        _amountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _amountController.text.length,
        );
      },
      _shortcutSettings.processPaymentKey.activator: () {
        if (_canProcessPayment) {
          _processPayment();
        }
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 860;
        final isTablet =
            constraints.maxWidth >= 860 && constraints.maxWidth < 1320;
        final pagePadding = constraints.maxWidth < 640 ? 12.0 : 18.0;
        final sectionGap = constraints.maxWidth < 640 ? 12.0 : 16.0;

        final productsPanel = _ProductsPanel(
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          categories: _categories,
          selectedCategory: _selectedCategory,
          products: _visibleCatalogItems,
          selectedStockKey: _selectedStockKey,
          viewMode: _catalogSettings.defaultViewMode,
          selectedPricingGroup: _selectedPricingGroup,
          isCatalogLoading: _isCatalogLoading,
          onSearchChanged: _handleSearchChanged,
          onSearchSubmitted: _handleSearchSubmitted,
          onMoveSelectionUp: () => _moveCatalogSelection(-1),
          onMoveSelectionDown: () => _moveCatalogSelection(1),
          onCategorySelected: (category) {
            setState(() => _selectedCategory = category);
            _loadCatalog();
            _searchFocusNode.requestFocus();
          },
          onProductSelected: _addCatalogItemToCart,
          onRefresh: () {
            _repository?.invalidateCatalog();
            _loadCatalog();
          },
        );

        final orderPanel = _OrderItemsPanel(
          items: _cartItems,
          onIncreaseQuantity: (item) => _changeCartQuantity(item, 1),
          onDecreaseQuantity: (item) => _changeCartQuantity(item, -1),
          onRemoveItem: _removeCartItem,
        );

        final checkoutPanel = _CheckoutPanel(
          customerController: _customerController,
          customerFocusNode: _customerFocusNode,
          customerSuggestions: _customerSuggestions,
          showCustomerSuggestions: _showCustomerSuggestions,
          isCustomerLoading: _isCustomerLoading,
          selectedCustomer: _selectedCustomer,
          amountController: _amountController,
          cardAmountController: _cardAmountController,
          discountController: _discountController,
          amountFocusNode: _amountFocusNode,
          cardAmountFocusNode: _cardAmountFocusNode,
          discountFocusNode: _discountFocusNode,
          selectedPaymentMethod: _selectedPaymentMethod,
          selectedPricingGroup: _selectedPricingGroup,
          subtotal: _subtotal,
          discount: _discount,
          tax: _tax,
          total: _total,
          taxLabel: _taxSettings.isTaxEnabled
              ? 'Tax (${_taxSettings.taxPercent % 1 == 0 ? _taxSettings.taxPercent.toStringAsFixed(0) : _taxSettings.taxPercent.toStringAsFixed(2)}%)'
              : null,
          balance: _balance,
          canProcessPayment: _canProcessPayment,
          isProcessing: _isProcessing,
          onPaymentMethodChanged: (method) {
            setState(() => _selectedPaymentMethod = method);
          },
          onPricingGroupChanged: _applyPricingGroup,
          onAmountChanged: (_) => setState(() {}),
          onCustomerChanged: _handleCustomerChanged,
          onCustomerTapped: () {
            setState(() => _showCustomerSuggestions = true);
            _loadCustomers();
          },
          onCustomerSelected: _selectCustomer,
          onResetCustomer: _resetToWalkInCustomer,
          onProcessPayment: _processPayment,
          printReceipt: _printReceipt,
          onPrintReceiptChanged: (value) =>
              setState(() => _printReceipt = value),
          onExactCash: () => setState(() {
            _selectedPaymentMethod = PosPaymentMethod.cash;
            _amountController.text = _total.toStringAsFixed(2);
            _cardAmountController.clear();
          }),
          isOpeningCustomerDialog: _isOpeningCustomerDialog,
          touchModeEnabled: _touchModeEnabled,
          onTouchDigitPressed: _appendTouchDigit,
          onTouchBackspace: _removeTouchDigit,
        );

        return Padding(
          padding: EdgeInsets.all(pagePadding),
          child: CallbackShortcuts(
            bindings: _buildShortcutBindings(),
            child: AbsorbPointer(
              absorbing: _isProcessing,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PosHeader(
                          compact: isMobile || constraints.maxHeight < 600,
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'New transaction',
                        onPressed: _isProcessing ? null : _startNewTransaction,
                        icon: const Icon(Icons.add_rounded),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'POS actions',
                        enabled: !_isProcessing,
                        onSelected: (value) {
                          if (value == 'expenses') _openQuickExpenseDialog();
                          if (value == 'day') _openDaySessionAction();
                          if (value == 'invoices') _openRecentInvoicesDialog();
                          if (value == 'refresh') {
                            _repository?.invalidateCatalog();
                            _loadCatalog();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            enabled: !_isSavingQuickExpense,
                            value: 'expenses',
                            child: Text('Add expense'),
                          ),
                          PopupMenuItem(
                            enabled: !_isDaySessionLoading,
                            value: 'day',
                            child: Text(
                              _drawerSession.isActive ? 'Day End' : 'Day Start',
                            ),
                          ),
                          PopupMenuItem(
                            enabled: !_isRecentInvoicesLoading,
                            value: 'invoices',
                            child: Text('Recent Invoices'),
                          ),
                          const PopupMenuItem(
                            value: 'refresh',
                            child: Text('Refresh products'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: sectionGap),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryTeal,
                            ),
                          )
                        : isMobile
                        ? _MobilePosWorkspace(
                            productsPanel: productsPanel,
                            orderPanel: orderPanel,
                            checkoutPanel: checkoutPanel,
                            cartItemCount: _cartItems.fold<int>(
                              0,
                              (count, item) => count + item.quantity,
                            ),
                            total: _total,
                          )
                        : isTablet
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: productsPanel),
                              SizedBox(width: sectionGap),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    Expanded(child: orderPanel),
                                    SizedBox(height: sectionGap),
                                    Expanded(child: checkoutPanel),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: productsPanel),
                              SizedBox(width: sectionGap),
                              Expanded(flex: 3, child: orderPanel),
                              SizedBox(width: sectionGap),
                              Expanded(flex: 3, child: checkoutPanel),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ).withAdaptivePageViewport(minHeight: 500);
      },
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
      case PosPaymentMethod.multiple:
        return 'Multiple';
    }
  }
}

extension on PosShortcutKey {
  ShortcutActivator get activator => switch (this) {
    PosShortcutKey.f1 => const SingleActivator(LogicalKeyboardKey.f1),
    PosShortcutKey.f2 => const SingleActivator(LogicalKeyboardKey.f2),
    PosShortcutKey.f3 => const SingleActivator(LogicalKeyboardKey.f3),
    PosShortcutKey.f4 => const SingleActivator(LogicalKeyboardKey.f4),
    PosShortcutKey.f5 => const SingleActivator(LogicalKeyboardKey.f5),
    PosShortcutKey.f6 => const SingleActivator(LogicalKeyboardKey.f6),
    PosShortcutKey.f7 => const SingleActivator(LogicalKeyboardKey.f7),
    PosShortcutKey.f8 => const SingleActivator(LogicalKeyboardKey.f8),
    PosShortcutKey.f9 => const SingleActivator(LogicalKeyboardKey.f9),
    PosShortcutKey.f10 => const SingleActivator(LogicalKeyboardKey.f10),
    PosShortcutKey.f11 => const SingleActivator(LogicalKeyboardKey.f11),
    PosShortcutKey.f12 => const SingleActivator(LogicalKeyboardKey.f12),
  };
}

Color _posAccentSurface([double amount = 0.12]) =>
    Color.lerp(Colors.white, AppColors.primaryTeal, amount)!;

Color _posAccentBorder([double amount = 0.34]) =>
    Color.lerp(Colors.white, AppColors.primaryTeal, amount)!;

Color _posAccentStrong([double amount = 0.18]) =>
    Color.lerp(Colors.white, AppColors.primaryTeal, amount)!;

class _PosHeader extends StatelessWidget {
  const _PosHeader({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        if (!compact) const SizedBox(height: 6),
        if (!compact)
          const Text(
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

class PosCustomerCreateDialog extends StatefulWidget {
  const PosCustomerCreateDialog({super.key, required this.initialPhone});

  final String initialPhone;

  @override
  State<PosCustomerCreateDialog> createState() =>
      _PosCustomerCreateDialogState();
}

class _PosCustomerCreateDialogState extends State<PosCustomerCreateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController(text: widget.initialPhone);
    _addressController = TextEditingController();
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
        id: 0,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        joinDate: '',
        invoices: const [],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF91A0B5), size: 20),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
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
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x250F172A),
              blurRadius: 36,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 14, 18),
              child: Row(
                children: [
                  const Text(
                    'Add New Customer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3A4D),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8EDF4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: _fieldDecoration(
                      hintText: 'Enter customer name',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          decoration: _fieldDecoration(
                            hintText: 'email@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          decoration: _fieldDecoration(
                            hintText: '+94 7x xxx xxxx',
                            prefixIcon: Icons.call_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _addressController,
                    maxLines: 4,
                    decoration: _fieldDecoration(
                      hintText: 'Enter full address',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
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
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Add Customer'),
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

class _ProductsPanel extends StatelessWidget {
  const _ProductsPanel({
    required this.searchController,
    required this.searchFocusNode,
    required this.categories,
    required this.selectedCategory,
    required this.products,
    required this.selectedStockKey,
    required this.viewMode,
    required this.selectedPricingGroup,
    required this.isCatalogLoading,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onMoveSelectionUp,
    required this.onMoveSelectionDown,
    required this.onCategorySelected,
    required this.onProductSelected,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<String> categories;
  final String selectedCategory;
  final List<PosCatalogItem> products;
  final String? selectedStockKey;
  final PosCatalogViewMode viewMode;
  final PosPricingGroup selectedPricingGroup;
  final bool isCatalogLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onMoveSelectionUp;
  final VoidCallback onMoveSelectionDown;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<PosCatalogItem> onProductSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374457),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh products',
                onPressed: isCatalogLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.arrowDown):
                  onMoveSelectionDown,
              const SingleActivator(LogicalKeyboardKey.arrowUp):
                  onMoveSelectionUp,
            },
            child: SizedBox(
              height: 38,
              child: TextField(
                key: const ValueKey('pos-product-search'),
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
                    borderSide: BorderSide(color: AppColors.primaryTeal),
                  ),
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
            child: isCatalogLoading
                ? const _PosCatalogSkeleton()
                : products.isEmpty
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
                : viewMode == PosCatalogViewMode.compact
                ? GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductCompactTile(
                        key: ValueKey('product-${product.stockKey}'),
                        product: product,
                        selectedPricingGroup: selectedPricingGroup,
                        isSelected: product.stockKey == selectedStockKey,
                        onTap: () => onProductSelected(product),
                      );
                    },
                  )
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return _ProductRow(
                        key: ValueKey('product-${product.stockKey}'),
                        product: product,
                        selectedPricingGroup: selectedPricingGroup,
                        isSelected: product.stockKey == selectedStockKey,
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

class _ProductCompactTile extends StatelessWidget {
  const _ProductCompactTile({
    super.key,
    required this.product,
    required this.selectedPricingGroup,
    required this.isSelected,
    required this.onTap,
  });

  final PosCatalogItem product;
  final PosPricingGroup selectedPricingGroup;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayPrice = selectedPricingGroup == PosPricingGroup.retail
        ? product.retailPrice
        : product.wholesalePrice;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected ? _posAccentSurface(0.12) : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryTeal
                  : const Color(0xFFE5EBF2),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: _posAccentSurface(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primaryTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF344256),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs ${displayPrice.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderItemsPanel extends StatelessWidget {
  const _OrderItemsPanel({
    required this.items,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onRemoveItem,
  });

  final List<PosCartItem> items;
  final ValueChanged<PosCartItem> onIncreaseQuantity;
  final ValueChanged<PosCartItem> onDecreaseQuantity;
  final ValueChanged<PosCartItem> onRemoveItem;

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}

class _MobilePosWorkspace extends StatelessWidget {
  const _MobilePosWorkspace({
    required this.productsPanel,
    required this.orderPanel,
    required this.checkoutPanel,
    required this.cartItemCount,
    required this.total,
  });
  final Widget productsPanel, orderPanel, checkoutPanel;
  final int cartItemCount;
  final double total;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        TabBar(
          tabs: [
            const Tab(text: 'Products'),
            Tab(text: 'Cart ($cartItemCount)'),
            const Tab(text: 'Checkout'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            children: [productsPanel, orderPanel, checkoutPanel],
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) => SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: cartItemCount == 0
                  ? null
                  : () => DefaultTabController.of(context).animateTo(2),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text('Review bill • Rs ${total.toStringAsFixed(2)}'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({
    required this.customerController,
    required this.customerFocusNode,
    required this.customerSuggestions,
    required this.showCustomerSuggestions,
    required this.isCustomerLoading,
    required this.selectedCustomer,
    required this.amountController,
    required this.cardAmountController,
    required this.discountController,
    required this.amountFocusNode,
    required this.cardAmountFocusNode,
    required this.discountFocusNode,
    required this.selectedPaymentMethod,
    required this.selectedPricingGroup,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.taxLabel,
    required this.balance,
    required this.canProcessPayment,
    required this.isProcessing,
    required this.isOpeningCustomerDialog,
    required this.onPaymentMethodChanged,
    required this.onPricingGroupChanged,
    required this.onAmountChanged,
    required this.onCustomerChanged,
    required this.onCustomerTapped,
    required this.onCustomerSelected,
    required this.onResetCustomer,
    required this.onProcessPayment,
    required this.onExactCash,
    required this.printReceipt,
    required this.onPrintReceiptChanged,
    required this.touchModeEnabled,
    required this.onTouchDigitPressed,
    required this.onTouchBackspace,
  });

  final TextEditingController customerController;
  final FocusNode customerFocusNode;
  final List<PosCustomerOption> customerSuggestions;
  final bool showCustomerSuggestions;
  final bool isCustomerLoading;
  final PosCustomerOption selectedCustomer;
  final TextEditingController amountController;
  final TextEditingController cardAmountController;
  final TextEditingController discountController;
  final FocusNode amountFocusNode;
  final FocusNode cardAmountFocusNode;
  final FocusNode discountFocusNode;
  final PosPaymentMethod selectedPaymentMethod;
  final PosPricingGroup selectedPricingGroup;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? taxLabel;
  final double balance;
  final bool canProcessPayment;
  final bool isProcessing;
  final bool isOpeningCustomerDialog;
  final ValueChanged<PosPaymentMethod> onPaymentMethodChanged;
  final ValueChanged<PosPricingGroup> onPricingGroupChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCustomerTapped;
  final ValueChanged<String> onCustomerChanged;
  final ValueChanged<PosCustomerOption> onCustomerSelected;
  final VoidCallback onResetCustomer;
  final VoidCallback onProcessPayment;
  final VoidCallback onExactCash;
  final bool printReceipt;
  final ValueChanged<bool> onPrintReceiptChanged;
  final bool touchModeEnabled;
  final ValueChanged<String> onTouchDigitPressed;
  final VoidCallback onTouchBackspace;

  @override
  Widget build(BuildContext context) {
    final hasShortPayment = subtotal > 0 && balance < 0;
    final showCashAmountField = selectedPaymentMethod != PosPaymentMethod.card;
    final showCardAmountField =
        selectedPaymentMethod == PosPaymentMethod.multiple;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        return _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checkout',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374457),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('pos-exact-cash'),
                          onPressed: subtotal > 0 && !isProcessing
                              ? onExactCash
                              : null,
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(
                            'Exact cash • Rs ${total.toStringAsFixed(2)}',
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Print receipt'),
                        value: printReceipt,
                        onChanged: isProcessing ? null : onPrintReceiptChanged,
                      ),
                      const SizedBox(height: 14),
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
                      if (isCustomerLoading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          minHeight: 2,
                          color: AppColors.primaryTeal,
                          backgroundColor: _posAccentSurface(),
                        ),
                      ],
                      if (showCustomerSuggestions &&
                          customerSuggestions.isNotEmpty) ...[
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
                      const Text(
                        'Discount',
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
                          controller: discountController,
                          focusNode: discountFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: onAmountChanged,
                          decoration: InputDecoration(
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 32,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 8, right: 2),
                              child: Icon(
                                Icons.local_offer_outlined,
                                size: 16,
                                color: Color(0xFF78889E),
                              ),
                            ),
                            hintText: '0.00',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.primaryTeal,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.primaryTeal,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (discount > 0) ...[
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Discount',
                          value: '-Rs ${discount.toStringAsFixed(2)}',
                          valueColor: const Color(0xFFE35D5D),
                        ),
                      ],
                      if (taxLabel != null) ...[
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: taxLabel!,
                          value: 'Rs ${tax.toStringAsFixed(2)}',
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFFEDF2F7), height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF344256),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Rs ${total.toStringAsFixed(2)}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Pricing Group',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A586B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      isCompact
                          ? Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: _PaymentMethodButton(
                                    label: 'Retail',
                                    icon: Icons.storefront_outlined,
                                    isSelected:
                                        selectedPricingGroup ==
                                        PosPricingGroup.retail,
                                    onTap: () => onPricingGroupChanged(
                                      PosPricingGroup.retail,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: _PaymentMethodButton(
                                    label: 'Wholesale',
                                    icon: Icons.local_shipping_outlined,
                                    isSelected:
                                        selectedPricingGroup ==
                                        PosPricingGroup.wholesale,
                                    onTap: () => onPricingGroupChanged(
                                      PosPricingGroup.wholesale,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _PaymentMethodButton(
                                    label: 'Retail',
                                    icon: Icons.storefront_outlined,
                                    isSelected:
                                        selectedPricingGroup ==
                                        PosPricingGroup.retail,
                                    onTap: () => onPricingGroupChanged(
                                      PosPricingGroup.retail,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _PaymentMethodButton(
                                    label: 'Wholesale',
                                    icon: Icons.local_shipping_outlined,
                                    isSelected:
                                        selectedPricingGroup ==
                                        PosPricingGroup.wholesale,
                                    onTap: () => onPricingGroupChanged(
                                      PosPricingGroup.wholesale,
                                    ),
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
                      if (isCompact)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: _PaymentMethodButton(
                                label: 'Cash',
                                icon: Icons.receipt_long_outlined,
                                isSelected:
                                    selectedPaymentMethod ==
                                    PosPaymentMethod.cash,
                                onTap: () => onPaymentMethodChanged(
                                  PosPaymentMethod.cash,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _PaymentMethodButton(
                                    label: 'Card',
                                    icon: Icons.credit_card_outlined,
                                    isSelected:
                                        selectedPaymentMethod ==
                                        PosPaymentMethod.card,
                                    onTap: () => onPaymentMethodChanged(
                                      PosPaymentMethod.card,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _PaymentMethodButton(
                                    label: 'Multiple',
                                    icon: Icons.payments_outlined,
                                    isSelected:
                                        selectedPaymentMethod ==
                                        PosPaymentMethod.multiple,
                                    onTap: () => onPaymentMethodChanged(
                                      PosPaymentMethod.multiple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _PaymentMethodButton(
                                label: 'Cash',
                                icon: Icons.receipt_long_outlined,
                                isSelected:
                                    selectedPaymentMethod ==
                                    PosPaymentMethod.cash,
                                onTap: () => onPaymentMethodChanged(
                                  PosPaymentMethod.cash,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PaymentMethodButton(
                                label: 'Card',
                                icon: Icons.credit_card_outlined,
                                isSelected:
                                    selectedPaymentMethod ==
                                    PosPaymentMethod.card,
                                onTap: () => onPaymentMethodChanged(
                                  PosPaymentMethod.card,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PaymentMethodButton(
                                label: 'Multiple',
                                icon: Icons.payments_outlined,
                                isSelected:
                                    selectedPaymentMethod ==
                                    PosPaymentMethod.multiple,
                                onTap: () => onPaymentMethodChanged(
                                  PosPaymentMethod.multiple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (showCashAmountField) ...[
                        const SizedBox(height: 14),
                        Text(
                          showCardAmountField ? 'Cash Amount' : 'Amount Paid',
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
                            focusNode: amountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: onAmountChanged,
                            decoration: InputDecoration(
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 32,
                              ),
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
                                borderSide: BorderSide(
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (showCardAmountField) ...[
                        const Text(
                          'Card Amount',
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
                            controller: cardAmountController,
                            focusNode: cardAmountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: onAmountChanged,
                            decoration: InputDecoration(
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 32,
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 8, right: 2),
                                child: Icon(
                                  Icons.credit_card_rounded,
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
                                borderSide: BorderSide(
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: hasShortPayment
                              ? const Color(0xFFFFEFEF)
                              : _posAccentSurface(0.20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasShortPayment
                                ? const Color(0xFFF2B5B5)
                                : _posAccentBorder(0.46),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hasShortPayment
                                    ? 'Balance Due'
                                    : 'Change to Return',
                                style: const TextStyle(
                                  color: Color(0xFF4A586B),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Rs ${balance.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                color: hasShortPayment
                                    ? const Color(0xFFEA5A5A)
                                    : AppColors.primaryTeal,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (touchModeEnabled) ...[
                        const SizedBox(height: 14),
                        _TouchCheckoutNumberPad(
                          onDigitPressed: onTouchDigitPressed,
                          onBackspace: onTouchBackspace,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  key: const ValueKey('pos-process-payment'),
                  onPressed: canProcessPayment ? onProcessPayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    disabledBackgroundColor: _posAccentBorder(0.45),
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
                    isProcessing
                        ? 'Processing...'
                        : isOpeningCustomerDialog
                        ? 'Opening Customer Form...'
                        : 'Process Payment',
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
      },
    );
  }
}

class _TouchCheckoutNumberPad extends StatelessWidget {
  const _TouchCheckoutNumberPad({
    required this.onDigitPressed,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
      <String>['.', '0', 'back'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((value) {
              final isBack = value == 'back';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      if (isBack) {
                        onBackspace();
                      } else {
                        onDigitPressed(value);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4EAF2)),
                      ),
                      child: Center(
                        child: isBack
                            ? const Icon(
                                Icons.backspace_outlined,
                                color: Color(0xFF64748B),
                              )
                            : Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _PosCatalogSkeleton extends StatelessWidget {
  const _PosCatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 10,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.35, end: 0.9),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: Container(
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7EDF5)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7FB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7FB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 16,
                  width: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F7F4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          color: isSelected ? AppColors.primaryTeal : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : const Color(0xFFE2E8F0),
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

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.product,
    required this.selectedPricingGroup,
    required this.isSelected,
    required this.onTap,
  });

  final PosCatalogItem product;
  final PosPricingGroup selectedPricingGroup;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayPrice = selectedPricingGroup == PosPricingGroup.retail
        ? product.retailPrice
        : product.wholesalePrice;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? _posAccentBorder(0.52)
                    : const Color(0xFFE7EDF5),
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 30,
                      color: Color(0xFFCBD6E4),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        product.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF465366),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.productBarcode.isEmpty
                            ? product.category
                            : '${product.category} • ${product.productBarcode}',
                        maxLines: isCompact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF96A3B6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock: ${product.availableQty} • ${product.stockBarcode}',
                        maxLines: isCompact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF96A3B6),
                        ),
                      ),
                      if (isCompact) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              'Rs ${displayPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _posAccentSurface(0.16)
                                    : const Color(0xFFF5F8FB),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isSelected ? 'Selected' : 'Add',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.primaryTeal
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Rs ${displayPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _posAccentSurface(0.16)
                              : const Color(0xFFF5F8FB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isSelected ? 'Selected' : 'Add',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primaryTeal
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;

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
              if (isCompact) ...[
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
                    const Spacer(),
                    Text(
                      'Rs ${item.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'x Rs ${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF93A0B2),
                  ),
                ),
              ] else
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
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
            borderSide: BorderSide(color: AppColors.primaryTeal),
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
        color: _posAccentSurface(0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _posAccentBorder(0.46)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: AppColors.primaryTeal,
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A879A),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
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
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTeal : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : const Color(0xFFE1E8F1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

class _RecentInvoicesDialog extends StatelessWidget {
  const _RecentInvoicesDialog({
    required this.invoices,
    required this.viewingInvoiceId,
    required this.printingInvoiceId,
    required this.onView,
    required this.onPrint,
  });

  final List<InvoiceRecord> invoices;
  final String? viewingInvoiceId;
  final String? printingInvoiceId;
  final ValueChanged<InvoiceRecord> onView;
  final ValueChanged<InvoiceRecord> onPrint;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 680),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Invoices',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View or print the latest completed transactions.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xD9FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: invoices.isEmpty
                  ? const Center(
                      child: Text(
                        'No recent invoices found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF90A0B4),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: invoices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final invoice = invoices[index];
                        final isViewing = viewingInvoiceId == invoice.invoiceId;
                        final isPrinting =
                            printingInvoiceId == invoice.invoiceId;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE6ECF3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      invoice.invoiceId,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF39475A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      invoice.customerName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF55657A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${invoice.date} • ${invoice.paymentMethod}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF95A3B5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs ${invoice.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryTeal,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: isViewing
                                            ? null
                                            : () => onView(invoice),
                                        icon: isViewing
                                            ? SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          AppColors.primaryTeal,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.visibility_outlined,
                                                size: 16,
                                              ),
                                        label: const Text('View'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: isPrinting
                                            ? null
                                            : () => onPrint(invoice),
                                        icon: isPrinting
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.print_outlined,
                                                size: 16,
                                              ),
                                        label: const Text('Print'),
                                      ),
                                    ],
                                  ),
                                ],
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
    );
  }
}

class _PosExpenseDialog extends StatefulWidget {
  const _PosExpenseDialog({
    required this.repository,
    required this.paidFromDrawerByDefault,
  });

  final ExpenseRepository repository;
  final bool paidFromDrawerByDefault;

  @override
  State<_PosExpenseDialog> createState() => _PosExpenseDialogState();
}

class _PosExpenseDialogState extends State<_PosExpenseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _notesController;
  bool _paidFromDrawer = true;
  bool _isSaving = false;
  List<String> _categorySuggestions = const <String>[];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _categoryController = TextEditingController();
    _amountController = TextEditingController();
    _dateController = TextEditingController(
      text: formatAppDate(DateTime.now()),
    );
    _paymentMethodController = TextEditingController(text: 'Cash');
    _notesController = TextEditingController();
    _paidFromDrawer = widget.paidFromDrawerByDefault;
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
          title: _titleController.text.trim(),
          category: _categoryController.text.trim(),
          amount: double.tryParse(_amountController.text.trim()) ?? 0,
          date: parsedDate,
          paymentMethod: _paymentMethodController.text.trim(),
          paidFromDrawer: _paidFromDrawer,
          notes: _notesController.text.trim(),
          status: ExpenseStatus.active,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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
        borderSide: BorderSide(color: AppColors.primaryTeal, width: 1.4),
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
                  const Text(
                    'Add Expense',
                    style: TextStyle(
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
                            child: AppDateField(
                              controller: _dateController,
                              hintText: 'Expense date',
                              decoration: decoration('Expense date'),
                              validator: (value) => parseAppDate(value) == null
                                  ? 'Select a valid date'
                                  : null,
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
                          'Day end drawer balance will be reduced by this expense amount.',
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
                    label: Text(_isSaving ? 'Saving...' : 'Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
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

class _DayEndSummaryDialog extends StatefulWidget {
  const _DayEndSummaryDialog({
    required this.summary,
    required this.onPrint,
    required this.onEndDay,
  });

  final DrawerSessionSummary summary;
  final Future<void> Function(double actualCashInHand) onPrint;
  final Future<void> Function(double actualCashInHand) onEndDay;

  @override
  State<_DayEndSummaryDialog> createState() => _DayEndSummaryDialogState();
}

class _DayEndSummaryDialogState extends State<_DayEndSummaryDialog> {
  late final TextEditingController _cashInHandController;
  bool _isPrinting = false;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _cashInHandController = TextEditingController(
      text: widget.summary.expectedDrawerAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _cashInHandController.dispose();
    super.dispose();
  }

  double get _actualCashInHand =>
      double.tryParse(_cashInHandController.text.trim()) ?? 0;

  double get _variance =>
      _actualCashInHand - widget.summary.expectedDrawerAmount;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day End Summary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Review cashier totals before closing the day.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xD9FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                        child: _DaySummaryCard(
                          label: 'Opening Cash',
                          value:
                              'Rs ${widget.summary.session.openingCash.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DaySummaryCard(
                          label: 'Cash Sales',
                          value:
                              'Rs ${widget.summary.cashSales.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DaySummaryCard(
                          label: 'Card Sales',
                          value:
                              'Rs ${widget.summary.cardSales.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DaySummaryCard(
                          label: 'Drawer Expenses',
                          value:
                              'Rs ${widget.summary.drawerExpenseTotal.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DaySummaryCard(
                          label: 'Total Sales',
                          value:
                              'Rs ${widget.summary.totalSales.toStringAsFixed(2)}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DaySummaryCard(
                          label: 'Expected Drawer Amount',
                          value:
                              'Rs ${widget.summary.expectedDrawerAmount.toStringAsFixed(2)}',
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cashInHandController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Cash In Hand',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DaySummaryCard(
                    label: _variance >= 0 ? 'Over Amount' : 'Short Amount',
                    value: 'Rs ${_variance.abs().toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isPrinting || _isEnding
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isPrinting || _isEnding
                            ? null
                            : () async {
                                setState(() => _isPrinting = true);
                                try {
                                  await widget.onPrint(_actualCashInHand);
                                } finally {
                                  if (mounted) {
                                    setState(() => _isPrinting = false);
                                  }
                                }
                              },
                        icon: _isPrinting
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryTeal,
                                ),
                              )
                            : const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print Chit'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isPrinting || _isEnding
                            ? null
                            : () async {
                                setState(() => _isEnding = true);
                                try {
                                  await widget.onEndDay(_actualCashInHand);
                                  if (!mounted) {
                                    return;
                                  }
                                  Navigator.of(context).pop();
                                } finally {
                                  if (mounted) {
                                    setState(() => _isEnding = false);
                                  }
                                }
                              },
                        child: _isEnding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('End Day'),
                      ),
                    ],
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

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? _posAccentSurface(0.16) : const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? _posAccentBorder(0.4) : const Color(0xFFE6ECF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A889B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primaryTeal : AppColors.textPrimary,
            ),
          ),
        ],
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
