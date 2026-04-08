import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'isar_schemas.dart';

class AppDatabase {
  AppDatabase._();

  static const String _databaseName = 'nex_pos_db';
  static Future<Isar>? _openFuture;

  static Future<Isar> get instance {
    final existing = Isar.getInstance(_databaseName);
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
      name: _databaseName,
      inspector: false,
    );
  }
}
