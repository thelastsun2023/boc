import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base_url.dart';
import 'session_service.dart';

class MallService {
  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
    String method = 'GET',
  }) async {
    final token = SessionService().token;
    if (token == null) throw Exception('请重新登录后使用商城');
    final request = http.Request(
      method,
      Uri.parse('${getBaseUrl()}/api/mall/$path'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await request.send(),
    ).timeout(const Duration(seconds: 30));
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(data['error'] ?? '请求失败');
    return data;
  }

  Future<List<Map<String, dynamic>>> products() async =>
      List<Map<String, dynamic>>.from((await call('products'))['products']);
  Future<List<Map<String, dynamic>>> orders() async =>
      List<Map<String, dynamic>>.from((await call('orders'))['orders']);
  Future<void> availability(String code, bool out) async {
    await call(
      'products/${Uri.encodeComponent(code)}',
      method: 'PUT',
      body: {'outOfStock': out},
    );
  }

  Future<int> submit(
    List<Map<String, dynamic>> items,
    String key,
    String? store,
  ) async =>
      (await call(
            'orders',
            method: 'POST',
            body: {'items': items, 'submissionKey': key, 'storeCode': store},
          ))['id']
          as int;
  Future<void> item(int order, int item, bool purchased, bool out) async {
    await call(
      'orders/$order/items/$item',
      method: 'PUT',
      body: {'purchased': purchased, 'outOfStock': out},
    );
  }
}
