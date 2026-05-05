import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/toast/app_toast.dart';
import '../../../../core/services/invoice_print_service.dart';
import '../../../../core/services/kot_print_service.dart';
import '../../../../core/widgets/invoice_preview.dart';
import '../../data/customer_local_repository.dart';
import '../../data/customer_remote_repository.dart';
import '../../data/customer_repository.dart';
import '../../data/customer_repository_factory.dart';
import '../../data/pos_local_repository.dart';
import '../../data/pos_remote_repository.dart';
import '../../data/pos_repository.dart';
import '../../data/pos_repository_factory.dart';
import '../../models/models.dart';
import '../../../settings/services/app_settings_service.dart';
import '../../../setup/services/setup_service.dart';
import 'package:printing/printing.dart';

enum PosPaymentMethod { cash, card, upi }

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  PosRepository? _repository;
  CustomerRepository? _customerRepository;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _customerFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  Timer? _searchDebounce;
  Timer? _customerDebounce;

  List<String> _categories = const <String>['All'];
  List<PosCatalogItem> _catalogItems = <PosCatalogItem>[];
  List<PosCustomerOption> _customerSuggestions = <PosCustomerOption>[];
  final List<PosCartItem> _cartItems = <PosCartItem>[];

  String _selectedCategory = 'All';
  PosPaymentMethod _selectedPaymentMethod = PosPaymentMethod.cash;
  PosCustomerOption _selectedCustomer = PosLocalRepository.walkInCustomer;
  String? _selectedStockKey;
  bool _showCustomerSuggestions = false;
  bool _isLoading = true;
  bool _isCatalogLoading = false;
  bool _isCustomerLoading = false;
  bool _isProcessing = false;
  bool _isOpeningCustomerDialog = false;
  PosTaxSettings _taxSettings = const PosTaxSettings(
    isTaxEnabled: false,
    taxPercent: 10,
  );
  PosCustomerSettings _customerSettings = const PosCustomerSettings(
    createCustomerOnlyContact: false,
  );
  PosPrintSettings _printSettings = PosPrintSettings.defaults;
  PosShortcutSettings _shortcutSettings = PosShortcutSettings.defaults;

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
    _amountFocusNode.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _cartItems.fold<double>(0, (sum, item) => sum + item.subtotal);
  double get _tax =>
      _taxSettings.isTaxEnabled ? _subtotal * _taxSettings.taxRate : 0;
  double get _total => _subtotal + _tax;
  double get _amountPaid => double.tryParse(_amountController.text.trim()) ?? 0;
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
            sellingPrice: item.sellingPrice,
          );
        })
        .where((item) => item.availableQty > 0)
        .toList();
  }

  bool get _canProcessPayment =>
      !_isProcessing && _cartItems.isNotEmpty && _amountPaid >= _total;

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
      sellingPrice: item.sellingPrice,
    );
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

  Future<void> _initializePage() async {
    try {
      final repository = await PosRepositoryFactory.create();
      final customerRepository = await CustomerRepositoryFactory.create();
      await repository.initialize();
      await customerRepository.initialize();
      _repository = repository;
      _customerRepository = customerRepository;
      final taxSettings = await AppSettingsService.instance
          .loadPosTaxSettings();
      final customerSettings = await AppSettingsService.instance
          .loadPosCustomerSettings();
      final printSettings = await AppSettingsService.instance
          .loadPosPrintSettings();
      final shortcutSettings = await AppSettingsService.instance
          .loadPosShortcutSettings();
      await _loadCatalog();
      await _loadCustomers();
      if (mounted) {
        setState(() {
          _taxSettings = taxSettings;
          _customerSettings = customerSettings;
          _printSettings = printSettings;
          _shortcutSettings = shortcutSettings;
        });
      }
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
      AppToast.error('Failed to load POS data: ${_readableError(error)}');
    }
  }

  Future<void> _loadCatalog() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    if (mounted) {
      setState(() => _isCatalogLoading = true);
    }
    try {
      final result = await repository.fetchCatalog(
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
        _selectedStockKey = _pickSelectableStockKey();
        _isLoading = false;
        _isCatalogLoading = false;
      });
    } catch (error) {
      if (!mounted) {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _customerSuggestions = customers;
        _isCustomerLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isCustomerLoading = false);
      AppToast.error('Failed to load customers: ${_readableError(error)}');
    }
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
        if (adjustedMatch != null) {
          _addCatalogItemToCart(adjustedMatch);
          return;
        }
      }
    }

    final visibleItems = _visibleCatalogItems;
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
    final shouldReloadAfterAdd = _searchController.text.trim().isNotEmpty;

    final existingIndex = _cartItems.indexWhere(
      (cartItem) => cartItem.stockKey == item.stockKey,
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
            unitPrice: item.sellingPrice,
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
    });
  }

  void _removeCartItem(PosCartItem item) {
    setState(() {
      _cartItems.removeWhere((cartItem) => cartItem.stockKey == item.stockKey);
      _selectedStockKey = _pickSelectableStockKey(preferred: item.stockKey);
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
      _selectedStockKey = _pickSelectableStockKey();
    });
    _resetToWalkInCustomer();
    _searchFocusNode.requestFocus();
    AppToast.success('New transaction started');
  }

  Future<void> _processPayment() async {
    if (!_canProcessPayment) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final checkoutCustomer = await _resolveCheckoutCustomer();
      if (checkoutCustomer == null) {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }

      final result = await _repository!.processSale(
        items: _cartItems,
        customer: checkoutCustomer,
        paymentMethod: _selectedPaymentMethod.label,
        amountPaid: _amountPaid,
        cashierName: 'Admin User',
        taxAmount: _tax,
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
        items: _cartItems
            .map(
              (item) => InvoicePreviewLine(
                name: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ),
            )
            .toList(),
        subtotal: _subtotal,
        tax: _tax,
        total: _total,
        paymentMethod: _selectedPaymentMethod.label,
        paidAmount: _amountPaid,
        balance: result.changeAmount,
      );

      AppToast.success(
        'Payment processed successfully. Invoice ${result.invoiceNumber}',
      );

      setState(() {
        _cartItems.clear();
        _amountController.clear();
        _searchController.clear();
        _selectedCategory = 'All';
        _selectedPaymentMethod = PosPaymentMethod.cash;
        _selectedStockKey = _pickSelectableStockKey();
        _isProcessing = false;
      });
      _resetToWalkInCustomer();
      await _loadCatalog();
      _searchFocusNode.requestFocus();
      final currentPrintSettings = await AppSettingsService.instance
          .loadPosPrintSettings();
      if (mounted) {
        setState(() => _printSettings = currentPrintSettings);
      }
      if (currentPrintSettings.invoicePrintMode ==
          PosInvoicePrintMode.instant) {
        await _printInstantly(preview);
      } else {
        await _showPrintPreview(preview);
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
      await _loadCustomers();
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
    return error.toString();
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
          amountFocusNode: _amountFocusNode,
          selectedPaymentMethod: _selectedPaymentMethod,
          subtotal: _subtotal,
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
          onAmountChanged: (_) => setState(() {}),
          onCustomerChanged: _handleCustomerChanged,
          onCustomerTapped: () {
            setState(() => _showCustomerSuggestions = true);
          },
          onCustomerSelected: _selectCustomer,
          onResetCustomer: _resetToWalkInCustomer,
          onProcessPayment: _processPayment,
          isOpeningCustomerDialog: _isOpeningCustomerDialog,
        );

        return Padding(
          padding: EdgeInsets.all(pagePadding),
          child: CallbackShortcuts(
            bindings: _buildShortcutBindings(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (constraints.maxWidth < 760) ...[
                  const _PosHeader(),
                  SizedBox(height: sectionGap),
                  SizedBox(
                    width: double.infinity,
                    child: _PrimaryActionButton(
                      label: 'New Transaction',
                      icon: Icons.add,
                      onPressed: _isProcessing ? null : _startNewTransaction,
                      isLoading: false,
                    ),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _PosHeader()),
                      const SizedBox(width: 16),
                      _PrimaryActionButton(
                        label: 'New Transaction',
                        icon: Icons.add,
                        onPressed: _isProcessing ? null : _startNewTransaction,
                        isLoading: false,
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
                      ? Column(
                          children: [
                            Expanded(flex: 11, child: productsPanel),
                            SizedBox(height: sectionGap),
                            Expanded(
                              flex: 10,
                              child: _MobilePosBillingPanel(
                                orderPanel: orderPanel,
                                checkoutPanel: checkoutPanel,
                                cartItemCount: _cartItems.length,
                                canProcessPayment: _canProcessPayment,
                              ),
                            ),
                          ],
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
        );
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
      case PosPaymentMethod.upi:
        return 'UPI';
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
    required this.isCatalogLoading,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onMoveSelectionUp,
    required this.onMoveSelectionDown,
    required this.onCategorySelected,
    required this.onProductSelected,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<String> categories;
  final String selectedCategory;
  final List<PosCatalogItem> products;
  final String? selectedStockKey;
  final bool isCatalogLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onMoveSelectionUp;
  final VoidCallback onMoveSelectionDown;
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
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = products[index];

                      return _ProductRow(
                        product: product,
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

class _MobilePosBillingPanel extends StatelessWidget {
  const _MobilePosBillingPanel({
    required this.orderPanel,
    required this.checkoutPanel,
    required this.cartItemCount,
    required this.canProcessPayment,
  });

  final Widget orderPanel;
  final Widget checkoutPanel;
  final int cartItemCount;
  final bool canProcessPayment;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: _posAccentSurface(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              padding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: AppColors.white,
              unselectedLabelColor: const Color(0xFF5E6D82),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: 'Order ($cartItemCount)'),
                Tab(text: canProcessPayment ? 'Checkout Ready' : 'Checkout'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: TabBarView(children: [orderPanel, checkoutPanel])),
        ],
      ),
    );
  }
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
    required this.amountFocusNode,
    required this.selectedPaymentMethod,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.taxLabel,
    required this.balance,
    required this.canProcessPayment,
    required this.isProcessing,
    required this.isOpeningCustomerDialog,
    required this.onPaymentMethodChanged,
    required this.onAmountChanged,
    required this.onCustomerChanged,
    required this.onCustomerTapped,
    required this.onCustomerSelected,
    required this.onResetCustomer,
    required this.onProcessPayment,
  });

  final TextEditingController customerController;
  final FocusNode customerFocusNode;
  final List<PosCustomerOption> customerSuggestions;
  final bool showCustomerSuggestions;
  final bool isCustomerLoading;
  final PosCustomerOption selectedCustomer;
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final PosPaymentMethod selectedPaymentMethod;
  final double subtotal;
  final double tax;
  final double total;
  final String? taxLabel;
  final double balance;
  final bool canProcessPayment;
  final bool isProcessing;
  final bool isOpeningCustomerDialog;
  final ValueChanged<PosPaymentMethod> onPaymentMethodChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCustomerTapped;
  final ValueChanged<String> onCustomerChanged;
  final ValueChanged<PosCustomerOption> onCustomerSelected;
  final VoidCallback onResetCustomer;
  final VoidCallback onProcessPayment;

  @override
  Widget build(BuildContext context) {
    final hasShortPayment = subtotal > 0 && balance < 0;
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryTeal,
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
                                    label: 'UPI',
                                    icon: Icons.account_balance_wallet_outlined,
                                    isSelected:
                                        selectedPaymentMethod ==
                                        PosPaymentMethod.upi,
                                    onTap: () => onPaymentMethodChanged(
                                      PosPaymentMethod.upi,
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
                                label: 'UPI',
                                icon: Icons.account_balance_wallet_outlined,
                                isSelected:
                                    selectedPaymentMethod ==
                                    PosPaymentMethod.upi,
                                onTap: () => onPaymentMethodChanged(
                                  PosPaymentMethod.upi,
                                ),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
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
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final PosCatalogItem product;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Rs ${product.sellingPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryTeal,
                                ),
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
                        'Rs ${product.sellingPrice.toStringAsFixed(2)}',
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
          color: isSelected ? AppColors.primaryTeal : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : const Color(0xFFE1E8F1),
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
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 16),
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
