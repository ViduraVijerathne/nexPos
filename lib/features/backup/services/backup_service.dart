import 'dart:convert';
import 'dart:io';
//admin
// $2y$10$I23Io8.4YzMmTVlLGzMB8OQwsfXFPo1NeAJzVSazpRAEBNoNwZ7Fa

//old
// $2y$10$tO.M10QTDvQAsmmZoNqtbu55cHr/fSh80QhhP3/6e.T...
// $2y$10$tO.M10QTDvQAsmmZoNqtbu55cHr/fSh80QhhP3/6e.Tx8UuH4NVeO
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../activation/services/activation_service.dart';
import '../../setup/services/setup_service.dart';

class BackupRecord {
  const BackupRecord({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    required this.status,
    required this.type,
  });

  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;
  final String status;
  final String type;

  String get formattedSize {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes B';
  }

  String get formattedDateTime {
    final year = createdAt.year.toString().padLeft(4, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'status': status,
    'type': type,
  };

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    return BackupRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      status: json['status'] as String? ?? 'Completed',
      type: json['type'] as String? ?? 'Database Backup',
    );
  }
}

class BackupState {
  const BackupState({required this.records, required this.backupOnLogin});

  final List<BackupRecord> records;
  final bool backupOnLogin;

  int get totalBackups => records.length;

  int get totalSizeBytes =>
      records.fold<int>(0, (sum, record) => sum + record.sizeBytes);

  BackupRecord? get latestBackup => records.isEmpty ? null : records.first;
}

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const _recordsPref = 'backup_records_v1';
  static const _backupOnLoginPref = 'backup_on_every_login';

  Future<BackupState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsPref);
    final decoded = raw == null || raw.isEmpty
        ? const <dynamic>[]
        : jsonDecode(raw) as List<dynamic>;
    final records =
        decoded
            .whereType<Map<String, dynamic>>()
            .map(BackupRecord.fromJson)
            .where((record) => File(record.filePath).existsSync())
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    return BackupState(
      records: records,
      backupOnLogin: prefs.getBool(_backupOnLoginPref) ?? false,
    );
  }

  Future<void> setBackupOnLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupOnLoginPref, value);
  }

  Future<BackupRecord> createBackup({
    String type = 'Database Backup',
    String? name,
  }) async {
    final isar = await AppDatabase.instance;
    final supportDirectoryPath = await AppDatabase.getSupportDirectoryPath();
    final backupsDirectory = Directory('$supportDirectoryPath/backups');
    if (!await backupsDirectory.exists()) {
      await backupsDirectory.create(recursive: true);
    }

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final backupFile = File('${backupsDirectory.path}/backup_$id.isar');
    final stateFile = File('${backupsDirectory.path}/backup_$id.state.json');

    await isar.copyToFile(backupFile.path);

    final setupState = await SetupService.instance.exportState();
    final activationState = await ActivationService.instance.exportState();
    final backupState = <String, dynamic>{
      'setup': setupState,
      'activation': activationState,
    };
    await stateFile.writeAsString(jsonEncode(backupState));

    final sizeBytes = await backupFile.length();
    final record = BackupRecord(
      id: id,
      name: name ?? type,
      filePath: backupFile.path,
      createdAt: now,
      sizeBytes: sizeBytes,
      status: 'Completed',
      type: type,
    );

    final currentState = await loadState();
    final updatedRecords = <BackupRecord>[record, ...currentState.records];
    await _persistRecords(updatedRecords);
    return record;
  }

  Future<BackupRecord?> createBackupIfEnabled() async {
    final state = await loadState();
    if (!state.backupOnLogin) {
      return null;
    }
    return createBackup(type: 'Login Backup');
  }

  Future<void> restoreBackup(BackupRecord record) async {
    final backupFile = File(record.filePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    final dbFilePath = await AppDatabase.getDatabaseFilePath();
    final dbFile = File(dbFilePath);
    final stateFile = File(
      record.filePath.replaceFirst('.isar', '.state.json'),
    );

    await AppDatabase.close();
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await backupFile.copy(dbFile.path);

    if (await stateFile.exists()) {
      final decoded =
          jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
      final setup = decoded['setup'];
      final activation = decoded['activation'];
      if (setup is Map<String, dynamic>) {
        await SetupService.instance.importState(setup);
      }
      if (activation is Map<String, dynamic>) {
        await ActivationService.instance.importState(activation);
      }
    }
  }

  Future<void> restoreFromExternalFile(String filePath) async {
    final externalFile = File(filePath);
    if (!await externalFile.exists()) {
      throw Exception('Selected backup file not found');
    }

    final dbFilePath = await AppDatabase.getDatabaseFilePath();
    final dbFile = File(dbFilePath);

    await AppDatabase.close();
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await externalFile.copy(dbFile.path);

    final externalStateFile = File(
      filePath.endsWith('.isar')
          ? filePath.replaceFirst('.isar', '.state.json')
          : '$filePath.state.json',
    );
    if (await externalStateFile.exists()) {
      final decoded =
          jsonDecode(await externalStateFile.readAsString())
              as Map<String, dynamic>;
      final setup = decoded['setup'];
      final activation = decoded['activation'];
      if (setup is Map<String, dynamic>) {
        await SetupService.instance.importState(setup);
      }
      if (activation is Map<String, dynamic>) {
        await ActivationService.instance.importState(activation);
      }
    }
  }

  Future<String?> pickAndRestoreBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['isar'],
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      return null;
    }
    await restoreFromExternalFile(selectedPath);
    return selectedPath;
  }

  Future<String?> exportBackup(BackupRecord record) async {
    final sourceFile = File(record.filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Backup file not found');
    }

    final targetPath = await FilePicker.saveFile(
      dialogTitle: 'Export Backup',
      fileName: 'nexpos_backup_${record.id}.isar',
    );
    if (targetPath == null || targetPath.isEmpty) {
      return null;
    }

    await sourceFile.copy(targetPath);
    final sourceStateFile = File(
      record.filePath.replaceFirst('.isar', '.state.json'),
    );
    if (await sourceStateFile.exists()) {
      final targetStateFile = File(
        targetPath.endsWith('.isar')
            ? targetPath.replaceFirst('.isar', '.state.json')
            : '$targetPath.state.json',
      );
      await sourceStateFile.copy(targetStateFile.path);
    }
    return targetPath;
  }

  Future<void> _persistRecords(List<BackupRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      records.map((record) => record.toJson()).toList(),
    );
    await prefs.setString(_recordsPref, encoded);
  }
}
