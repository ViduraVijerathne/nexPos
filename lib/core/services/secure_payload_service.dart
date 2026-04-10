import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class SecurePayloadService {
  SecurePayloadService._();

  static String encryptText({
    required String plainText,
    required String secret,
  }) {
    final normalizedSecret = secret.trim();
    if (normalizedSecret.isEmpty) {
      throw const FormatException('Encryption secret is required');
    }

    final nonce = _generateNonce();
    final plainBytes = utf8.encode(plainText);
    final keyStream = _buildKeyStream(
      secret: normalizedSecret,
      nonce: nonce,
      length: plainBytes.length,
    );
    final cipherBytes = Uint8List(plainBytes.length);
    for (var i = 0; i < plainBytes.length; i++) {
      cipherBytes[i] = plainBytes[i] ^ keyStream[i];
    }

    final payload = <String, dynamic>{
      'version': 1,
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(cipherBytes),
      'signature': sha256
          .convert(utf8.encode('$normalizedSecret::$plainText'))
          .toString(),
    };

    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  static String decryptText({
    required String encryptedText,
    required String secret,
  }) {
    final normalizedSecret = secret.trim();
    if (normalizedSecret.isEmpty) {
      throw const FormatException('Decryption secret is required');
    }

    final raw = utf8.decode(base64Decode(encryptedText.trim()));
    final payload = jsonDecode(raw);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid encrypted payload');
    }

    final nonce = base64Decode(payload['nonce'] as String? ?? '');
    final cipherBytes = base64Decode(payload['ciphertext'] as String? ?? '');
    final signature = payload['signature'] as String? ?? '';
    final keyStream = _buildKeyStream(
      secret: normalizedSecret,
      nonce: nonce,
      length: cipherBytes.length,
    );

    final plainBytes = Uint8List(cipherBytes.length);
    for (var i = 0; i < cipherBytes.length; i++) {
      plainBytes[i] = cipherBytes[i] ^ keyStream[i];
    }

    final plainText = utf8.decode(plainBytes);
    final expectedSignature = sha256
        .convert(utf8.encode('$normalizedSecret::$plainText'))
        .toString();

    if (expectedSignature != signature) {
      throw const FormatException('Encrypted payload verification failed');
    }

    return plainText;
  }

  static Uint8List _buildKeyStream({
    required String secret,
    required List<int> nonce,
    required int length,
  }) {
    final output = BytesBuilder(copy: false);
    var counter = 0;
    while (output.length < length) {
      final digest = sha256.convert(<int>[
        ...utf8.encode(secret),
        58,
        ...nonce,
        58,
        ...utf8.encode(counter.toString()),
      ]);
      output.add(digest.bytes);
      counter++;
    }
    return Uint8List.fromList(output.takeBytes().sublist(0, length));
  }

  static List<int> _generateNonce() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }
}
