import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivationBootState {
  const ActivationBootState({
    required this.deviceId,
    required this.isActivated,
  });

  final String deviceId;
  final bool isActivated;
}

class ActivationService {
  ActivationService._();

  static final ActivationService instance = ActivationService._();

  static const _activationKeyPref = 'activation_key';
  static const _deviceIdPref = 'device_id';
  static const _isActivatedPref = 'is_activated';

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  Future<ActivationBootState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();

    return ActivationBootState(
      deviceId: deviceId,
      isActivated: prefs.getBool(_isActivatedPref) ?? false,
    );
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_deviceIdPref);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final resolvedDeviceId = await _resolveStableDeviceId();
    await prefs.setString(_deviceIdPref, resolvedDeviceId);
    return resolvedDeviceId;
  }

  String buildActivationKey(String deviceId) {
    // Deterministic local key generation for now; can be replaced with API validation later.
    final normalized = deviceId.replaceAll('-', '').toUpperCase();
    final digest = sha256
        .convert(utf8.encode('NEXPOS::$normalized::2026'))
        .toString()
        .substring(0, 24)
        .toUpperCase();

    final chunks = <String>[];
    for (var index = 0; index < digest.length; index += 4) {
      chunks.add(digest.substring(index, index + 4));
    }
    return chunks.join('-');
  }

  Future<bool> activate(String enteredKey) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    final normalizedInput = _normalizeKey(enteredKey);
    final expectedKey = _normalizeKey(buildActivationKey(deviceId));

    if (normalizedInput != expectedKey) {
      return false;
    }

    await prefs.setString(_activationKeyPref, enteredKey.trim());
    await prefs.setBool(_isActivatedPref, true);
    return true;
  }

  Future<void> clearActivation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activationKeyPref);
    await prefs.remove(_isActivatedPref);
  }

  Future<Map<String, dynamic>> exportState() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, dynamic>{
      _activationKeyPref: prefs.getString(_activationKeyPref),
      _deviceIdPref: prefs.getString(_deviceIdPref),
      _isActivatedPref: prefs.getBool(_isActivatedPref) ?? false,
    };
  }

  Future<void> importState(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final activationKey = data[_activationKeyPref];
    final deviceId = data[_deviceIdPref];
    final isActivated = data[_isActivatedPref];

    if (activationKey is String && activationKey.isNotEmpty) {
      await prefs.setString(_activationKeyPref, activationKey);
    }
    if (deviceId is String && deviceId.isNotEmpty) {
      await prefs.setString(_deviceIdPref, deviceId);
    }
    if (isActivated is bool) {
      await prefs.setBool(_isActivatedPref, isActivated);
    }
  }

  String _normalizeKey(String value) =>
      value.replaceAll('-', '').replaceAll(' ', '').toUpperCase();

  Future<String> _resolveStableDeviceId() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          final info = await _deviceInfoPlugin.macOsInfo;
          final raw =
              info.systemGUID ??
              '${info.hostName}-${info.model}-${info.arch}-${info.memorySize}';
          return _formatDeviceId(_hash(raw));
        case TargetPlatform.windows:
          final info = await _deviceInfoPlugin.windowsInfo;
          return _formatDeviceId(_hash(info.deviceId));
        case TargetPlatform.linux:
          final info = await _deviceInfoPlugin.linuxInfo;
          final raw =
              info.machineId ?? '${info.name}-${info.id}-${info.prettyName}';
          return _formatDeviceId(_hash(raw));
        case TargetPlatform.android:
          final info = await _deviceInfoPlugin.androidInfo;
          final raw =
              '${info.id}-${info.board}-${info.model}-${info.brand}-${info.device}';
          return _formatDeviceId(_hash(raw));
        case TargetPlatform.iOS:
          final info = await _deviceInfoPlugin.iosInfo;
          final raw =
              '${info.identifierForVendor}-${info.name}-${info.model}-${info.systemVersion}';
          return _formatDeviceId(_hash(raw));
        case TargetPlatform.fuchsia:
          return _formatDeviceId(_hash(_generateFallbackRawId()));
      }
    } catch (_) {
      return _formatDeviceId(_hash(_generateFallbackRawId()));
    }
  }

  String _hash(String raw) => sha256.convert(utf8.encode(raw)).toString();

  String _formatDeviceId(String rawHash) {
    final upper = rawHash.substring(0, 24).toUpperCase();
    final segments = <String>[];
    for (var index = 0; index < upper.length; index += 4) {
      segments.add(upper.substring(index, index + 4));
    }
    return segments.join('-');
  }

  String _generateFallbackRawId() {
    final random = Random.secure();
    final chars = List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    );
    return chars.join();
  }
}
