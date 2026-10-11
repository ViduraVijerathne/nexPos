import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:nex_pos_desktop/core/database/database_restore.dart';
import 'package:nex_pos_desktop/core/database/entities/entities.dart';
import 'helpers/isar_test_support.dart';

void main() {
  setUpAll(initializeTestIsar);
  late Directory directory;
  late Isar database;
  late File target;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nexpos-restore-test-');
    target = File('${directory.path}/live.isar');
    database = await Isar.open(
      [StockEntitySchema],
      directory: directory.path,
      name: 'live',
      inspector: false,
    );
    final stock = StockEntity()
      ..id = 1
      ..barcode = 'original'
      ..productName = 'Original product'
      ..initialQuantity = 5
      ..availableQuantity = 5
      ..buyingPrice = 1
      ..sellingPrice = 2
      ..maxDiscount = 0
      ..status = StockEntityStatus.active
      ..createdAt = DateTime.now();
    await database.writeTxn(() => database.stockEntitys.put(stock));
  });
  tearDown(() async {
    if (database.isOpen) await database.close();
    await directory.delete(recursive: true);
  });
  test(
    'invalid and empty backups leave live database open and intact',
    () async {
      for (final contents in ['', 'not an isar database', 'x' * 4096]) {
        final source = File('${directory.path}/invalid.isar');
        await source.writeAsString(contents);
        var closed = false;
        await expectLater(
          restoreDatabaseFile(
            source: source,
            target: target,
            schemas: [StockEntitySchema],
            closeDatabase: () async {
              closed = true;
              await database.close();
            },
          ),
          throwsA(anything),
        );
        expect(closed, isFalse);
        expect(database.isOpen, isTrue);
        expect((await database.stockEntitys.get(1))!.barcode, 'original');
      }
    },
  );
  test('valid backup restores records after staging and validation', () async {
    final source = File('${directory.path}/backup.isar');
    await database.copyToFile(source.path);
    await database.writeTxn(() => database.stockEntitys.delete(1));
    await restoreDatabaseFile(
      source: source,
      target: target,
      schemas: [StockEntitySchema],
      closeDatabase: () async {
        await database.close();
      },
    );
    database = await Isar.open(
      [StockEntitySchema],
      directory: directory.path,
      name: 'live',
      inspector: false,
    );
    expect((await database.stockEntitys.get(1))!.barcode, 'original');
    expect(await source.exists(), isTrue);
  });
  test('failure to close live database preserves the original file', () async {
    final source = File('${directory.path}/backup.isar');
    await database.copyToFile(source.path);
    await expectLater(
      restoreDatabaseFile(
        source: source,
        target: target,
        schemas: [StockEntitySchema],
        closeDatabase: () async => throw StateError('busy'),
      ),
      throwsStateError,
    );
    expect((await database.stockEntitys.get(1))!.barcode, 'original');
    expect(await target.exists(), isTrue);
  });
}
