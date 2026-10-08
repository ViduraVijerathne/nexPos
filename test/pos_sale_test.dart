import 'dart:io';
import 'helpers/isar_test_support.dart';
import 'package:nex_pos_desktop/features/dashboard/data/stock_local_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nex_pos_desktop/features/dashboard/data/grn_local_repository.dart';
import 'package:nex_pos_desktop/core/database/app_database.dart';
import 'package:nex_pos_desktop/core/database/entities/entities.dart';
import 'package:nex_pos_desktop/core/database/isar_schemas.dart';
import 'package:nex_pos_desktop/features/dashboard/data/pos_local_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/pos_remote_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/data/pos_repository.dart';
import 'package:nex_pos_desktop/features/dashboard/models/models.dart';

PosCartItem _item({int quantity = 1, double price = 10}) => PosCartItem(
  stockId: 1,
  stockCloudId: 'stock-1',
  stockBarcode: 'stock-1',
  productBarcode: 'product-1',
  productName: 'Test product',
  category: 'Test',
  retailPrice: 10,
  wholesalePrice: 10,
  unitPrice: price,
  availableQty: 5,
  quantity: quantity,
);

Future<PosCheckoutResult> _sell(
  PosRepository repository, {
  List<PosCartItem>? items,
  double paid = 10,
  double cash = 10,
  double card = 0,
  double discount = 0,
  double tax = 0,
}) => repository.processSale(
  items: items ?? [_item()],
  customer: PosLocalRepository.walkInCustomer,
  paymentMethod: 'Cash',
  amountPaid: paid,
  cashPaidAmount: cash,
  cardPaidAmount: card,
  cashierName: 'Test',
  discountAmount: discount,
  taxAmount: tax,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final repository in <PosRepository>[
    const PosLocalRepository(),
    PosRemoteRepository(shopId: 'test'),
  ]) {
    final rejectsSale = repository is PosLocalRepository
        ? throwsA(isA<PosLocalRepositoryException>())
        : throwsA(isA<PosRemoteRepositoryException>());
    group('${repository.runtimeType} payment validation', () {
      test('rejects non-finite and negative payments', () async {
        for (final value in [double.nan, double.infinity, -1.0]) {
          await expectLater(
            _sell(repository, paid: value, cash: value),
            rejectsSale,
          );
          await expectLater(_sell(repository, card: value), rejectsSale);
          await expectLater(_sell(repository, discount: value), rejectsSale);
          await expectLater(_sell(repository, tax: value), rejectsSale);
        }
      });
      test(
        'rejects mismatched totals, card overpayment and underpayment',
        () async {
          await expectLater(_sell(repository, paid: 20), rejectsSale);
          await expectLater(
            _sell(repository, paid: 20, cash: 0, card: 20),
            rejectsSale,
          );
          await expectLater(_sell(repository, paid: 5, cash: 5), rejectsSale);
        },
      );
      test('rejects invalid cart quantities and prices', () async {
        for (final item in [
          _item(quantity: 0),
          _item(quantity: -1),
          _item(price: double.nan),
          _item(price: double.infinity),
          _item(price: -1),
        ]) {
          await expectLater(_sell(repository, items: [item]), rejectsSale);
        }
      });
    });
  }

  group('offline sale transactions', () {
    late Isar isar;
    late Directory directory;
    setUpAll(initializeTestIsar);
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      directory = await Directory.systemTemp.createTemp('nexpos-sale-test-');
      isar = await Isar.open(
        appIsarSchemas,
        directory: directory.path,
        name: AppDatabase.databaseName,
        inspector: false,
      );
      final stock = StockEntity()
        ..id = 1
        ..barcode = 'stock-1'
        ..productName = 'Test product'
        ..initialQuantity = 5
        ..availableQuantity = 5
        ..buyingPrice = 5
        ..sellingPrice = 10
        ..maxDiscount = 0
        ..status = StockEntityStatus.active
        ..createdAt = DateTime.now();
      await isar.writeTxn(() => isar.stockEntitys.put(stock));
    });
    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await directory.delete(recursive: true);
    });

    test(
      'concurrent stock creation rejects duplicate barcode without replacement',
      () async {
        const record = StockRecord(
          barcode: 'new-stock',
          product: 'Test product',
          initialQty: 8,
          availableQty: 8,
          buyingPrice: 5,
          sellingPrice: 10,
          maxDiscount: 0,
          status: StockStatus.active,
          grnId: 'Not Assigned',
        );
        final results = await Future.wait<Object?>([
          for (var i = 0; i < 2; i++)
            const StockLocalRepository()
                .saveStock(record)
                .then<Object?>(
                  (value) => value,
                  onError: (Object error) => error,
                ),
        ]);
        expect(results.whereType<StockRecord>(), hasLength(1));
        expect(
          results.whereType<StockLocalRepositoryException>(),
          hasLength(1),
        );
        expect(await isar.stockEntitys.count(), 2);
        expect((await isar.stockEntitys.get(1))!.availableQuantity, 5);
      },
    );
    test('saving a deleted stock does not recreate it', () async {
      final record = (await const StockLocalRepository().fetchStockById(1))!;
      await isar.writeTxn(() => isar.stockEntitys.delete(1));
      await expectLater(
        const StockLocalRepository().saveStock(record),
        throwsA(isA<StockLocalRepositoryException>()),
      );
      expect(await isar.stockEntitys.count(), 0);
    });
    test(
      'deactivation cannot restore stock consumed by a concurrent sale',
      () async {
        final results = await Future.wait<Object?>([
          _sell(
            const PosLocalRepository(),
          ).then<Object?>((value) => value, onError: (Object error) => error),
          const StockLocalRepository().deactivateStockById(1),
        ]);
        final sold = results.first is PosCheckoutResult;
        final stock = (await isar.stockEntitys.get(1))!;
        expect(stock.availableQuantity, sold ? 4 : 5);
        expect(stock.status, StockEntityStatus.inactive);
        expect(await isar.invoiceEntitys.count(), sold ? 1 : 0);
      },
    );
    test(
      'concurrent sales retain both invoices and stock deductions',
      () async {
        final results = await Future.wait([
          _sell(const PosLocalRepository()),
          _sell(const PosLocalRepository()),
        ]);
        expect(results.map((result) => result.invoiceNumber).toSet().length, 2);
        expect(await isar.invoiceEntitys.count(), 2);
        expect((await isar.stockEntitys.get(1))!.availableQuantity, 3);
      },
    );
    test(
      'duplicate cart lines cannot oversell and leave database unchanged',
      () async {
        await expectLater(
          _sell(
            const PosLocalRepository(),
            items: [_item(quantity: 3), _item(quantity: 3)],
            paid: 60,
            cash: 60,
          ),
          throwsA(isA<PosLocalRepositoryException>()),
        );
        expect((await isar.stockEntitys.get(1))!.availableQuantity, 5);
        expect(await isar.invoiceEntitys.count(), 0);
      },
    );
    test('concurrent sales cannot sell more stock than available', () async {
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          _sell(
            const PosLocalRepository(),
            items: [_item(quantity: 3)],
            paid: 30,
            cash: 30,
          ).then<Object>((result) => result, onError: (Object error) => error),
      ]);
      expect(results.whereType<PosCheckoutResult>().length, 1);
      expect(results.whereType<PosLocalRepositoryException>().length, 1);
      expect((await isar.stockEntitys.get(1))!.availableQuantity, 2);
      expect(await isar.invoiceEntitys.count(), 1);
    });
    test(
      'valid mixed payment returns change and saves tendered amounts',
      () async {
        final result = await _sell(
          const PosLocalRepository(),
          paid: 15,
          cash: 10,
          card: 5,
        );
        expect(result.changeAmount, 5);
        final invoice = (await isar.invoiceEntitys.where().findAll()).single;
        expect(invoice.cashPaidAmount, 10);
        expect(invoice.cardPaidAmount, 5);
        expect(invoice.totalAmount, 10);
      },
    );
    test('decimal prices accept exact cash rounded to cents', () async {
      final result = await _sell(
        const PosLocalRepository(),
        items: [_item(quantity: 3, price: 0.1)],
        paid: 0.3,
        cash: 0.3,
      );
      expect(result.changeAmount, 0);
      final invoice = (await isar.invoiceEntitys.where().findAll()).single;
      expect(invoice.totalAmount, 0.3);
    });
    test(
      'concurrent supplier payments cannot overwrite history or overpay',
      () async {
        final grn = GrnEntity()
          ..code = 'GRN-1'
          ..supplierName = 'Supplier'
          ..date = DateTime.now()
          ..subTotal = 100
          ..discount = 0
          ..paidAmount = 0
          ..paymentMethod = 'Cash'
          ..createdAt = DateTime.now();
        await isar.writeTxn(() => isar.grnEntitys.put(grn));
        final results = await Future.wait([
          for (var i = 0; i < 2; i++)
            const GrnLocalRepository()
                .recordDuePayment(grnId: 'GRN-1', amount: 60, method: 'Cash')
                .then<Object?>(
                  (result) => result,
                  onError: (Object error) => error,
                ),
        ]);
        expect(results.whereType<GrnRecord>().length, 1);
        expect(results.whereType<GrnLocalRepositoryException>().length, 1);
        final saved = (await isar.grnEntitys.where().findAll()).single;
        expect(saved.paidAmount, 60);
        expect(saved.paymentHistory.length, 1);
      },
    );
    test(
      'adding pending GRN stock cannot replace existing sold stock',
      () async {
        final line = GrnItemEmbedded()
          ..productName = 'Product'
          ..stockBarcode = 'stock-1'
          ..quantity = 10
          ..buyingPrice = 5
          ..sellingPrice = 10;
        final grn = GrnEntity()
          ..code = 'GRN-1'
          ..supplierName = 'Supplier'
          ..date = DateTime.now()
          ..subTotal = 50
          ..discount = 0
          ..paidAmount = 0
          ..paymentMethod = 'Cash'
          ..createdAt = DateTime.now()
          ..items = [line];
        await isar.writeTxn(() => isar.grnEntitys.put(grn));
        await expectLater(
          const GrnLocalRepository().addPendingItemsToStock('GRN-1'),
          throwsA(isA<GrnLocalRepositoryException>()),
        );
        expect((await isar.stockEntitys.get(1))!.availableQuantity, 5);
        expect(
          (await isar.grnEntitys.get(grn.id))!.items.single.inStock,
          isFalse,
        );
      },
    );
  });
}
