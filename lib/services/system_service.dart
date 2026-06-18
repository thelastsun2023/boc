import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_base_url.dart';
import 'session_service.dart';

class SystemService {
  static final SystemService _instance = SystemService._internal();
  factory SystemService() => _instance;
  SystemService._internal();

  final String baseUrl = getBaseUrl();

  Future<bool> addRawMaterial(
    String nameCN,
    String nameEN,
    String specification,
    String? categoryCode,
    String? locationCode,
    String? primarySupplierCode,
    String? secondarySupplierCode,
    double minQuantity,
    Uint8List? imageBytes,
    String? imageFileName,
  ) async {
    final imagePath = await _uploadImage(imageBytes, imageFileName);
    return _post('/api/raw-materials', {
      'nameCN': nameCN,
      'nameEN': nameEN,
      'specification': specification,
      'categoryCode': categoryCode,
      'locationCode': locationCode,
      'primarySupplierCode': primarySupplierCode,
      'secondarySupplierCode': secondarySupplierCode,
      'minQuantity': minQuantity,
      'imagePath': imagePath,
    }, 'Failed to add raw material');
  }

  Future<List<Map<String, dynamic>>> getRawMaterials() async {
    final data = await _get(
      '/api/raw-materials',
      'Failed to get raw materials',
    );
    return List<Map<String, dynamic>>.from(data['materials'] ?? []);
  }

  Future<bool> updateRawMaterial(
    String code,
    String nameCN,
    String nameEN,
    String specification,
    String? categoryCode,
    String? locationCode,
    String? primarySupplierCode,
    String? secondarySupplierCode,
    double minQuantity,
    Uint8List? imageBytes,
    String? imageFileName,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    final imagePath = await _uploadImage(imageBytes, imageFileName);
    final payload = <String, dynamic>{
      'nameCN': nameCN,
      'nameEN': nameEN,
      'specification': specification,
      'categoryCode': categoryCode,
      'locationCode': locationCode,
      'primarySupplierCode': primarySupplierCode,
      'secondarySupplierCode': secondarySupplierCode,
      'minQuantity': minQuantity,
    };
    if (imagePath != null) {
      payload['imagePath'] = imagePath;
    }
    return _put(
      '/api/raw-materials/$encodedCode',
      payload,
      'Failed to update raw material',
    );
  }

  Future<bool> deleteRawMaterial(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/raw-materials/$encodedCode',
      'Failed to delete raw material',
    );
  }

  Future<bool> addRawMaterialCategory(String code, String name) async {
    return _post('/api/raw-material-categories', {
      'code': code,
      'name': name,
    }, 'Failed to add raw material category');
  }

  Future<List<Map<String, dynamic>>> getRawMaterialCategories() async {
    final data = await _get(
      '/api/raw-material-categories',
      'Failed to get raw material categories',
    );
    return List<Map<String, dynamic>>.from(data['categories'] ?? []);
  }

  Future<bool> updateRawMaterialCategory(String code, String name) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put(
      '/api/raw-material-categories/$encodedCode',
      {'name': name},
      'Failed to update raw material category',
    );
  }

  Future<bool> deleteRawMaterialCategory(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/raw-material-categories/$encodedCode',
      'Failed to delete raw material category',
    );
  }

  Future<bool> addRawMaterialLocation(
    String code,
    String name,
    String note,
  ) async {
    return _post('/api/raw-material-locations', {
      'code': code,
      'name': name,
      'note': note,
    }, 'Failed to add raw material location');
  }

  Future<List<Map<String, dynamic>>> getRawMaterialLocations() async {
    final data = await _get(
      '/api/raw-material-locations',
      'Failed to get raw material locations',
    );
    return List<Map<String, dynamic>>.from(data['locations'] ?? []);
  }

  Future<bool> updateRawMaterialLocation(
    String code,
    String name,
    String note,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put(
      '/api/raw-material-locations/$encodedCode',
      {'name': name, 'note': note},
      'Failed to update raw material location',
    );
  }

  Future<bool> deleteRawMaterialLocation(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/raw-material-locations/$encodedCode',
      'Failed to delete raw material location',
    );
  }

  Future<bool> addSupplier(
    String code,
    String name,
    String alias,
    String address,
    String contact,
  ) async {
    return _post('/api/suppliers', {
      'code': code,
      'name': name,
      'alias': alias,
      'address': address,
      'contact': contact,
    }, 'Failed to add supplier');
  }

  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final data = await _get('/api/suppliers', 'Failed to get suppliers');
    return List<Map<String, dynamic>>.from(data['suppliers'] ?? []);
  }

  Future<bool> updateSupplier(
    String code,
    String name,
    String alias,
    String address,
    String contact,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put('/api/suppliers/$encodedCode', {
      'name': name,
      'alias': alias,
      'address': address,
      'contact': contact,
    }, 'Failed to update supplier');
  }

  Future<bool> deleteSupplier(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete('/api/suppliers/$encodedCode', 'Failed to delete supplier');
  }

  Future<bool> addUnit(String code, String nameCN, String nameEN) async {
    return _post('/api/units', {
      'code': code,
      'nameCN': nameCN,
      'nameEN': nameEN,
    }, 'Failed to add unit');
  }

  Future<List<Map<String, dynamic>>> getUnits() async {
    final data = await _get('/api/units', 'Failed to get units');
    return List<Map<String, dynamic>>.from(data['units'] ?? []);
  }

  Future<bool> updateUnit(String code, String nameCN, String nameEN) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put('/api/units/$encodedCode', {
      'nameCN': nameCN,
      'nameEN': nameEN,
    }, 'Failed to update unit');
  }

  Future<bool> deleteUnit(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete('/api/units/$encodedCode', 'Failed to delete unit');
  }

  Future<bool> addRegion(
    String code,
    String nameCN,
    String nameEN,
    String note,
  ) async {
    return _post('/api/regions', {
      'code': code,
      'nameCN': nameCN,
      'nameEN': nameEN,
      'note': note,
    }, 'Failed to add region');
  }

  Future<List<Map<String, dynamic>>> getRegions() async {
    final data = await _get('/api/regions', 'Failed to get regions');
    return List<Map<String, dynamic>>.from(data['regions'] ?? []);
  }

  Future<bool> updateRegion(
    String code,
    String nameCN,
    String nameEN,
    String note,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put('/api/regions/$encodedCode', {
      'nameCN': nameCN,
      'nameEN': nameEN,
      'note': note,
    }, 'Failed to update region');
  }

  Future<bool> deleteRegion(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete('/api/regions/$encodedCode', 'Failed to delete region');
  }

  Future<bool> addStore(String code, String name, String note) async {
    return _post('/api/stores', {
      'code': code,
      'name': name,
      'note': note,
    }, 'Failed to add store');
  }

  Future<List<Map<String, dynamic>>> getStores() async {
    final data = await _get('/api/stores', 'Failed to get stores');
    return List<Map<String, dynamic>>.from(data['stores'] ?? []);
  }

  Future<bool> updateStore(String code, String name, String note) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put('/api/stores/$encodedCode', {
      'name': name,
      'note': note,
    }, 'Failed to update store');
  }

  Future<bool> deleteStore(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete('/api/stores/$encodedCode', 'Failed to delete store');
  }

  Future<bool> addSemiProduct(
    String code,
    String nameCN,
    String nameEN, {
    String? categoryCode,
    String? description,
    String? imagePath,
    List<String>? rawMaterialCodes,
    List<String>? toolCodes,
    List<String>? steps,
  }) async {
    return _post('/api/semi-products', {
      'code': code,
      'nameCN': nameCN,
      'nameEN': nameEN,
      'categoryCode': categoryCode,
      'description': description ?? '',
      'imagePath': imagePath,
      'rawMaterialCodes': rawMaterialCodes ?? [],
      'toolCodes': toolCodes ?? [],
      'steps': steps ?? [],
    }, 'Failed to add semi product');
  }

  Future<List<Map<String, dynamic>>> getSemiProducts() async {
    final data = await _get(
      '/api/semi-products',
      'Failed to get semi products',
    );
    return List<Map<String, dynamic>>.from(data['products'] ?? []);
  }

  Future<bool> updateSemiProduct(
    String code,
    String nameCN,
    String nameEN, {
    String? categoryCode,
    String? description,
    String? imagePath,
    List<String>? rawMaterialCodes,
    List<String>? toolCodes,
    List<String>? steps,
  }) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put('/api/semi-products/$encodedCode', {
      'nameCN': nameCN,
      'nameEN': nameEN,
      'categoryCode': categoryCode,
      'description': description ?? '',
      'imagePath': imagePath,
      'rawMaterialCodes': rawMaterialCodes ?? [],
      'toolCodes': toolCodes ?? [],
      'steps': steps ?? [],
    }, 'Failed to update semi product');
  }

  Future<String?> uploadImage(Uint8List? imageBytes, String? imageFileName) {
    return _uploadImage(imageBytes, imageFileName);
  }

  Future<bool> addSemiProductCategory(
    String code,
    String nameCN,
    String nameEN,
  ) async {
    return _post('/api/semi-product-categories', {
      'code': code,
      'nameCN': nameCN,
      'nameEN': nameEN,
    }, 'Failed to add semi product category');
  }

  Future<List<Map<String, dynamic>>> getSemiProductCategories() async {
    final data = await _get(
      '/api/semi-product-categories',
      'Failed to get semi product categories',
    );
    return List<Map<String, dynamic>>.from(data['categories'] ?? []);
  }

  Future<bool> updateSemiProductCategory(
    String code,
    String nameCN,
    String nameEN,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put(
      '/api/semi-product-categories/$encodedCode',
      {'nameCN': nameCN, 'nameEN': nameEN},
      'Failed to update semi product category',
    );
  }

  Future<bool> deleteSemiProductCategory(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/semi-product-categories/$encodedCode',
      'Failed to delete semi product category',
    );
  }

  Future<bool> deleteSemiProduct(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/semi-products/$encodedCode',
      'Failed to delete semi product',
    );
  }

  Future<bool> addSemiProductStockCheck(
    String semiProductCode,
    String regionCode,
    double weekdayStock,
    double weekendStock,
    double holidayStock,
  ) async {
    final session = SessionService();
    return _post('/api/semi-product-stock-checks', {
      'semiProductCode': semiProductCode,
      'regionCode': regionCode,
      'weekdayStock': weekdayStock,
      'weekendStock': weekendStock,
      'holidayStock': holidayStock,
      'actorUsername': session.username,
      'storeCode': session.storeCode,
    }, 'Failed to add semi product stock check');
  }

  Future<List<Map<String, dynamic>>> getSemiProductStockChecks() async {
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    final path = params.isEmpty
        ? '/api/semi-product-stock-checks'
        : '/api/semi-product-stock-checks?${Uri(queryParameters: params).query}';
    final data = await _get(path, 'Failed to get semi product stock checks');
    return List<Map<String, dynamic>>.from(data['checks'] ?? []);
  }

  Future<bool> updateSemiProductStockCheck(
    int id,
    String semiProductCode,
    String regionCode,
    double weekdayStock,
    double weekendStock,
    double holidayStock,
  ) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    return _put(
      '/api/semi-product-stock-checks/$encodedId',
      {
        'semiProductCode': semiProductCode,
        'regionCode': regionCode,
        'weekdayStock': weekdayStock,
        'weekendStock': weekendStock,
        'holidayStock': holidayStock,
        'actorUsername': session.username,
        'storeCode': session.storeCode,
      },
      'Failed to update semi product stock check',
    );
  }

  Future<bool> deleteSemiProductStockCheck(int id) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    final path = params.isEmpty
        ? '/api/semi-product-stock-checks/$encodedId'
        : '/api/semi-product-stock-checks/$encodedId?${Uri(queryParameters: params).query}';
    return _delete(path, 'Failed to delete semi product stock check');
  }

  Future<bool> addTodoTask(
    String title,
    String content,
    String note,
    String dueDateTime,
    String status, {
    String? ownerUsername,
    int? stockOrderId,
    String? supplierCode,
    String? taskType,
  }) async {
    final session = SessionService();
    return _post('/api/todo-tasks', {
      'title': title,
      'content': content,
      'note': note,
      'dueDateTime': dueDateTime,
      'status': status,
      'actorUsername': session.username,
      'storeCode': session.storeCode,
      'ownerUsername': ownerUsername,
      'stockOrderId': stockOrderId,
      'supplierCode': supplierCode,
      'taskType': taskType,
    }, 'Failed to add todo task');
  }

  Future<List<Map<String, dynamic>>> getTodoTasks() async {
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    if (session.role?.trim().isNotEmpty == true) {
      params['role'] = session.role!.trim();
    }
    final path = params.isEmpty
        ? '/api/todo-tasks'
        : '/api/todo-tasks?${Uri(queryParameters: params).query}';
    final data = await _get(path, 'Failed to get todo tasks');
    return List<Map<String, dynamic>>.from(data['tasks'] ?? []);
  }

  Future<bool> updateTodoTask(
    int id,
    String title,
    String content,
    String note,
    String dueDateTime,
    String status, {
    String? ownerUsername,
    int? stockOrderId,
    String? supplierCode,
    String? taskType,
  }) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    return _put('/api/todo-tasks/$encodedId', {
      'title': title,
      'content': content,
      'note': note,
      'dueDateTime': dueDateTime,
      'status': status,
      'actorUsername': session.username,
      'storeCode': session.storeCode,
      'ownerUsername': ownerUsername,
      'stockOrderId': stockOrderId,
      'supplierCode': supplierCode,
      'taskType': taskType,
    }, 'Failed to update todo task');
  }

  Future<int?> addStockOrder(
    String orderDate,
    List<Map<String, dynamic>> details,
    bool isConfirmed,
  ) async {
    try {
      final session = SessionService();
      final uri = Uri.parse('$baseUrl/api/stock-orders');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderDate': orderDate,
          'details': details,
          'isConfirmed': isConfirmed,
          'actorUsername': session.username,
          'storeCode': session.storeCode,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int?;
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Failed to add stock order: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStockOrders() async {
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    final path = params.isEmpty
        ? '/api/stock-orders'
        : '/api/stock-orders?${Uri(queryParameters: params).query}';
    final data = await _get(path, 'Failed to get stock orders');
    return List<Map<String, dynamic>>.from(data['orders'] ?? []);
  }

  Future<bool> updateStockOrder(
    int id,
    List<Map<String, dynamic>> details,
    bool isConfirmed,
  ) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    return _put('/api/stock-orders/$encodedId', {
      'details': details,
      'isConfirmed': isConfirmed,
      'actorUsername': session.username,
      'storeCode': session.storeCode,
    }, 'Failed to update stock order');
  }

  Future<bool> deleteStockOrder(int id) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    final path = params.isEmpty
        ? '/api/stock-orders/$encodedId'
        : '/api/stock-orders/$encodedId?${Uri(queryParameters: params).query}';
    return _delete(path, 'Failed to delete stock order');
  }

  Future<bool> deleteTodoTask(int id) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    final path = params.isEmpty
        ? '/api/todo-tasks/$encodedId'
        : '/api/todo-tasks/$encodedId?${Uri(queryParameters: params).query}';
    return _delete(path, 'Failed to delete todo task');
  }

  Future<bool> addFinanceRecord(
    String type,
    String recordDate,
    Uint8List? imageBytes,
    double amount,
    String note,
  ) async {
    final session = SessionService();
    final imagePath = await _uploadImage(imageBytes, 'finance.jpg');
    return _post('/api/finance-records', {
      'type': type,
      'recordDate': recordDate,
      'amount': amount,
      'note': note,
      'imagePath': imagePath,
      'actorUsername': session.username,
      'storeCode': session.storeCode,
    }, 'Failed to add finance record');
  }

  Future<List<Map<String, dynamic>>> getFinanceRecords() async {
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    final path = params.isEmpty
        ? '/api/finance-records'
        : '/api/finance-records?${Uri(queryParameters: params).query}';
    final data = await _get(path, 'Failed to get finance records');
    return List<Map<String, dynamic>>.from(data['records'] ?? []);
  }

  Future<bool> updateFinanceRecord(
    int id,
    String type,
    String recordDate,
    Uint8List? imageBytes,
    double amount,
    String note,
  ) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    final imagePath = await _uploadImage(imageBytes, 'finance.jpg');
    final payload = <String, dynamic>{
      'type': type,
      'recordDate': recordDate,
      'amount': amount,
      'note': note,
      'actorUsername': session.username,
      'storeCode': session.storeCode,
    };
    if (imagePath != null) {
      payload['imagePath'] = imagePath;
    }
    return _put(
      '/api/finance-records/$encodedId',
      payload,
      'Failed to update finance record',
    );
  }

  Future<bool> deleteFinanceRecord(int id) async {
    final encodedId = Uri.encodeComponent(id.toString());
    final session = SessionService();
    final params = <String, String>{};
    if (session.username?.trim().isNotEmpty == true) {
      params['username'] = session.username!.trim();
    }
    final path = params.isEmpty
        ? '/api/finance-records/$encodedId'
        : '/api/finance-records/$encodedId?${Uri(queryParameters: params).query}';
    return _delete(path, 'Failed to delete finance record');
  }

  Future<bool> addKitchenTool(
    String code,
    String nameCN,
    String nameEN,
    Uint8List? imageBytes,
    String? imageFileName,
  ) async {
    final imagePath = await _uploadImage(imageBytes, imageFileName);
    return _post('/api/kitchen-tools', {
      'code': code,
      'nameCN': nameCN,
      'nameEN': nameEN,
      'imagePath': imagePath,
    }, 'Failed to add kitchen tool');
  }

  Future<List<Map<String, dynamic>>> getKitchenTools() async {
    final data = await _get(
      '/api/kitchen-tools',
      'Failed to get kitchen tools',
    );
    final tools = List<Map<String, dynamic>>.from(data['tools'] ?? []);
    return tools.map(_decodeImage).toList();
  }

  Future<bool> updateKitchenTool(
    String code,
    String nameCN,
    String nameEN,
    Uint8List? imageBytes,
    String? imageFileName,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    final imagePath = await _uploadImage(imageBytes, imageFileName);
    final payload = <String, dynamic>{'nameCN': nameCN, 'nameEN': nameEN};
    if (imagePath != null) {
      payload['imagePath'] = imagePath;
    }

    return _put(
      '/api/kitchen-tools/$encodedCode',
      payload,
      'Failed to update kitchen tool',
    );
  }

  Future<bool> deleteKitchenTool(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete(
      '/api/kitchen-tools/$encodedCode',
      'Failed to delete kitchen tool',
    );
  }

  Future<bool> addProcess(
    String nameCN,
    String nameEN,
    List<String> toolCodes,
  ) async {
    final response = await _post('/api/processes', {
      'nameCN': nameCN,
      'nameEN': nameEN,
      'toolCodes': toolCodes,
    }, 'Failed to add process');
    return response;
  }

  Future<List<Map<String, dynamic>>> getProcesses() async {
    final data = await _get('/api/processes', 'Failed to get processes');
    return List<Map<String, dynamic>>.from(data['processes'] ?? []);
  }

  Future<bool> updateProcess(
    String code,
    String nameCN,
    String nameEN,
    List<String> toolCodes,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    return _put('/api/processes/$encodedCode', {
      'nameCN': nameCN,
      'nameEN': nameEN,
      'toolCodes': toolCodes,
    }, 'Failed to update process');
  }

  Future<bool> deleteProcess(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete('/api/processes/$encodedCode', 'Failed to delete process');
  }

  Future<bool> addTool(
    String nameCN,
    String nameEN,
    Uint8List? imageBytes,
    String? imageFileName,
  ) async {
    final imagePath = await _uploadImage(imageBytes, imageFileName);
    return _post('/api/tools', {
      'nameCN': nameCN,
      'nameEN': nameEN,
      'imagePath': imagePath,
    }, 'Failed to add tool');
  }

  Future<List<Map<String, dynamic>>> getTools() async {
    final data = await _get('/api/tools', 'Failed to get tools');
    return List<Map<String, dynamic>>.from(data['tools'] ?? []);
  }

  Future<bool> updateTool(
    String code,
    String nameCN,
    String nameEN,
    Uint8List? imageBytes,
    String? imageFileName,
  ) async {
    final encodedCode = Uri.encodeComponent(code);
    final imagePath = await _uploadImage(imageBytes, imageFileName);
    final payload = <String, dynamic>{'nameCN': nameCN, 'nameEN': nameEN};
    if (imagePath != null) {
      payload['imagePath'] = imagePath;
    }

    return _put('/api/tools/$encodedCode', payload, 'Failed to update tool');
  }

  Future<bool> deleteTool(String code) async {
    final encodedCode = Uri.encodeComponent(code);
    return _delete('/api/tools/$encodedCode', 'Failed to delete tool');
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final data = await _get('/api/users', 'Failed to get users');
    return List<Map<String, dynamic>>.from(data['users'] ?? []);
  }

  Future<bool> addUser({
    required String username,
    required String password,
    required String role,
    String? storeCode,
    String uiLanguage = 'ZH',
    required List<String> allowedCategoryCodes,
  }) async {
    return _post('/api/register', {
      'username': username,
      'password': password,
      'role': role,
      'storeCode': storeCode,
      'uiLanguage': uiLanguage,
      'allowedCategoryCodes': allowedCategoryCodes,
    }, 'Failed to add user');
  }

  Future<bool> updateUser({
    required String username,
    String? password,
    required String role,
    String? storeCode,
    String uiLanguage = 'ZH',
    required List<String> allowedCategoryCodes,
  }) async {
    final encodedUsername = Uri.encodeComponent(username);
    return _put('/api/users/$encodedUsername', {
      'password': password,
      'role': role,
      'storeCode': storeCode,
      'uiLanguage': uiLanguage,
      'allowedCategoryCodes': allowedCategoryCodes,
    }, 'Failed to update user');
  }

  Future<bool> deleteUser(String username) async {
    final encodedUsername = Uri.encodeComponent(username);
    return _delete('/api/users/$encodedUsername', 'Failed to delete user');
  }

  Future<Map<String, dynamic>> _get(String path, String message) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$path'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('$message: $e');
    }
  }

  Future<bool> _post(
    String path,
    Map<String, dynamic> payload,
    String message,
  ) async {
    return _sendWithBody('POST', path, payload, message);
  }

  Future<bool> _put(
    String path,
    Map<String, dynamic> payload,
    String message,
  ) async {
    return _sendWithBody('PUT', path, payload, message);
  }

  Future<bool> _sendWithBody(
    String method,
    String path,
    Map<String, dynamic> payload,
    String message,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(payload);
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return true;
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('$message: $e');
    }
  }

  Future<bool> _delete(String path, String message) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl$path'));
      if (response.statusCode == 200) {
        return true;
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('$message: $e');
    }
  }

  Future<String?> _uploadImage(
    Uint8List? imageBytes,
    String? imageFileName,
  ) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      return null;
    }

    try {
      final request =
          http.Request('POST', Uri.parse('$baseUrl/api/uploads/images'))
            ..headers['Content-Type'] = 'application/octet-stream'
            ..headers['x-file-name'] = imageFileName?.trim().isNotEmpty == true
                ? imageFileName!.trim()
                : 'upload.jpg'
            ..bodyBytes = imageBytes;
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['imagePath'] as String?;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Map<String, dynamic> _decodeImage(Map<String, dynamic> tool) {
    final imageUrl = tool['imageUrl'];
    if (imageUrl is String && imageUrl.isNotEmpty) {
      return tool;
    }

    final imageData = tool['imageData'];
    if (imageData is String && imageData.isNotEmpty) {
      tool['imageBytes'] = base64Decode(imageData);
      tool.remove('imageData');
    }
    return tool;
  }
}
