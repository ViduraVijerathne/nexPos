import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/setup/services/setup_service.dart';

enum ChangeLogEntityType { product, stock, grn, expense }

class ChangeLogService {
  ChangeLogService._();

  static final ChangeLogService instance = ChangeLogService._();

  static const String _localLogsPref = 'maintenance_change_logs';
  static const int _maxLocalLogs = 500;

  Future<void> logChange({
    required ChangeLogEntityType entityType,
    required String entityId,
    required String action,
    required String title,
    required Map<String, dynamic> details,
  }) async {
    final state = await SetupService.instance.loadState();
    final timestamp = DateTime.now();
    final payload = <String, dynamic>{
      'entityType': entityType.name,
      'entityId': entityId,
      'action': action,
      'title': title,
      'details': details,
      'createdAt': timestamp.toIso8601String(),
    };

    if (state.mode == AppMode.online &&
        state.selectedShopId.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(state.selectedShopId.trim())
          .collection('change_logs')
          .add({...payload, 'createdAt': timestamp});
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localLogsPref);
    final logs = raw == null || raw.trim().isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List<dynamic>).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );
    logs.insert(0, payload);
    if (logs.length > _maxLocalLogs) {
      logs.removeRange(_maxLocalLogs, logs.length);
    }
    await prefs.setString(_localLogsPref, jsonEncode(logs));
  }
}
