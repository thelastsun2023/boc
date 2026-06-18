import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final hashedPw = sha256.convert(utf8.encode('admin')).toString();
  print('SHA-256 hash of "admin": $hashedPw');
}