import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.adminEmail,
    required this.passwordHash,
    required this.pin,
    required this.defaultLoginMethod,
    required this.shopInfo,
  });

  final AppMode? mode;
  final String adminEmail;
  final String passwordHash;
  final String pin;
  final LoginMethod? defaultLoginMethod;
  final ShopInfo shopInfo;

  bool get hasMode => mode != null;
  bool get hasAdminAccount => adminEmail.isNotEmpty && passwordHash.isNotEmpty;
  bool get hasPin => pin.length == 4;
  bool get hasDefaultLoginMethod => defaultLoginMethod != null;
  bool get hasShopInfo => shopInfo.shopName.trim().isNotEmpty;

  bool get isComplete =>
      hasMode &&
      hasAdminAccount &&
      hasPin &&
      hasDefaultLoginMethod &&
      hasShopInfo;

  int get firstIncompleteStep {
    if (!hasMode) return 0;
    if (!hasAdminAccount) return 1;
    if (!hasPin) return 2;
    if (!hasDefaultLoginMethod) return 3;
    if (!hasShopInfo) return 4;
    return 5;
  }
}

class SetupService {
  SetupService._();

  static final SetupService instance = SetupService._();

  static const _appModePref = 'setup_app_mode';
  static const _adminEmailPref = 'setup_admin_email';
  static const _passwordHashPref = 'setup_admin_password_hash';
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
      adminEmail: prefs.getString(_adminEmailPref) ?? '',
      passwordHash: prefs.getString(_passwordHashPref) ?? '',
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

  Future<void> saveAdminAccount({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminEmailPref, email.trim());
    await prefs.setString(_passwordHashPref, _hashPassword(password));
  }

  Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinPref, pin);
  }

  Future<void> saveDefaultLoginMethod(LoginMethod method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultLoginMethodPref, method.name);
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

  Future<void> saveShopInfo(ShopInfo shopInfo) async {
    final prefs = await SharedPreferences.getInstance();
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
    await prefs.remove(_adminEmailPref);
    await prefs.remove(_passwordHashPref);
    await prefs.remove(_pinPref);
    await prefs.remove(_defaultLoginMethodPref);
    await prefs.remove(_shopLogoPathPref);
    await prefs.remove(_shopNamePref);
    await prefs.remove(_shopEmailPref);
    await prefs.remove(_shopPhonePref);
    await prefs.remove(_shopAddressPref);
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
