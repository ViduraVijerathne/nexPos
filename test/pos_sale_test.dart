import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
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
    setUpAll(() async {
      final configFile = File('.dart_tool/package_config.json').absolute;
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final package = (config['packages'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((entry) => entry['name'] == 'isar_flutter_libs');
      final rootUri = package['rootUri'] as String;
      final root = configFile.uri.resolve(
        rootUri.endsWith('/') ? rootUri : '$rootUri/',
      );
      final library = Platform.isWindows
          ? 'windows/isar.dll'
          : Platform.isMacOS
          ? 'macos/libisar.dylib'
          : 'linux/libisar.so';
      await Isar.initializeIsarCore(
        libraries: {Abi.current(): root.resolve(library).toFilePath()},
      );
    });
    setUp(() async {
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
  });
}
