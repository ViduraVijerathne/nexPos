import 'dart:io';
import 'dart:typed_data';

import 'package:isar/isar.dart';

/// Stage and validate a backup before closing or replacing the live database.
Future<void> restoreDatabaseFile({
  required File source,
  required File target,
  required List<CollectionSchema> schemas,
  required Future<void> Function() closeDatabase,
}) async {
  // Isar/MDBX backups contain database pages, not a short text/empty file.
  // Opening a truncated file can otherwise initialize a new empty database.
  if (await source.length() < 4096) {
    throw const FormatException('Backup file is empty or truncated');
  }
  final handle = await source.open();
  try {
    final header = await handle.read(28);
    // MDBX v0.12.4: 20-byte page header followed by magic/version.
    // https://github.com/isar/libmdbx/blob/v0.12.4/src/internals.h
    final magic = ByteData.sublistView(header).getUint64(20, Endian.little);
    if ((magic & 0xffffffffffffff00) != 0x59659dbdef4c1100 ||
        !const {2, 3, 66, 67}.contains(magic & 0xff)) {
      throw const FormatException(
        'Selected file is not an Isar database backup',
      );
    }
  } finally {
    await handle.close();
  }
  await target.parent.create(recursive: true);
  final staging = await target.parent.createTemp('.nexpos-restore-');
  final staged = File('${staging.path}/restore_check.isar');
  final previous = File('${staging.path}/previous.isar');
  var movedPrevious = false;
  try {
    await source.copy(staged.path);
    // A truncated or incompatible backup must leave the live DB untouched.
    final check = await Isar.open(
      schemas,
      directory: staging.path,
      name: 'restore_check',
      inspector: false,
    );
    await check.close();
    await closeDatabase();
    if (await target.exists()) {
      await target.rename(previous.path);
      movedPrevious = true;
    }
    try {
      await staged.rename(target.path);
    } catch (_) {
      if (movedPrevious) await previous.rename(target.path);
      rethrow;
    }
  } finally {
    // Never remove the only recoverable copy after a failed rollback.
    if (!await previous.exists() || await target.exists()) {
      await staging.delete(recursive: true);
    }
  }
}
