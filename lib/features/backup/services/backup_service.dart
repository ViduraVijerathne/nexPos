import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
//admin
// $2y$10$I23Io8.4YzMmTVlLGzMB8OQwsfXFPo1NeAJzVSazpRAEBNoNwZ7Fa

//old
// $2y$10$tO.M10QTDvQAsmmZoNqtbu55cHr/fSh80QhhP3/6e.T...
// $2y$10$tO.M10QTDvQAsmmZoNqtbu55cHr/fSh80QhhP3/6e.Tx8UuH4NVeO
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_restore.dart';
import '../../../core/database/isar_schemas.dart';
import '../../activation/services/activation_service.dart';
import '../../setup/services/setup_service.dart';
import '../../subscription/services/subscription_usage_service.dart';

class BackupRecord {
  const BackupRecord({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    required this.status,
    required this.type,
    this.storage = BackupStorage.local,
  });

  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;
  final int sizeBytes;
  final String status;
  final String type;
  final BackupStorage storage;

  bool get isRemote => storage == BackupStorage.remote;
  bool get isLocal => storage == BackupStorage.local;

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
    'storage': storage.name,
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
      storage: BackupStorage.values.firstWhere(
        (item) => item.name == (json['storage'] as String? ?? ''),
        orElse: () => BackupStorage.local,
      ),
    );
  }
}

enum BackupStorage { local, remote }

class BackupState {
  const BackupState({
    required this.records,
    required this.backupOnLogin,
    required this.mode,
  });

  final List<BackupRecord> records;
  final bool backupOnLogin;
  final AppMode? mode;

  bool get isOnlineMode => mode == AppMode.online;

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
  static const List<String> _onlineCollections = <String>[
    'products',
    'categories',
    'suppliers',
    'customers',
    'expenses',
    'grns',
    'stocks',
    'invoices',
    'change_logs',
  ];

  Future<BackupState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final setupState = await SetupService.instance.loadState();
    if (setupState.mode == AppMode.online &&
        setupState.selectedShopId.trim().isNotEmpty) {
      final records = await _loadRemoteRecords(
        setupState.selectedShopId.trim(),
      );
      return BackupState(
        records: records,
        backupOnLogin: prefs.getBool(_backupOnLoginPref) ?? false,
        mode: setupState.mode,
      );
    }

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
      mode: setupState.mode,
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
    final setupState = await SetupService.instance.loadState();
    if (setupState.mode == AppMode.online &&
        setupState.selectedShopId.trim().isNotEmpty) {
      return _createRemoteBackup(
        shopId: setupState.selectedShopId.trim(),
        type: type,
        name: name,
      );
    }

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

    final exportedSetupState = await SetupService.instance.exportState();
    final activationState = await ActivationService.instance.exportState();
    final backupState = <String, dynamic>{
      'setup': exportedSetupState,
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
      storage: BackupStorage.local,
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
    if (record.isRemote) {
      await _restoreRemoteBackup(record);
      return;
    }

    await restoreFromExternalFile(record.filePath);
  }

  String _stateFilePath(String path) => path.endsWith('.isar')
      ? '${path.substring(0, path.length - 5)}.state.json'
      : '$path.state.json';

  Future<void> restoreFromExternalFile(String filePath) async {
    final source = File(filePath);
    if (!await source.exists())
      throw Exception('Selected backup file not found');
    final stateFile = File(_stateFilePath(filePath));
    Map<String, dynamic>? state;
    // Parse companion data before any live database mutation.
    if (await stateFile.exists()) {
      state =
          jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    }
    await restoreDatabaseFile(
      source: source,
      target: File(await AppDatabase.getDatabaseFilePath()),
      schemas: appIsarSchemas,
      closeDatabase: AppDatabase.close,
    );
    final setup = state?['setup'];
    final activation = state?['activation'];
    if (setup is Map<String, dynamic>)
      await SetupService.instance.importState(setup);
    if (activation is Map<String, dynamic>)
      await ActivationService.instance.importState(activation);
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
    if (record.isRemote) {
      throw Exception('Cloud snapshots cannot be exported as local files');
    }

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
    final sourceStateFile = File(_stateFilePath(record.filePath));
    if (await sourceStateFile.exists()) {
      final targetStateFile = File(_stateFilePath(targetPath));
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

  Future<List<BackupRecord>> _loadRemoteRecords(String shopId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('backups')
        .orderBy('createdAt', descending: true)
        .get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'backups',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((doc) => doc.data()).toList(),
    );

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final createdAt = _readDateTime(data['createdAt']);
      return BackupRecord(
        id: doc.id,
        name: data['name']?.toString() ?? 'Cloud Shop Snapshot',
        filePath: 'remote://$shopId/${doc.id}',
        createdAt: createdAt,
        sizeBytes: (data['sizeBytes'] as num?)?.round() ?? 0,
        status: data['status']?.toString() ?? 'Completed',
        type: data['type']?.toString() ?? 'Cloud Shop Snapshot',
        storage: BackupStorage.remote,
      );
    }).toList();
  }

  Future<BackupRecord> _createRemoteBackup({
    required String shopId,
    required String type,
    String? name,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final shopRef = firestore.collection('shops').doc(shopId);
    final backupRef = shopRef.collection('backups').doc();
    final now = DateTime.now();

    final shopSnapshot = await shopRef.get();
    final shopData = shopSnapshot.data() ?? <String, dynamic>{};
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'backups',
      documentCount: shopSnapshot.exists ? 1 : 0,
      payload: shopData,
    );

    final collectionSnapshots = <String, QuerySnapshot<Map<String, dynamic>>>{};
    var totalBytes = _jsonSize(shopData);
    var totalDocuments = 0;

    for (final collectionName in _onlineCollections) {
      final snapshot = await shopRef.collection(collectionName).get();
      await SubscriptionUsageService.instance.recordRead(
        shopId: shopId,
        module: 'backups',
        documentCount: snapshot.docs.length,
        payload: snapshot.docs.map((doc) => doc.data()).toList(),
      );
      collectionSnapshots[collectionName] = snapshot;
      totalDocuments += snapshot.docs.length;
      for (final doc in snapshot.docs) {
        totalBytes += _jsonSize(doc.data());
      }
    }

    await backupRef.set({
      'name': name ?? 'Cloud Shop Snapshot',
      'type': type,
      'status': 'Creating',
      'storage': BackupStorage.remote.name,
      'shopId': shopId,
      'createdAt': now,
      'sizeBytes': totalBytes,
      'totalDocuments': totalDocuments,
      'collectionNames': _onlineCollections,
      'shopData': shopData,
    });
    await SubscriptionUsageService.instance.recordWrite(
      shopId: shopId,
      module: 'backups',
      payload: <String, dynamic>{
        'backupId': backupRef.id,
        'type': type,
        'totalDocuments': totalDocuments,
        'sizeBytes': totalBytes,
      },
    );

    for (final entry in collectionSnapshots.entries) {
      await _copyCollectionSnapshotToBackup(
        backupRef: backupRef,
        collectionName: entry.key,
        snapshot: entry.value,
      );
    }

    await backupRef.update({'status': 'Completed'});

    return BackupRecord(
      id: backupRef.id,
      name: name ?? 'Cloud Shop Snapshot',
      filePath: 'remote://$shopId/${backupRef.id}',
      createdAt: now,
      sizeBytes: totalBytes,
      status: 'Completed',
      type: type,
      storage: BackupStorage.remote,
    );
  }

  Future<void> _copyCollectionSnapshotToBackup({
    required DocumentReference<Map<String, dynamic>> backupRef,
    required String collectionName,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
  }) async {
    var totalWrites = 0;
    for (var start = 0; start < snapshot.docs.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final end = math.min(start + 400, snapshot.docs.length);
      for (final doc in snapshot.docs.sublist(start, end)) {
        batch.set(
          backupRef.collection(collectionName).doc(doc.id),
          doc.data(),
          SetOptions(merge: false),
        );
      }
      await batch.commit();
      totalWrites += end - start;
    }
    if (totalWrites > 0) {
      await SubscriptionUsageService.instance.recordWrite(
        shopId: backupRef.parent.parent?.id ?? '',
        module: 'backups',
        documentCount: totalWrites,
        payload: <String, dynamic>{
          'backupId': backupRef.id,
          'collection': collectionName,
        },
      );
    }
  }

  Future<void> _restoreRemoteBackup(BackupRecord record) async {
    final setupState = await SetupService.instance.loadState();
    final shopId = setupState.selectedShopId.trim();
    if (shopId.isEmpty) {
      throw Exception('Online shop is not selected');
    }

    final firestore = FirebaseFirestore.instance;
    final shopRef = firestore.collection('shops').doc(shopId);
    final backupRef = shopRef.collection('backups').doc(record.id);
    final backupSnapshot = await backupRef.get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopId,
      module: 'backups',
      documentCount: backupSnapshot.exists ? 1 : 0,
      payload: backupSnapshot.data(),
    );
    if (!backupSnapshot.exists) {
      throw Exception('Cloud snapshot not found');
    }

    final backupData = backupSnapshot.data() ?? <String, dynamic>{};
    if (backupData['status'] != 'Completed') {
      throw Exception('Cloud snapshot is incomplete and cannot be restored');
    }
    // Read all source collections before altering any shop data.
    final sources = <String, QuerySnapshot<Map<String, dynamic>>>{};
    for (final collectionName in _onlineCollections) {
      final source = await backupRef.collection(collectionName).get();
      sources[collectionName] = source;
      await SubscriptionUsageService.instance.recordRead(
        shopId: shopId,
        module: 'backups',
        documentCount: source.docs.length,
        payload: source.docs.map((doc) => doc.data()).toList(),
      );
    }
    final shopData = backupData['shopData'];
    if (shopData is Map<String, dynamic>) {
      await shopRef.set(shopData, SetOptions(merge: true));
      await SubscriptionUsageService.instance.recordWrite(
        shopId: shopId,
        module: 'backups',
        payload: shopData,
      );
    }

    for (final collectionName in _onlineCollections) {
      await _replaceShopCollectionFromBackup(
        shopRef: shopRef,
        backupSnapshot: sources[collectionName]!,
        collectionName: collectionName,
      );
    }
  }

  Future<void> _replaceShopCollectionFromBackup({
    required DocumentReference<Map<String, dynamic>> shopRef,
    required QuerySnapshot<Map<String, dynamic>> backupSnapshot,
    required String collectionName,
  }) async {
    final targetSnapshot = await shopRef.collection(collectionName).get();
    await SubscriptionUsageService.instance.recordRead(
      shopId: shopRef.id,
      module: 'backups',
      documentCount: targetSnapshot.docs.length,
      payload: targetSnapshot.docs.map((doc) => doc.data()).toList(),
    );
    var deleteCount = 0;
    for (var start = 0; start < targetSnapshot.docs.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final end = math.min(start + 400, targetSnapshot.docs.length);
      for (final doc in targetSnapshot.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleteCount += end - start;
    }
    if (deleteCount > 0) {
      await SubscriptionUsageService.instance.recordDelete(
        shopId: shopRef.id,
        module: 'backups',
        documentCount: deleteCount,
        payload: <String, dynamic>{'collection': collectionName},
      );
    }

    var writeCount = 0;
    for (var start = 0; start < backupSnapshot.docs.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final end = math.min(start + 400, backupSnapshot.docs.length);
      for (final doc in backupSnapshot.docs.sublist(start, end)) {
        batch.set(shopRef.collection(collectionName).doc(doc.id), doc.data());
      }
      await batch.commit();
      writeCount += end - start;
    }
    if (writeCount > 0) {
      await SubscriptionUsageService.instance.recordWrite(
        shopId: shopRef.id,
        module: 'backups',
        documentCount: writeCount,
        payload: <String, dynamic>{'collection': collectionName},
      );
    }
  }

  DateTime _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  int _jsonSize(Map<String, dynamic> value) =>
      utf8.encode(jsonEncode(_normalizeForJson(value))).length;

  Object? _normalizeForJson(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is GeoPoint) {
      return <String, double>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is Iterable) {
      return value.map(_normalizeForJson).toList();
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _normalizeForJson(nestedValue)),
      );
    }
    return value.toString();
  }
}
