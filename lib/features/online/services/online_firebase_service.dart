import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/secure_payload_service.dart';
import '../../../firebase_options.dart';
import '../../subscription/services/subscription_usage_service.dart';
import '../../activation/services/activation_service.dart';
import '../../setup/services/setup_service.dart';

class OnlineFirebaseConfig {
  const OnlineFirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
    this.storageBucket,
    this.databaseURL,
    this.measurementId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? authDomain;
  final String? storageBucket;
  final String? databaseURL;
  final String? measurementId;

  FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
    databaseURL: databaseURL,
    measurementId: measurementId,
  );

  factory OnlineFirebaseConfig.fromJson(Map<String, dynamic> json) {
    final resolved = _resolvePlatformConfig(json);
    final apiKey = resolved['apiKey']?.toString() ?? '';
    final appId = resolved['appId']?.toString() ?? '';
    final messagingSenderId = resolved['messagingSenderId']?.toString() ?? '';
    final projectId = resolved['projectId']?.toString() ?? '';
    if ([
      apiKey,
      appId,
      messagingSenderId,
      projectId,
    ].any((value) => value.trim().isEmpty)) {
      throw const FormatException('Firebase config is missing required keys');
    }

    _validatePlatformCompatibility(appId: appId);

    return OnlineFirebaseConfig(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: resolved['authDomain']?.toString(),
      storageBucket: resolved['storageBucket']?.toString(),
      databaseURL: resolved['databaseURL']?.toString(),
      measurementId: resolved['measurementId']?.toString(),
    );
  }

  static Map<String, dynamic> _resolvePlatformConfig(
    Map<String, dynamic> json,
  ) {
    final keys = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => const ['macos', 'ios', 'apple'],
      TargetPlatform.iOS => const ['ios', 'macos', 'apple'],
      TargetPlatform.windows => const ['windows', 'desktop', 'web'],
      TargetPlatform.linux => const ['linux', 'desktop', 'web'],
      TargetPlatform.android => const ['android'],
      TargetPlatform.fuchsia => const ['web', 'desktop'],
    };

    for (final key in keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }

    return json;
  }

  static void _validatePlatformCompatibility({required String appId}) {
    final normalized = appId.toLowerCase();

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        if (normalized.contains(':web:')) {
          throw const FormatException(
            'This Firebase config uses a web appId. Please upload a macOS/Apple Firebase config instead.',
          );
        }
      case TargetPlatform.android:
        if (normalized.contains(':web:')) {
          throw const FormatException(
            'This Firebase config uses a web appId. Please upload an Android Firebase config instead.',
          );
        }
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        break;
    }
  }
}

class OnlineConfigLoadResult {
  const OnlineConfigLoadResult({
    required this.encryptedPayload,
    required this.config,
  });

  final String encryptedPayload;
  final OnlineFirebaseConfig config;
}

class OnlineShopRecord {
  const OnlineShopRecord({required this.id, required this.shopInfo});

  final String id;
  final ShopInfo shopInfo;
}

class OnlineFirebaseService {
  OnlineFirebaseService._();

  static final OnlineFirebaseService instance = OnlineFirebaseService._();

  FirebaseApp? _app;

  Future<OnlineConfigLoadResult> verifyEncryptedConfigText(String raw) async {
    final activationKey = await ActivationService.instance
        .getStoredActivationKey();
    if (activationKey == null || activationKey.trim().isEmpty) {
      throw const FormatException(
        'Activation key is required before verifying Firebase config',
      );
    }

    final normalized = raw.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Config file is empty');
    }

    final config = _parseConfig(normalized, activationKey);
    final encryptedPayload = _looksLikePlainJson(normalized)
        ? SecurePayloadService.encryptText(
            plainText: normalized,
            secret: activationKey,
          )
        : normalized;

    return OnlineConfigLoadResult(
      encryptedPayload: encryptedPayload,
      config: config,
    );
  }

  Future<void> initializeFromSavedSetup() async {
    final state = await SetupService.instance.loadState();
    if (state.mode != AppMode.online || !state.hasOnlineFirebaseConfig) {
      return;
    }

    if (_app != null) {
      return;
    }

    if (Firebase.apps.isNotEmpty) {
      _app = Firebase.apps.first;
      return;
    }

    if (state.firebaseConfigCiphertext.trim().isEmpty) {
      try {
        _app = Firebase.app();
        return;
      } catch (_) {
        throw const FormatException(
          'Firebase is not initialized yet. Initialize Firebase in the app first, then try the online admin login again.',
        );
      }
    }

    final activationKey = await ActivationService.instance
        .getStoredActivationKey();
    if (activationKey == null || activationKey.trim().isEmpty) {
      throw const FormatException('Activation key is missing');
    }

    final decrypted = SecurePayloadService.decryptText(
      encryptedText: state.firebaseConfigCiphertext,
      secret: activationKey,
    );
    final config = OnlineFirebaseConfig.fromJson(
      jsonDecode(decrypted) as Map<String, dynamic>,
    );

    try {
      _app = await Firebase.initializeApp(options: config.options);
    } catch (error) {
      throw FormatException(
        'Unable to initialize Firebase for this platform. Please verify the uploaded Firebase config. Original error: $error',
      );
    }
  }

  Future<void> verifyAdminCredentials({
    required String email,
    required String password,
  }) async {
    await initializeFromSavedSetup();
    await _signInWithPasswordRest(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    await initializeFromSavedSetup();
    await _signInWithPasswordRest(email: email, password: password);
  }

  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    await initializeFromSavedSetup();
    final signInResult = await _signInWithPasswordRest(
      email: email,
      password: currentPassword,
      returnAuthPayload: true,
    );
    final idToken = signInResult?['idToken']?.toString() ?? '';
    if (idToken.isEmpty) {
      throw const FormatException('Unable to verify current online password.');
    }
    await _updatePasswordRest(idToken: idToken, newPassword: newPassword);
  }

  Future<OnlineShopRecord?> findShopByAdminEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return null;
    }

    final firestore = FirebaseFirestore.instanceFor(app: _resolvedApp);
    QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection('shops')
        .where('adminEmail', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      snapshot = await firestore
          .collection('shops')
          .where('adminEmailLower', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
    }

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    await SubscriptionUsageService.instance.recordRead(
      shopId: doc.id,
      module: 'setup',
      documentCount: snapshot.docs.length,
      payload: snapshot.docs.map((item) => item.data()).toList(),
    );
    final data = doc.data();
    return OnlineShopRecord(
      id: doc.id,
      shopInfo: ShopInfo(
        logoPath:
            data['logoPath']?.toString() ?? data['logoUrl']?.toString() ?? '',
        shopName: data['shopName']?.toString() ?? '',
        contactEmail: data['contactEmail']?.toString() ?? '',
        contactNumber: data['contactNumber']?.toString() ?? '',
        address: data['address']?.toString() ?? '',
      ),
    );
  }

  Future<OnlineShopRecord> createShopForAdmin({
    required String adminEmail,
    required ShopInfo shopInfo,
  }) async {
    final normalizedEmail = adminEmail.trim().toLowerCase();
    final firestore = FirebaseFirestore.instanceFor(app: _resolvedApp);
    final doc = await firestore.collection('shops').add({
      'adminEmail': normalizedEmail,
      'adminEmailLower': normalizedEmail,
      'shopName': shopInfo.shopName.trim(),
      'contactEmail': shopInfo.contactEmail.trim(),
      'contactNumber': shopInfo.contactNumber.trim(),
      'address': shopInfo.address.trim(),
      'logoPath': shopInfo.logoPath.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await SubscriptionUsageService.instance.recordWrite(
      shopId: doc.id,
      module: 'setup',
      payload: <String, dynamic>{
        'shopId': doc.id,
        'shopName': shopInfo.shopName.trim(),
        'adminEmail': normalizedEmail,
      },
    );

    return OnlineShopRecord(id: doc.id, shopInfo: shopInfo);
  }

  OnlineFirebaseConfig parseStoredConfig({
    required String encryptedPayload,
    required String activationKey,
  }) {
    final decrypted = SecurePayloadService.decryptText(
      encryptedText: encryptedPayload,
      secret: activationKey,
    );
    return OnlineFirebaseConfig.fromJson(
      jsonDecode(decrypted) as Map<String, dynamic>,
    );
  }

  OnlineFirebaseConfig _parseConfig(String raw, String activationKey) {
    if (_looksLikePlainJson(raw)) {
      return OnlineFirebaseConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }

    final decrypted = SecurePayloadService.decryptText(
      encryptedText: raw,
      secret: activationKey,
    );
    return OnlineFirebaseConfig.fromJson(
      jsonDecode(decrypted) as Map<String, dynamic>,
    );
  }

  bool _looksLikePlainJson(String value) {
    final trimmed = value.trimLeft();
    return trimmed.startsWith('{');
  }

  FirebaseApp get _resolvedApp {
    final app = _app;
    if (app != null) {
      return app;
    }
    if (Firebase.apps.isNotEmpty) {
      return Firebase.apps.first;
    }
    throw const FormatException(
      'Firebase app is not initialized. Please initialize Firebase before using online data.',
    );
  }

  Future<Map<String, dynamic>?> _signInWithPasswordRest({
    required String email,
    required String password,
    bool returnAuthPayload = false,
  }) async {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
    );

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(
        jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (returnAuthPayload && decoded is Map<String, dynamic>) {
          return decoded;
        }
        return <String, dynamic>{};
      }

      String? errorCode;
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          errorCode = error['message']?.toString();
        }
      }
      errorCode ??= 'AUTH_REQUEST_FAILED';
      throw FormatException(_mapFirebaseAuthError(errorCode));
    } on SocketException {
      throw const FormatException(
        'Network error. Please check the internet connection and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _updatePasswordRest({
    required String idToken,
    required String newPassword,
  }) async {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$apiKey',
    );

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(
        jsonEncode({
          'idToken': idToken,
          'password': newPassword,
          'returnSecureToken': true,
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      String? errorCode;
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          errorCode = error['message']?.toString();
        }
      }
      errorCode ??= 'AUTH_UPDATE_FAILED';
      throw FormatException(_mapFirebaseAuthError(errorCode));
    } on SocketException {
      throw const FormatException(
        'Network error. Please check the internet connection and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_EMAIL':
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'INVALID_PASSWORD':
      case 'USER_NOT_FOUND':
        return 'Invalid email or password.';
      case 'USER_DISABLED':
        return 'This Firebase user account has been disabled.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many login attempts. Please try again later.';
      case 'NETWORK_REQUEST_FAILED':
        return 'Network error. Please check the internet connection and try again.';
      default:
        return code
            .replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }
}
