import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'isar_schemas.dart';

class AppDatabase {
  AppDatabase._();

  static const String databaseName = 'nex_pos_db2';
  static Future<Isar>? _openFuture;

  static Future<Isar> get instance {
    final existing = Isar.getInstance(databaseName);
    if (existing != null) {
      return Future<Isar>.value(existing);
    }

    return _openFuture ??= _open();
  }

  static Future<Isar> _open() async {
    final directory = await getApplicationSupportDirectory();

    return Isar.open(
      appIsarSchemas,
      directory: directory.path,
      name: databaseName,
      inspector: false,
    );
  }

  static Future<String> getSupportDirectoryPath() async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  static Future<String> getDatabaseFilePath() async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/$databaseName.isar';
  }

  static Future<void> close() async {
    final existing = Isar.getInstance(databaseName);
    if (existing != null) {
      await existing.close();
    }
    _openFuture = null;
  }
}
