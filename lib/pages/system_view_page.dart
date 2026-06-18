import 'package:flutter/material.dart';

import '../services/system_service.dart';

class SystemViewPage extends StatefulWidget {
  const SystemViewPage({super.key});

  @override
  State<SystemViewPage> createState() => _SystemViewPageState();
}

class _SystemViewPageState extends State<SystemViewPage> {
  final SystemService _service = SystemService();

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _rawMaterials = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _suppliers = const [];
  List<Map<String, dynamic>> _regions = const [];
  List<Map<String, dynamic>> _semiProducts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final rawMaterials = await _service.getRawMaterials();
      final categories = await _service.getRawMaterialCategories();
      final suppliers = await _service.getSuppliers();
      final regions = await _service.getRegions();
      final semiProducts = await _service.getSemiProducts();

      if (!mounted) {
        return;
      }

      setState(() {
        _rawMaterials = rawMaterials;
        _categories = categories;
        _suppliers = suppliers;
        _regions = regions;
        _semiProducts = semiProducts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildPreviewList(
    String title,
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic> item) formatter,
  ) {
    final preview = items.take(6).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title (${items.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (preview.isEmpty)
              const Text('暂无数据')
            else
              ...preview.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(formatter(item)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置（只读）'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '当前账号仅可查看系统数据，不能新增、编辑或删除。',
                    ),
                  ),
                ),
                _buildPreviewList(
                  '原材料分类',
                  _categories,
                  (item) => '${item['code'] ?? '-'} - ${item['name'] ?? '-'}',
                ),
                _buildPreviewList(
                  '原材料',
                  _rawMaterials,
                  (item) => '${item['code'] ?? '-'} - ${item['nameCN'] ?? '-'}',
                ),
                _buildPreviewList(
                  '供应商',
                  _suppliers,
                  (item) => '${item['code'] ?? '-'} - ${item['name'] ?? '-'}',
                ),
                _buildPreviewList(
                  '区域',
                  _regions,
                  (item) => '${item['code'] ?? '-'} - ${item['nameCN'] ?? '-'}',
                ),
                _buildPreviewList(
                  '半成品',
                  _semiProducts,
                  (item) => '${item['code'] ?? '-'} - ${item['nameCN'] ?? '-'}',
                ),
              ],
            ),
    );
  }
}
