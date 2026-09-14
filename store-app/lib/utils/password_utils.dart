import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Local-only app with a single shared database per device, so a fixed
/// salt is enough to keep stored passwords from being plain text.
const _salt = 'auola-store-app-v1';

String hashPassword(String rawPassword) {
  final bytes = utf8.encode('$_salt::$rawPassword');
  return sha256.convert(bytes).toString();
}

bool verifyPassword(String rawPassword, String hash) {
  return hashPassword(rawPassword) == hash;
}
