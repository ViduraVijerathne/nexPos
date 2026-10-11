import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:isar/isar.dart';

Future<void> initializeTestIsar() async {
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
}
