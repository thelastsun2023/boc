import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_base_url.dart';

class HttpAuthService {
  static final HttpAuthService _instance = HttpAuthService._internal();
  factory HttpAuthService() => _instance;
  HttpAuthService._internal();

  final String baseUrl = getBaseUrl();

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<bool> register(
    String username,
    String password, {
    String role = 'USER',
    List<String> allowedCategoryCodes = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': role,
          'allowedCategoryCodes': allowedCategoryCodes,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Register failed: $e');
    }
  }
}
