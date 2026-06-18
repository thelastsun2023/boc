import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base_url.dart';

class MenuService {
  static final MenuService _instance = MenuService._internal();
  factory MenuService() => _instance;
  MenuService._internal();

  final String baseUrl = getBaseUrl();

  Future<bool> addMenuCategory(
    String code,
    String nameCn,
    String? nameEn,
  ) async {
    return _post('/api/menu-categories', {
      'code': code,
      'name_cn': nameCn,
      'name_en': nameEn,
    }, 'Failed to add menu category');
  }

  Future<List<Map<String, dynamic>>> getMenuCategories() async {
    final data = await _get(
      '/api/menu-categories',
      'Failed to get menu categories',
    );
    return List<Map<String, dynamic>>.from(data['categories'] ?? []);
  }

  Future<bool> updateMenuCategory(
    String code,
    String nameCn,
    String? nameEn,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put(
      '/api/menu-categories/$encodedCode',
      {
        'name_cn': nameCn,
        'name_en': nameEn,
      },
      'Failed to update menu category',
    );
  }

  Future<bool> deleteMenuCategory(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/menu-categories/$encodedCode',
      'Failed to delete menu category',
    );
  }

  Future<bool> addMenu(
    String code,
    String nameCn,
    String? nameEn,
    String? categoryCode,
  ) async {
    return _post('/api/menus', {
      'code': code,
      'name_cn': nameCn,
      'name_en': nameEn,
      'category_code': categoryCode,
    }, 'Failed to add menu');
  }

  Future<List<Map<String, dynamic>>> getMenus() async {
    final data = await _get(
      '/api/menus',
      'Failed to get menus',
    );
    return List<Map<String, dynamic>>.from(data['menus'] ?? []);
  }

  Future<bool> updateMenu(
    String code,
    String nameCn,
    String? nameEn,
    String? categoryCode,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put(
      '/api/menus/$encodedCode',
      {
        'name_cn': nameCn,
        'name_en': nameEn,
        'category_code': categoryCode,
      },
      'Failed to update menu',
    );
  }

  Future<bool> deleteMenu(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/menus/$encodedCode',
      'Failed to delete menu',
    );
  }

  Future<Map<String, dynamic>> _get(String path, String errorMessage) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('$errorMessage: ${response.statusCode} ${response.body}');
    }
  }

  Future<bool> _post(String path, Map<String, dynamic> body, String errorMessage) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } else {
      throw Exception('$errorMessage: ${response.statusCode} ${response.body}');
    }
  }

  Future<bool> _put(String path, Map<String, dynamic> body, String errorMessage) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } else {
      throw Exception('$errorMessage: ${response.statusCode} ${response.body}');
    }
  }

  Future<bool> _delete(String path, String errorMessage) async {
    final response = await http.delete(Uri.parse('$baseUrl$path'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } else {
      throw Exception('$errorMessage: ${response.statusCode} ${response.body}');
    }
  }
}