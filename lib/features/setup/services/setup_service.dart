import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/secure_payload_service.dart';

enum AppMode {
  online('Online Version'),
  offline('Offline Version');

  const AppMode(this.label);

  final String label;
}

enum LoginMethod {
  emailPassword('Email & Password'),
  pin('PIN');

  const LoginMethod(this.label);

  final String label;
}

class ShopInfo {
  const ShopInfo({
    required this.logoPath,
    required this.shopName,
    required this.contactEmail,
    required this.contactNumber,
    required this.address,
  });

  final String logoPath;
  final String shopName;
  final String contactEmail;
  final String contactNumber;
  final String address;
}

class SetupState {
  const SetupState({
    required this.mode,
    required this.selectedShopId,
    required this.adminEmail,
    required this.passwordHash,
    required this.firebaseConfigCiphertext,
    required this.onlineEmailCiphertext,
    required this.onlinePasswordCiphertext,
    required this.pin,
    required this.defaultLoginMethod,
    required this.shopInfo,
  });

  final AppMode? mode;
  final String selectedShopId;
  final String adminEmail;
  final String passwordHash;
  final String firebaseConfigCiphertext;
  final String onlineEmailCiphertext;
  final String onlinePasswordCiphertext;
  final String pin;
  final LoginMethod? defaultLoginMethod;
  final ShopInfo shopInfo;

  bool get hasMode => mode != null;
  bool get hasAdminAccount => adminEmail.isNotEmpty && passwordHash.isNotEmpty;
  bool get hasOnlineFirebaseConfig => true;
  bool get hasOnlinePinCredentials =>
      mode != AppMode.online ||
      defaultLoginMethod != LoginMethod.pin ||
      (onlineEmailCiphertext.trim().isNotEmpty &&
          onlinePasswordCiphertext.trim().isNotEmpty);
  bool get hasPin => pin.length == 4;
  bool get hasDefaultLoginMethod => defaultLoginMethod != null;
  bool get hasShopInfo => shopInfo.shopName.trim().isNotEmpty;

  bool get isComplete =>
      hasMode &&
      hasOnlineFirebaseConfig &&
      hasAdminAccount &&
      hasPin &&
      hasDefaultLoginMethod &&
      hasOnlinePinCredentials &&
      hasShopInfo;

  int get firstIncompleteStep {
    if (!hasMode) return 0;
    if (!hasAdminAccount) return 1;
    if (!hasPin) return 2;
    if (!hasDefaultLoginMethod) return 3;
    if (!hasOnlinePinCredentials) return 3;
    if (!hasShopInfo) return 4;
    return 5;
  }
}

class SetupService {
  SetupService._();

  static final SetupService instance = SetupService._();

  static const _appModePref = 'setup_app_mode';
  static const _shopIdPref = 'setup_shop_id';
  static const _adminEmailPref = 'setup_admin_email';
  static const _passwordHashPref = 'setup_admin_password_hash';
  static const _firebaseConfigCiphertextPref = 'setup_online_firebase_config';
  static const _onlineEmailCiphertextPref = 'setup_online_email_ciphertext';
  static const _onlinePasswordCiphertextPref =
      'setup_online_password_ciphertext';
  static const _pinPref = 'setup_login_pin';
  static const _defaultLoginMethodPref = 'setup_default_login_method';
  static const _shopLogoPathPref = 'setup_shop_logo_path';
  static const _shopNamePref = 'setup_shop_name';
  static const _shopEmailPref = 'setup_shop_email';
  static const _shopPhonePref = 'setup_shop_phone';
  static const _shopAddressPref = 'setup_shop_address';

  Future<SetupState> loadState() async {
    final prefs = await SharedPreferences.getInstance();

    return SetupState(
      mode: _readAppMode(prefs.getString(_appModePref)),
      selectedShopId: prefs.getString(_shopIdPref) ?? '',
      adminEmail: prefs.getString(_adminEmailPref) ?? '',
      passwordHash: prefs.getString(_passwordHashPref) ?? '',
      firebaseConfigCiphertext:
          prefs.getString(_firebaseConfigCiphertextPref) ?? '',
      onlineEmailCiphertext: prefs.getString(_onlineEmailCiphertextPref) ?? '',
      onlinePasswordCiphertext:
          prefs.getString(_onlinePasswordCiphertextPref) ?? '',
      pin: prefs.getString(_pinPref) ?? '',
      defaultLoginMethod: _readLoginMethod(
        prefs.getString(_defaultLoginMethodPref),
      ),
      shopInfo: ShopInfo(
        logoPath: prefs.getString(_shopLogoPathPref) ?? '',
        shopName: prefs.getString(_shopNamePref) ?? '',
        contactEmail: prefs.getString(_shopEmailPref) ?? '',
        contactNumber: prefs.getString(_shopPhonePref) ?? '',
        address: prefs.getString(_shopAddressPref) ?? '',
      ),
    );
  }

  Future<void> saveAppMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appModePref, mode.name);
  }

  Future<void> saveSelectedShopId(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopIdPref, shopId.trim());
  }

  Future<void> saveAdminAccount({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminEmailPref, email.trim());
    await prefs.setString(_passwordHashPref, _hashPassword(password));
  }

  Future<void> saveFirebaseConfigCiphertext(String encryptedConfig) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _firebaseConfigCiphertextPref,
      encryptedConfig.trim(),
    );
  }

  Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinPref, pin);
  }

  Future<void> saveDefaultLoginMethod(LoginMethod method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultLoginMethodPref, method.name);
  }

  Future<void> saveOnlinePinCredentials({
    required String email,
    required String password,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _onlineEmailCiphertextPref,
      SecurePayloadService.encryptText(plainText: email.trim(), secret: pin),
    );
    await prefs.setString(
      _onlinePasswordCiphertextPref,
      SecurePayloadService.encryptText(plainText: password.trim(), secret: pin),
    );
  }

  Future<void> clearOnlinePinCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onlineEmailCiphertextPref);
    await prefs.remove(_onlinePasswordCiphertextPref);
  }

  Future<({String email, String password})?> readOnlinePinCredentials(
    String pin,
  ) async {
    final state = await loadState();
    if (state.onlineEmailCiphertext.trim().isEmpty ||
        state.onlinePasswordCiphertext.trim().isEmpty) {
      return null;
    }
    final email = SecurePayloadService.decryptText(
      encryptedText: state.onlineEmailCiphertext,
      secret: pin,
    );
    final password = SecurePayloadService.decryptText(
      encryptedText: state.onlinePasswordCiphertext,
      secret: pin,
    );
    return (email: email, password: password);
  }

  Future<String?> saveShopLogo(PlatformFile platformFile) async {
    if (platformFile.path == null) {
      return null;
    }

    final sourceFile = File(platformFile.path!);
    if (!await sourceFile.exists()) {
      return null;
    }

    final appSupportDirectory = await getApplicationSupportDirectory();
    final logoDirectory = Directory('${appSupportDirectory.path}/shop_assets');
    if (!await logoDirectory.exists()) {
      await logoDirectory.create(recursive: true);
    }

    final extension = platformFile.extension == null
        ? ''
        : '.${platformFile.extension}';
    final targetFile = File('${logoDirectory.path}/shop_logo$extension');
    await sourceFile.copy(targetFile.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopLogoPathPref, targetFile.path);
    return targetFile.path;
  }

  Future<void> saveShopInfo(ShopInfo shopInfo, {String? shopId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (shopId != null) {
      await prefs.setString(_shopIdPref, shopId.trim());
    }
    await prefs.setString(_shopLogoPathPref, shopInfo.logoPath);
    await prefs.setString(_shopNamePref, shopInfo.shopName.trim());
    await prefs.setString(_shopEmailPref, shopInfo.contactEmail.trim());
    await prefs.setString(_shopPhonePref, shopInfo.contactNumber.trim());
    await prefs.setString(_shopAddressPref, shopInfo.address.trim());
  }

  Future<bool> validateAdminCredentials({
    required String email,
    required String password,
  }) async {
    final state = await loadState();
    if (!state.hasAdminAccount) {
      return false;
    }

    return state.adminEmail.trim().toLowerCase() ==
            email.trim().toLowerCase() &&
        state.passwordHash == _hashPassword(password);
  }

  Future<bool> validatePin(String pin) async {
    final state = await loadState();
    return state.pin == pin;
  }

  Future<void> resetSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appModePref);
    await prefs.remove(_shopIdPref);
    await prefs.remove(_adminEmailPref);
    await prefs.remove(_passwordHashPref);
    await prefs.remove(_firebaseConfigCiphertextPref);
    await prefs.remove(_onlineEmailCiphertextPref);
    await prefs.remove(_onlinePasswordCiphertextPref);
    await prefs.remove(_pinPref);
    await prefs.remove(_defaultLoginMethodPref);
    await prefs.remove(_shopLogoPathPref);
    await prefs.remove(_shopNamePref);
    await prefs.remove(_shopEmailPref);
    await prefs.remove(_shopPhonePref);
    await prefs.remove(_shopAddressPref);
  }

  Future<Map<String, dynamic>> exportState() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, dynamic>{
      _appModePref: prefs.getString(_appModePref),
      _shopIdPref: prefs.getString(_shopIdPref),
      _adminEmailPref: prefs.getString(_adminEmailPref),
      _passwordHashPref: prefs.getString(_passwordHashPref),
      _firebaseConfigCiphertextPref: prefs.getString(
        _firebaseConfigCiphertextPref,
      ),
      _onlineEmailCiphertextPref: prefs.getString(_onlineEmailCiphertextPref),
      _onlinePasswordCiphertextPref: prefs.getString(
        _onlinePasswordCiphertextPref,
      ),
      _pinPref: prefs.getString(_pinPref),
      _defaultLoginMethodPref: prefs.getString(_defaultLoginMethodPref),
      _shopLogoPathPref: prefs.getString(_shopLogoPathPref),
      _shopNamePref: prefs.getString(_shopNamePref),
      _shopEmailPref: prefs.getString(_shopEmailPref),
      _shopPhonePref: prefs.getString(_shopPhonePref),
      _shopAddressPref: prefs.getString(_shopAddressPref),
    };
  }

  Future<void> importState(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      }
    }
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  AppMode? _readAppMode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return AppMode.values.cast<AppMode?>().firstWhere(
      (item) => item?.name == raw,
      orElse: () => null,
    );
  }

  LoginMethod? _readLoginMethod(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return LoginMethod.values.cast<LoginMethod?>().firstWhere(
      (item) => item?.name == raw,
      orElse: () => null,
    );
  }
}
