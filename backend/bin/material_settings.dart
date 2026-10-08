part of 'server.dart';

Future<void> _initMaterialSettings() async {
  await _conn.execute(
      "ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS notes_rich TEXT NOT NULL DEFAULT '[{\"insert\":\"\\n\"}]'");
  await _conn.execute('''CREATE TABLE IF NOT EXISTS raw_material_hidden_stores (
    material_code VARCHAR(255) NOT NULL REFERENCES raw_materials(code) ON DELETE CASCADE,
    store_code VARCHAR(255) NOT NULL REFERENCES stores(code) ON DELETE CASCADE,
    PRIMARY KEY(material_code,store_code))''');
}

Future<_UserScope?> _authenticatedScope(Request request) async {
  final auth = request.headers['authorization'] ?? '';
  if (!auth.startsWith('Bearer ')) return null;
  final rows = await _conn.execute(
      'SELECT username FROM mall_sessions WHERE token_hash=\$1 AND expires_at>CURRENT_TIMESTAMP',
      parameters: [sha256.convert(utf8.encode(auth.substring(7))).toString()]);
  return rows.isEmpty ? null : _getUserScopeByUsername(rows.first[0] as String);
}

Future<Map<String, dynamic>> _materialSettings(
    Map<String, dynamic> data) async {
  final result = <String, dynamic>{};
  if (data.containsKey('notesRich')) {
    final text = data['notesRich'];
    if (text is! String || text.length > 100000)
      throw const FormatException('备注格式无效或过长');
    final delta = jsonDecode(text);
    if (delta is! List ||
        delta.isEmpty ||
        delta.any((op) =>
            op is! Map ||
            op['insert'] is! String ||
            (op['attributes'] != null && op['attributes'] is! Map))) {
      throw const FormatException('备注必须为富文本内容');
    }
    if (!(delta.last['insert'] as String).endsWith('\n'))
      throw const FormatException('备注格式无效');
    result['notesRich'] = jsonEncode(delta);
  }
  if (data.containsKey('visibleStoreCodes')) {
    final values = data['visibleStoreCodes'];
    if (values is! List || values.any((value) => value is! String))
      throw const FormatException('门店选择无效');
    final stores = await _conn.execute('SELECT code FROM stores');
    final valid = stores.map((row) => row[0] as String).toSet();
    if (values.any((value) => !valid.contains(value)))
      throw const FormatException('门店不存在');
    result['hiddenStores'] =
        valid.difference(values.cast<String>().toSet()).toList();
  }
  return result;
}

Future<void> _saveMaterialSettings(
    String code, Map<String, dynamic> settings) async {
  await _conn.runTx((tx) async {
    await tx.execute('SELECT code FROM raw_materials WHERE code=\$1 FOR UPDATE',
        parameters: [code]);
    if (settings.containsKey('notesRich')) {
      await tx.execute('UPDATE raw_materials SET notes_rich=\$1 WHERE code=\$2',
          parameters: [settings['notesRich'], code]);
    }
    if (settings.containsKey('hiddenStores')) {
      await tx.execute(
          'DELETE FROM raw_material_hidden_stores WHERE material_code=\$1',
          parameters: [code]);
      for (final store in settings['hiddenStores'] as List) {
        await tx.execute(
            'INSERT INTO raw_material_hidden_stores VALUES(\$1,\$2)',
            parameters: [code, store]);
      }
    }
  });
}

Future<bool> _materialAvailableForStore(String code, String store) async {
  final rows = await _conn.execute(
      'SELECT 1 FROM raw_material_hidden_stores WHERE material_code=\$1 AND store_code=\$2',
      parameters: [code, store]);
  return rows.isEmpty;
}

Future<bool> _stockMaterialsAllowed(dynamic details, String? store) async {
  if (details is! List || store == null) return false;
  for (final item in details) {
    if (item is! Map || item['code'] is! String) return false;
    if (!await _materialAvailableForStore(item['code'] as String, store))
      return false;
  }
  return true;
}
