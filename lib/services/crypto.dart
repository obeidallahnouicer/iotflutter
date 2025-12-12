import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

import '../config.dart';

// Simple AES-256-CBC helpers for Flutter mobile app.

Key _keyFromHex(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Key(Uint8List.fromList(bytes));
}

IV _ivFromHex(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return IV(Uint8List.fromList(bytes));
}

String encryptObjectToHex(Map<String, dynamic> obj) {
  final keyHex = encryptionKeyHex;
  final ivHex = encryptionIvHex;
  if (keyHex.isEmpty || ivHex.isEmpty) {
    throw Exception('Encryption key/iv not configured (set ENCRYPTION_KEY_HEX and ENCRYPTION_IV_HEX in .env)');
  }
  final key = _keyFromHex(keyHex);
  final iv = _ivFromHex(ivHex);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
  final plain = json.encode(obj);
  final encrypted = encrypter.encrypt(plain, iv: iv);
  return encrypted.base16; // hex
}

Map<String, dynamic> decryptHexToObject(String hex) {
  final keyHex = encryptionKeyHex;
  final ivHex = encryptionIvHex;
  if (keyHex.isEmpty || ivHex.isEmpty) {
    throw Exception('Encryption key/iv not configured (set ENCRYPTION_KEY_HEX and ENCRYPTION_IV_HEX in .env)');
  }
  final key = _keyFromHex(keyHex);
  final iv = _ivFromHex(ivHex);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
  final encrypted = Encrypted.fromBase16(hex);
  final decrypted = encrypter.decrypt(encrypted, iv: iv);
  return json.decode(decrypted) as Map<String, dynamic>;
}
