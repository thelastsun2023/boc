import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Database? _db;
  // Fallback in-memory store used on web where `sqflite` is not supported.
  bool _useMemory = false;
  final Map<String, Map<String, String>> _users = {};

  Future<void> init() async {
    if (kIsWeb) {
      // sqflite doesn't work on web; use in-memory store for testing in browser.
      _useMemory = true;
      await _seedAdmin();
      return;
    }
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE,
          password TEXT,
          role TEXT
        )
      ''');
    });

    await _seedAdmin();
  }

  Future<void> _seedAdmin() async {
    if (_useMemory) {
      if (!_users.containsKey('ADMIN')) {
        _users['ADMIN'] = {'password': _hashPassword('admin'), 'role': 'ADMIN'};
      }
      return;
    }
    if (_db == null) return;
    final res = await _db!.query('users', where: 'username = ?', whereArgs: ['ADMIN']);
    if (res.isEmpty) {
      final hashed = _hashPassword('admin');
      await _db!.insert('users', {'username': 'ADMIN', 'password': hashed, 'role': 'ADMIN'});
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<String?> login(String username, String password) async {
    if (_db == null) throw StateError('DB not initialized');
    final hashed = _hashPassword(password);
    if (_useMemory) {
      final u = _users[username];
      if (u == null) return null;
      return u['password'] == hashed ? u['role'] : null;
    }
    final res = await _db!.query('users', where: 'username = ? AND password = ?', whereArgs: [username, hashed]);
    if (res.isEmpty) return null;
    return res.first['role'] as String?;
  }

  Future<bool> register(String username, String password, {String role = 'USER'}) async {
    if (_useMemory) {
      if (_users.containsKey(username)) return false;
      _users[username] = {'password': _hashPassword(password), 'role': role};
      return true;
    }
    if (_db == null) throw StateError('DB not initialized');
    try {
      final hashed = _hashPassword(password);
      await _db!.insert('users', {'username': username, 'password': hashed, 'role': role});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
