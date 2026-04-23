import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'core/services/secure_payload_service.dart';

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

String encryptFirebaseJsonContent({
  required String firebaseJsonContent,
  required String activationKey,
}) {
  final normalizedJson = firebaseJsonContent.trim();
  if (normalizedJson.isEmpty) {
    throw const FormatException('Firebase JSON content is empty');
  }

  final decoded = jsonDecode(normalizedJson);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Firebase config must be a JSON object');
  }

  const requiredKeys = <String>[
    'apiKey',
    'appId',
    'messagingSenderId',
    'projectId',
  ];

  for (final key in requiredKeys) {
    final value = decoded[key]?.toString() ?? '';
    if (value.trim().isEmpty) {
      throw FormatException('Firebase JSON is missing required key: $key');
    }
  }

  return SecurePayloadService.encryptText(
    plainText: normalizedJson,
    secret: activationKey,
  );
}

Future<String> encryptFirebaseJsonFile({
  required String inputFilePath,
  required String activationKey,
  String? outputFilePath,
}) async {
  final inputFile = File(inputFilePath);
  if (!await inputFile.exists()) {
    throw FileSystemException('Firebase JSON file not found', inputFilePath);
  }

  final rawJson = await inputFile.readAsString();
  final encrypted = encryptFirebaseJsonContent(
    firebaseJsonContent: rawJson,
    activationKey: activationKey,
  );

  final targetPath = outputFilePath ?? '$inputFilePath.enc';
  final outputFile = File(targetPath);
  await outputFile.writeAsString(encrypted);
  return outputFile.path;
}

void main() {
  // Example usage:
  print(
    'Generated Activation Key is : ${buildActivationKey('95B3-D416-A309-F1D6-B328-DA32')}',
  );

  // Firebase JSON encryption example:
  // unawaited(
  //   encryptFirebaseJsonFile(
  //     inputFilePath: '/Users/vidura/Documents/industry-projects/aisha/nexPos/lib/firebase.json',
  //     activationKey: buildActivationKey('7304-69DE-611E-4285-E597-7CBB'),
  //   ).then(print),
  // );
}
