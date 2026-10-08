import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nex_pos_desktop/features/dashboard/data/customer_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/expense_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/invoice_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/pos_local_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/pos_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/models/models.dart';
import 'package:nex_pos_desktop/features/dashboard/presentation/pages/pos_page.dart';
import 'package:nex_pos_desktop/features/settings/services/app_settings_service.dart';

class _Customers implements CustomerRepository {
  @override
  Future<void> initialize() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Invoices implements InvoiceRepository {
  @override
  Future<void> initialize() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Expenses implements ExpenseRepository {
  @override
  Future<void> initialize() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pos implements PosRepository {
  bool failLookup = false;
  int quantity = 5;
  int soldQuantity = 0;
  int customerSearches = 0;
  Completer<PosCheckoutResult>? pendingSale;
  @override
  void invalidateCatalog() {}
  @override
  Future<void> initialize() async {}
  @override
  Future<PosCatalogResult> fetchCatalog({
    String? searchQuery,
    String? category,
    PosCatalogLoadMode loadMode = PosCatalogLoadMode.defaultOrder,
  }) async {
    final matches =
        (searchQuery ?? '').isEmpty ||
        'test tea'.contains(searchQuery!.toLowerCase());
    return PosCatalogResult(
      items: matches && quantity > 0
          ? [
              PosCatalogItem(
                stockId: 1,
                stockCloudId: null,
                stockBarcode: 'stock-1',
                productName: 'Test Tea',
                productBarcode: 'tea',
                category: 'Drinks',
                availableQty: quantity,
                retailPrice: 10,
                wholesalePrice: 8,
              ),
            ]
          : [],
      categories: const ['All', 'Drinks'],
    );
  }

  @override
  Future<PosCatalogItem?> findExactCatalogMatch(String value) async {
    if (failLookup) throw StateError('Network unavailable');
    return value == 'tea' || value == 'tea-code'
        ? (await fetchCatalog()).items.first
        : null;
  }

  @override
  Future<List<PosCustomerOption>> searchCustomers(String query) async {
    customerSearches++;
    return [PosLocalRepository.walkInCustomer];
  }

  @override
  Future<PosCheckoutResult> processSale({
    required List<PosCartItem> items,
    required PosCustomerOption customer,
    required String paymentMethod,
    required double amountPaid,
    required double cashPaidAmount,
    required double cardPaidAmount,
    required String cashierName,
    required double discountAmount,
    required double taxAmount,
  }) async {
    soldQuantity += items.fold<int>(0, (sum, item) => sum + item.quantity);
    quantity -= soldQuantity;
    return pendingSale?.future ??
        const PosCheckoutResult(invoiceNumber: 'INV-000001', changeAmount: 0);
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Pos repository, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    SharedPreferences.setMockInitialValues({
      'settings.pos_invoice_print_mode': 'none',
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: PosPage(
            repository: repository,
            customerRepository: _Customers(),
            invoiceRepository: _Invoices(),
            expenseRepository: _Expenses(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('billing fits phone, tablet, desktop and large text layouts', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Pos();
    await open(tester, repository);
    await tester.tap(find.byKey(const ValueKey('product-1')));
    await tester.pumpAndSettle();
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(640, 360),
      const Size(800, 600),
      const Size(1024, 768),
      const Size(1440, 900),
      const Size(1920, 1080),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Products at $size');
      if (size.width < 860) {
        await tester.tap(find.widgetWithText(Tab, 'Checkout'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Checkout at $size');
        await tester.tap(find.widgetWithText(Tab, 'Products'));
        await tester.pumpAndSettle();
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    final handler = FlutterError.onError;
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      handler?.call(details);
    };
    await open(tester, _Pos(), size: const Size(320, 568), textScale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(Tab, 'Checkout'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    FlutterError.onError = handler;
  });
  testWidgets(
    'repeated adds use full stock capacity; exact cash completes a bill',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Pos();
      await open(tester, repository);
      expect(repository.customerSearches, 0);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('product-1')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Cart (5)'), findsOneWidget);
      expect(find.byKey(const ValueKey('product-1')), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pos-exact-cash')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pos-process-payment')));
      await tester.pumpAndSettle();
      expect(repository.soldQuantity, 5);
      expect(find.text('Cart (0)'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed barcode lookup leaves cart intact and can be retried', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Pos()..failLookup = true;
    await open(tester, repository);
    await tester.enterText(
      find.byKey(const ValueKey('pos-product-search')),
      'tea-code',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cart (0)'), findsOneWidget);
    repository.failLookup = false;
    await tester.enterText(
      find.byKey(const ValueKey('pos-product-search')),
      'tea-code',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Cart (1)'), findsOneWidget);
  });
  testWidgets('unknown barcode cannot add the highlighted unrelated item', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, _Pos());
    await tester.enterText(
      find.byKey(const ValueKey('pos-product-search')),
      'unknown-barcode',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Cart (0)'), findsOneWidget);
  });
  testWidgets('name submission immediately refreshes the filtered catalog', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, _Pos());
    await tester.enterText(
      find.byKey(const ValueKey('pos-product-search')),
      'unknown',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(const ValueKey('pos-product-search')),
      'tea',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Cart (1)'), findsOneWidget);
  });
  testWidgets('checkout prevents duplicate submission while saving', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Pos()..pendingSale = Completer<PosCheckoutResult>();
    await open(tester, repository);
    await tester.tap(find.byKey(const ValueKey('product-1')));
    await tester.tap(find.widgetWithText(Tab, 'Checkout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pos-exact-cash')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pos-process-payment')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('pos-process-payment')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repository.soldQuantity, 1);
    repository.pendingSale!.complete(
      const PosCheckoutResult(invoiceNumber: 'INV-1', changeAmount: 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cart (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('new transaction confirms before discarding an unpaid bill', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, _Pos());
    await tester.tap(find.byKey(const ValueKey('product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this bill?'), findsOneWidget);
    await tester.tap(find.text('Keep bill'));
    await tester.pumpAndSettle();
    expect(find.text('Cart (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('New transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Cart (0)'), findsOneWidget);
  });
}
