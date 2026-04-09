import 'dart:convert';

import 'package:crypto/crypto.dart';

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

void main() {
  // Example of using the fixed buildActivationKey function:
  print(
    'Generated Activation Key is : ${buildActivationKey('EA55-F8C8-0B0A-47CC-C66D-76AF')}',
  );
}
