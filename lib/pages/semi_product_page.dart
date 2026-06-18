import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/semi_product_detail_codec.dart';
import '../services/session_service.dart';
import '../services/system_service.dart';

class SemiProductPage extends StatefulWidget {
  const SemiProductPage({super.key});

  @override
  State<SemiProductPage> createState() => _SemiProductPageState();
}

class _SemiProductPageState extends State<SemiProductPage> {
  final SystemService _systemService = SystemService();
  final List<Map<String, dynamic>> _semiProducts = [];
  final List<Map<String, dynamic>> _semiProductCategories = [];
  final List<Map<String, dynamic>> _rawMaterials = [];
  final List<Map<String, dynamic>> _units = [];
  final List<Map<String, dynamic>> _kitchenTools = [];
  final List<Map<String, dynamic>> _tools = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedSemiProductCategoryCode;

  bool get _isEnglish => SessionService().isEnglish;

  String _orderedName(String? nameCN, String? nameEN) {
    final cn = (nameCN ?? '').trim();
    final en = (nameEN ?? '').trim();
    if (cn.isEmpty) {
      return en;
    }
    if (en.isEmpty) {
      return cn;
    }
    return _isEnglish ? '$en / $cn' : '$cn / $en';
  }

  String _orderedNameWithCode(String? nameCN, String? nameEN, String code) {
    final ordered = _orderedName(nameCN, nameEN);
    if (ordered.isEmpty) {
      return code;
    }
    return '$ordered ($code)';
  }

  List<Map<String, dynamic>> get _filteredSemiProducts {
    if (_selectedSemiProductCategoryCode == null) {
      return _semiProducts;
    }
    if (_selectedSemiProductCategoryCode == '__UNCATEGORIZED__') {
      return _semiProducts.where((item) {
        final categoryCode = (item['categoryCode'] as String?)?.trim();
        return categoryCode == null || categoryCode.isEmpty;
      }).toList();
    }
    return _semiProducts.where((item) {
      final categoryCode = (item['categoryCode'] as String?)?.trim();
      return categoryCode == _selectedSemiProductCategoryCode;
    }).toList();
  }

  List<Map<String, dynamic>> get _semiProductFilterOptions {
    final options = <Map<String, dynamic>>[
      {'code': null, 'label': '全部', 'count': _semiProducts.length},
    ];

    for (final category in _semiProductCategories) {
      final code = (category['code'] as String?)?.trim();
      if (code == null || code.isEmpty) {
        continue;
      }
      final count = _semiProducts.where((item) {
        final itemCode = (item['categoryCode'] as String?)?.trim();
        return itemCode == code;
      }).length;
      options.add({
        'code': code,
        'label': _orderedName(
          category['nameCN'] as String?,
          category['nameEN'] as String?,
        ),
        'count': count,
      });
    }

    final uncategorizedCount = _semiProducts.where((item) {
      final categoryCode = (item['categoryCode'] as String?)?.trim();
      return categoryCode == null || categoryCode.isEmpty;
    }).length;
    if (uncategorizedCount > 0) {
      options.add({
        'code': '__UNCATEGORIZED__',
        'label': '未分类',
        'count': uncategorizedCount,
      });
    }

    return options;
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final products = await _systemService.getSemiProducts();
      final categories = await _systemService.getSemiProductCategories();
      final materials = await _systemService.getRawMaterials();
      final units = await _systemService.getUnits();
      final kitchenTools = await _systemService.getKitchenTools();
      final tools = await _systemService.getTools();

      if (!mounted) {
        return;
      }

      setState(() {
        _semiProducts
          ..clear()
          ..addAll(products);
        _semiProductCategories
          ..clear()
          ..addAll(categories);
        _rawMaterials
          ..clear()
          ..addAll(materials);
        _units
          ..clear()
          ..addAll(units);
        _kitchenTools
          ..clear()
          ..addAll(kitchenTools);
        _tools
          ..clear()
          ..addAll(tools);
        final hasSelectedCategory =
            _selectedSemiProductCategoryCode == null ||
            _semiProductFilterOptions.any(
              (option) => option['code'] == _selectedSemiProductCategoryCode,
            );
        if (!hasSelectedCategory) {
          _selectedSemiProductCategoryCode = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _generateCode(String prefix, List<Map<String, dynamic>> items) {
    final existingCodes = items
        .map((item) => item['code'] as String?)
        .whereType<String>()
        .toSet();
    var nextNumber = 1;
    while (true) {
      final nextCode = '$prefix${nextNumber.toString().padLeft(3, '0')}';
      if (!existingCodes.contains(nextCode)) {
        return nextCode;
      }
      nextNumber++;
    }
  }

  String _displayImageUrl(String imageUrl) {
    // Relative path (e.g. /uploads/images/xxx.jpg) → prepend baseUrl
    if (imageUrl.startsWith('/uploads/')) {
      return '${_systemService.baseUrl}$imageUrl';
    }
    // Legacy absolute localhost URL → replace host with current baseUrl
    if (imageUrl.startsWith('http://127.0.0.1') ||
        imageUrl.startsWith('http://localhost')) {
      final uri = Uri.parse(imageUrl);
      final base = Uri.parse(_systemService.baseUrl);
      return uri
          .replace(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : 0,
          )
          .toString();
    }
    return imageUrl;
  }

  String _rawMaterialOptionLabel(Map<String, dynamic> material) {
    final code = material['code'] as String? ?? '';
    final nameCN = material['nameCN'] as String? ?? '';
    final nameEN = material['nameEN'] as String? ?? '';
    return _orderedNameWithCode(nameCN, nameEN, code);
  }

  String _toolOptionLabel(Map<String, dynamic> tool) {
    final code = tool['code'] as String? ?? '';
    final nameCN = tool['nameCN'] as String? ?? '';
    final nameEN = tool['nameEN'] as String? ?? '';
    return _orderedNameWithCode(nameCN, nameEN, code);
  }

  String _semiProductOptionLabel(Map<String, dynamic> product) {
    final code = product['code'] as String? ?? '';
    final nameCN = product['nameCN'] as String? ?? '';
    final nameEN = product['nameEN'] as String? ?? '';
    return _orderedNameWithCode(nameCN, nameEN, code);
  }

  String _unitOptionLabel(Map<String, dynamic> unit) {
    final code = unit['code'] as String? ?? '';
    final nameCN = unit['nameCN'] as String? ?? '';
    final nameEN = unit['nameEN'] as String? ?? '';
    return _orderedNameWithCode(nameCN, nameEN, code);
  }

  String _unitDisplayText(String unitLabel, String unitCode) {
    final label = unitLabel.trim();
    if (label.isEmpty) {
      return '';
    }

    final codePattern = RegExp(r'\s*\([^)]+\)$');
    return label.replaceAll(codePattern, '').trimRight();
  }

  String _formatNumber(double value) {
    final normalized = value.toStringAsFixed(4);
    return normalized
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatScaledQuantity(String quantityValue, double multiplier) {
    final parsedValue = double.tryParse(quantityValue.trim());
    if (parsedValue == null) {
      return quantityValue;
    }
    return _formatNumber(parsedValue * multiplier);
  }

  bool _matchesSearchText(String source, String keyword) {
    final normalizedSource = source.trim().toLowerCase();
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return true;
    }
    return normalizedSource.contains(normalizedKeyword);
  }

  List<Map<String, String>> _buildRawMaterialSummaryEntries(
    List<Map<String, dynamic>> detailEntries,
    double multiplier,
  ) {
    final summaryByKey = <String, Map<String, String>>{};
    final orderedKeys = <String>[];

    for (final detail in detailEntries) {
      if (detail['type'] != semiProductDetailTypeRawMaterial) {
        continue;
      }

      final referenceCode = (detail['referenceCode'] as String? ?? '').trim();
      final referenceLabel = (detail['referenceLabel'] as String? ?? '').trim();
      final quantityValue = (detail['quantityValue'] as String? ?? '').trim();
      final unitLabel = (detail['unitLabel'] as String? ?? '').trim();
      final unitCode = (detail['unitCode'] as String? ?? '').trim();
      final rawMaterial = _findByCode(_rawMaterials, referenceCode);
      final materialName =
          (rawMaterial?['nameCN'] as String?)?.trim().isNotEmpty == true
          ? (rawMaterial!['nameCN'] as String).trim()
          : (referenceLabel.isNotEmpty ? referenceLabel : referenceCode);
      final unitText = _unitDisplayText(unitLabel, unitCode);
      final key = '$materialName|$unitText';
      final scaledValue = double.tryParse(quantityValue);

      if (scaledValue != null) {
        if (!summaryByKey.containsKey(key)) {
          summaryByKey[key] = {
            'name': materialName,
            'amount': _formatNumber(scaledValue * multiplier),
            'unit': unitText,
          };
          orderedKeys.add(key);
        } else {
          final currentAmount =
              double.tryParse(summaryByKey[key]!['amount'] ?? '0') ?? 0;
          summaryByKey[key]!['amount'] = _formatNumber(
            currentAmount + scaledValue * multiplier,
          );
        }
        continue;
      }

      if (!summaryByKey.containsKey(key)) {
        summaryByKey[key] = {
          'name': materialName,
          'amount': _formatScaledQuantity(quantityValue, multiplier),
          'unit': unitText,
        };
        orderedKeys.add(key);
      }
    }

    return orderedKeys
        .map((key) => summaryByKey[key]!)
        .where((entry) => (entry['name'] ?? '').trim().isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _createDetailEntry(int id, {String? type}) {
    return {
      'id': id,
      'type': type ?? semiProductDetailTypeStep,
      'referenceCode': '',
      'referenceLabel': '',
      'quantityValue': '',
      'unitCode': '',
      'unitLabel': '',
      'kitchenToolCode': '',
      'kitchenToolLabel': '',
      'imagePath': '',
      'imageUrl': '',
      'imageBytes': null,
      'imageFileName': '',
      'description': '',
    };
  }

  void _moveProductDetailToEnd(List<Map<String, dynamic>> details) {
    final productIndex = details.indexWhere(
      (detail) => detail['type'] == semiProductDetailTypeProduct,
    );
    if (productIndex == -1 || productIndex == details.length - 1) {
      return;
    }
    final productDetail = details.removeAt(productIndex);
    details.add(productDetail);
  }

  Future<({Uint8List bytes, String fileName})?>
  _pickAndCropFinishedImage() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) {
      return null;
    }

    final bytes = await imageFile.readAsBytes();
    if (!mounted) {
      return null;
    }
    final controller = CropController();
    var isCropping = false;

    return showDialog<({Uint8List bytes, String fileName})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('裁剪成品图片'),
            content: SizedBox(
              width: 380,
              height: 520,
              child: Column(
                children: [
                  Expanded(
                    child: Crop(
                      controller: controller,
                      image: bytes,
                      aspectRatio: 1,
                      interactive: true,
                      withCircleUi: false,
                      baseColor: Colors.black,
                      maskColor: Colors.black.withValues(alpha: 0.45),
                      radius: 12,
                      onCropped: (result) {
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            final decoded = img.decodeImage(croppedImage);
                            if (decoded == null) {
                              if (mounted) {
                                Navigator.of(context).pop();
                              }
                              return;
                            }
                            final resized = img.copyResize(
                              decoded,
                              width: 600,
                              height: 600,
                            );
                            final finalBytes = Uint8List.fromList(
                              img.encodeJpg(resized, quality: 90),
                            );
                            if (mounted) {
                              Navigator.of(context).pop((
                                bytes: finalBytes,
                                fileName: imageFile.name,
                              ));
                            }
                          case CropFailure():
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '拖动和缩放图片，保存为 600 x 600。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isCropping
                        ? null
                        : () {
                            setDialogState(() {
                              isCropping = true;
                            });
                            controller.crop();
                          },
                    child: Text(isCropping ? '正在裁剪...' : '保存图片'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic>? _findByCode(
    List<Map<String, dynamic>> items,
    String? code,
  ) {
    if (code == null || code.trim().isEmpty) {
      return null;
    }
    for (final item in items) {
      if (item['code'] == code) {
        return item;
      }
    }
    return null;
  }

  Widget _buildNetworkImage(String? imageUrl, {double height = 120}) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: const Text('无图片'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        _displayImageUrl(imageUrl),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: const Text('图片加载失败'),
        ),
      ),
    );
  }

  Widget _buildSquareImagePreview({
    Uint8List? imageBytes,
    String? imageUrl,
    double dimension = 140,
  }) {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          imageBytes,
          width: dimension,
          height: dimension,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox.square(
      dimension: dimension,
      child: _buildNetworkImage(imageUrl, height: dimension),
    );
  }

  Future<void> _showZoomableImage(String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    _displayImageUrl(imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(minHeight: 240),
                      child: const Text('图片加载失败'),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: '关闭',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSemiProductPreview(Map<String, dynamic> item) async {
    final detailEntries = decodeSemiProductDetails(
      item['steps'] as List<dynamic>?,
    );
    final hasProductDetail = detailEntries.any(
      (detail) => detail['type'] == semiProductDetailTypeProduct,
    );
    final currentImagePath = (item['imagePath'] as String? ?? '').trim();
    final currentImageUrl = (item['imageUrl'] as String? ?? '').trim();
    if (!hasProductDetail &&
        (currentImagePath.isNotEmpty || currentImageUrl.isNotEmpty)) {
      detailEntries.add({
        'type': semiProductDetailTypeProduct,
        'referenceCode': '',
        'referenceLabel': '成品图片',
        'kitchenToolCode': '',
        'kitchenToolLabel': '',
        'imagePath': currentImagePath,
        'imageUrl': currentImageUrl,
        'description': '',
      });
    }
    final scrollController = ScrollController();
    final multiplierController = TextEditingController(text: '1');
    double materialMultiplier = 1;
    bool isMultiplierAlertOpen = false;
    final multiplierOptions = List<double>.generate(11, (index) => 0.5 * index);

    Future<void> showMultiplierAlert(String message) async {
      if (isMultiplierAlertOpen || !mounted) {
        return;
      }
      isMultiplierAlertOpen = true;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('倍率输入错误'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      isMultiplierAlertOpen = false;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final nameCN = (item['nameCN'] as String? ?? '').trim();
          final nameEN = (item['nameEN'] as String? ?? '').trim();
          final rawMaterialSummaryEntries = _buildRawMaterialSummaryEntries(
            detailEntries,
            materialMultiplier,
          );
          final baseDetailStyle =
              theme.textTheme.bodyLarge ?? const TextStyle();
          final detailTextStyle = baseDetailStyle.copyWith(
            fontSize: (baseDetailStyle.fontSize ?? 14) + 10,
          );
          final detailTitleStyle = detailTextStyle.copyWith(
            fontWeight: FontWeight.w600,
          );
          final rawMaterialDescriptionStyle = detailTextStyle.copyWith(
            fontSize: (detailTextStyle.fontSize ?? 24) + 6,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade900,
          );
          final quantityTextStyle = detailTextStyle.copyWith(
            fontSize: (detailTextStyle.fontSize ?? 24) + 4,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
          );
          final orderedName = _orderedName(nameCN, nameEN);

          return AlertDialog(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  orderedName.isEmpty
                      ? (item['code'] as String? ?? '')
                      : orderedName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((item['categoryNameCN'] as String?)
                                ?.trim()
                                .isNotEmpty ==
                            true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '分类: ${_orderedName(item['categoryNameCN'] as String?, item['categoryNameEN'] as String?)}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if ((item['description'] as String?)
                                ?.trim()
                                .isNotEmpty ==
                            true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              item['description'] as String,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '使用原材料',
                                style: detailTitleStyle.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              if (rawMaterialSummaryEntries.isEmpty)
                                Text(
                                  '暂无原材料',
                                  style: detailTextStyle.copyWith(fontSize: 18),
                                )
                              else
                                ...rawMaterialSummaryEntries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${entry['name']}: ${entry['amount']}${(entry['unit'] ?? '').isEmpty ? '' : ' ${entry['unit']}'}',
                                      style: detailTextStyle.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '原材料用量',
                                style: detailTitleStyle.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: multiplierController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: '倍率',
                                  hintText: '0 - 5',
                                  suffixIcon: PopupMenuButton<double>(
                                    tooltip: '选择倍率',
                                    icon: const Icon(Icons.arrow_drop_down),
                                    onSelected: (value) {
                                      setDialogState(() {
                                        materialMultiplier = value;
                                        multiplierController.text =
                                            _formatNumber(value);
                                      });
                                    },
                                    itemBuilder: (context) => multiplierOptions
                                        .map(
                                          (value) => PopupMenuItem<double>(
                                            value: value,
                                            child: Text(
                                              '${_formatNumber(value)} 倍',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                onChanged: (value) {
                                  final trimmed = value.trim();
                                  if (trimmed.isEmpty) {
                                    return;
                                  }
                                  if (!RegExp(
                                    r'^\d*\.?\d*$',
                                  ).hasMatch(trimmed)) {
                                    showMultiplierAlert('倍率只能输入数字和小数点。');
                                    return;
                                  }

                                  final parsed = double.tryParse(trimmed);
                                  if (parsed == null) {
                                    showMultiplierAlert('请输入有效的数字倍率。');
                                    return;
                                  }
                                  if (parsed < 0 || parsed > 5) {
                                    showMultiplierAlert('倍率范围只能是 0 到 5。');
                                    return;
                                  }
                                  setDialogState(() {
                                    materialMultiplier = parsed;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '默认一倍，可点选 0 到 5 的 0.5 步进倍率，也可手动输入；输入非数字字符会警告且不参与计算。',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '详情',
                          style: detailTitleStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (detailEntries.isEmpty)
                          Text('暂无详情', style: detailTextStyle)
                        else
                          ...detailEntries.asMap().entries.map((entry) {
                            final index = entry.key;
                            final detail = entry.value;
                            final detailType =
                                detail['type'] ?? semiProductDetailTypeStep;
                            final referenceCode = detail['referenceCode'] ?? '';
                            final referenceLabel =
                                detail['referenceLabel'] ?? '';
                            final quantityValue = detail['quantityValue'] ?? '';
                            final unitLabel = detail['unitLabel'] ?? '';
                            final unitCode = detail['unitCode'] ?? '';
                            final kitchenToolCode =
                                detail['kitchenToolCode'] ?? '';
                            final kitchenToolLabel =
                                detail['kitchenToolLabel'] ?? '';
                            final imageUrl = detail['imageUrl'] ?? '';
                            final description = detail['description'] ?? '';
                            final rawMaterial =
                                detailType == semiProductDetailTypeRawMaterial
                                ? _findByCode(_rawMaterials, referenceCode)
                                : null;
                            final referencedSemiProduct =
                                detailType == semiProductDetailTypeSemiProduct
                                ? _findByCode(_semiProducts, referenceCode)
                                : null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${index + 1}. ${semiProductDetailTypeLabel(detailType)}',
                                      style: detailTitleStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    if (detailType ==
                                            semiProductDetailTypeRawMaterial &&
                                        rawMaterial != null) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _rawMaterialOptionLabel(
                                                    rawMaterial,
                                                  ),
                                                  style: detailTextStyle,
                                                  textAlign: TextAlign.left,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  quantityValue.trim().isEmpty
                                                      ? '用量: -'
                                                      : '用量: ${_formatScaledQuantity(quantityValue, materialMultiplier)} ${_unitDisplayText(unitLabel, unitCode)}',
                                                  style: quantityTextStyle,
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '使用厨具: ${kitchenToolLabel.isNotEmpty ? kitchenToolLabel : (kitchenToolCode.isEmpty ? '-' : kitchenToolCode)}',
                                                  style: detailTextStyle,
                                                  textAlign: TextAlign.left,
                                                ),
                                                if (description
                                                    .trim()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      description,
                                                      style:
                                                          rawMaterialDescriptionStyle,
                                                      textAlign: TextAlign.left,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () {
                                                final imageUrl =
                                                    rawMaterial['imageUrl']
                                                        as String?;
                                                if (imageUrl == null ||
                                                    imageUrl.trim().isEmpty) {
                                                  return;
                                                }
                                                _showZoomableImage(imageUrl);
                                              },
                                              child: SizedBox.square(
                                                dimension: 180,
                                                child: _buildNetworkImage(
                                                  rawMaterial['imageUrl']
                                                      as String?,
                                                  height: 180,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (detailType ==
                                        semiProductDetailTypeRawMaterial) ...[
                                      Text(
                                        referenceLabel.isEmpty
                                            ? (referenceCode.isEmpty
                                                  ? '-'
                                                  : referenceCode)
                                            : referenceLabel,
                                        style: detailTextStyle,
                                        textAlign: TextAlign.left,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        quantityValue.trim().isEmpty
                                            ? '用量: -'
                                            : '用量: ${_formatScaledQuantity(quantityValue, materialMultiplier)} ${_unitDisplayText(unitLabel, unitCode)}',
                                        style: quantityTextStyle,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '使用厨具: ${kitchenToolLabel.isNotEmpty ? kitchenToolLabel : (kitchenToolCode.isEmpty ? '-' : kitchenToolCode)}',
                                        style: detailTextStyle,
                                        textAlign: TextAlign.left,
                                      ),
                                      if (description.trim().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            description,
                                            style: rawMaterialDescriptionStyle,
                                            textAlign: TextAlign.left,
                                          ),
                                        ),
                                      ],
                                    ] else if (detailType ==
                                        semiProductDetailTypeProduct) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '成品图片',
                                                  style: detailTextStyle,
                                                  textAlign: TextAlign.left,
                                                ),
                                                if (description
                                                    .trim()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      description,
                                                      style:
                                                          rawMaterialDescriptionStyle,
                                                      textAlign: TextAlign.left,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () {
                                                final resolvedImageUrl =
                                                    imageUrl.isNotEmpty
                                                    ? imageUrl
                                                    : currentImageUrl;
                                                if (resolvedImageUrl.isEmpty) {
                                                  return;
                                                }
                                                _showZoomableImage(
                                                  resolvedImageUrl,
                                                );
                                              },
                                              child: _buildSquareImagePreview(
                                                imageUrl: imageUrl.isNotEmpty
                                                    ? imageUrl
                                                    : currentImageUrl,
                                                dimension: 180,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (detailType ==
                                        semiProductDetailTypeSemiProduct) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  referencedSemiProduct == null
                                                      ? (referenceLabel.isEmpty
                                                            ? (referenceCode
                                                                      .isEmpty
                                                                  ? '-'
                                                                  : referenceCode)
                                                            : referenceLabel)
                                                      : _semiProductOptionLabel(
                                                          referencedSemiProduct,
                                                        ),
                                                  style: detailTextStyle,
                                                  textAlign: TextAlign.left,
                                                ),
                                                if (description
                                                    .trim()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    description,
                                                    style: detailTextStyle,
                                                    textAlign: TextAlign.left,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap: () {
                                                final referencedImageUrl =
                                                    referencedSemiProduct ==
                                                        null
                                                    ? ''
                                                    : (referencedSemiProduct['imageUrl']
                                                              as String? ??
                                                          '');
                                                if (referencedImageUrl
                                                    .trim()
                                                    .isEmpty) {
                                                  return;
                                                }
                                                _showZoomableImage(
                                                  referencedImageUrl,
                                                );
                                              },
                                              child: _buildSquareImagePreview(
                                                imageUrl:
                                                    referencedSemiProduct ==
                                                        null
                                                    ? null
                                                    : referencedSemiProduct['imageUrl']
                                                          as String?,
                                                dimension: 180,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (detailType ==
                                        semiProductDetailTypeTool) ...[
                                      Text(
                                        referenceLabel.isEmpty
                                            ? (referenceCode.isEmpty
                                                  ? '-'
                                                  : referenceCode)
                                            : referenceLabel,
                                        style: detailTextStyle,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                    if (detailType !=
                                            semiProductDetailTypeRawMaterial &&
                                        detailType !=
                                            semiProductDetailTypeProduct &&
                                        detailType !=
                                            semiProductDetailTypeSemiProduct &&
                                        description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              detailType ==
                                                  semiProductDetailTypeRawMaterial
                                              ? Colors.red.shade50
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          description,
                                          style:
                                              detailType ==
                                                  semiProductDetailTypeRawMaterial
                                              ? rawMaterialDescriptionStyle
                                              : detailTextStyle,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
    scrollController.dispose();
    multiplierController.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSemiProductCategoryDialog({
    Map<String, dynamic>? item,
  }) async {
    final isEdit = item != null;
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑半成品分类' : '添加半成品分类'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Code: ${item['code']}'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCNController,
                decoration: const InputDecoration(labelText: '中文名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameENController,
                decoration: const InputDecoration(labelText: '英文名称'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final nameCN = nameCNController.text.trim();
              final nameEN = nameENController.text.trim();
              if (nameCN.isEmpty) {
                return;
              }
              try {
                final success = isEdit
                    ? await _systemService.updateSemiProductCategory(
                        item['code'] as String,
                        nameCN,
                        nameEN,
                      )
                    : await _systemService.addSemiProductCategory(
                        _generateCode('SPC', _semiProductCategories),
                        nameCN,
                        nameEN,
                      );
                if (success) {
                  await _loadAllData();
                  if (mounted) {
                    navigator.pop();
                  }
                }
              } catch (e) {
                if (mounted) {
                  _showMessage('${isEdit ? 'Update' : 'Create'} failed: $e');
                }
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSemiProductCategoriesManager() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('半成品分类'),
        content: SizedBox(
          width: 460,
          child: _semiProductCategories.isEmpty
              ? const Center(child: Text('No categories'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _semiProductCategories.length,
                  itemBuilder: (context, index) {
                    final item = _semiProductCategories[index];
                    final orderedName = _orderedName(
                      item['nameCN'] as String?,
                      item['nameEN'] as String?,
                    );
                    return ListTile(
                      title: Text(orderedName.isEmpty ? '-' : orderedName),
                      subtitle: Text(item['code'] as String? ?? '-'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _showSemiProductCategoryDialog(item: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(
                              title: item['nameCN'] as String? ?? '-',
                              onDelete: () =>
                                  _systemService.deleteSemiProductCategory(
                                    item['code'] as String,
                                  ),
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: _showSemiProductCategoryDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete({
    required String title,
    required Future<bool> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete $title from the database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final success = await onDelete();
      if (success) {
        await _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Delete failed: $e');
      }
    }
  }

  Future<void> _showSemiProductDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final currentSemiProductCode =
        item?['code'] as String? ?? _generateCode('CURN', _semiProducts);
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );
    final descriptionController = TextEditingController(
      text: item?['description'] as String? ?? '',
    );
    String? selectedCategoryCode = item?['categoryCode'] as String?;
    final selectedRawMaterials = <String>[];
    final selectedToolCodes = <String>[];
    final detailEntries = <Map<String, dynamic>>[];
    var nextDetailId = 0;

    if (item != null) {
      selectedRawMaterials.addAll(
        List<String>.from(item['rawMaterialCodes'] as List<dynamic>? ?? []),
      );
      selectedToolCodes.addAll(
        List<String>.from(item['toolCodes'] as List<dynamic>? ?? []),
      );
      for (final detail in decodeSemiProductDetails(
        item['steps'] as List<dynamic>?,
      )) {
        final entry = _createDetailEntry(
          nextDetailId++,
          type: detail['type'] ?? semiProductDetailTypeStep,
        );
        entry['referenceCode'] = detail['referenceCode'] ?? '';
        entry['referenceLabel'] = detail['referenceLabel'] ?? '';
        entry['quantityValue'] = detail['quantityValue'] ?? '';
        entry['unitCode'] = detail['unitCode'] ?? '';
        entry['unitLabel'] = detail['unitLabel'] ?? '';
        entry['kitchenToolCode'] = detail['kitchenToolCode'] ?? '';
        entry['kitchenToolLabel'] = detail['kitchenToolLabel'] ?? '';
        entry['imagePath'] = detail['imagePath'] ?? '';
        entry['imageUrl'] = detail['imageUrl'] ?? '';
        entry['description'] = detail['description'] ?? '';
        if (entry['type'] == semiProductDetailTypeProduct) {
          entry['imagePath'] = (detail['imagePath'] ?? '').trim().isNotEmpty
              ? detail['imagePath']
              : item['imagePath'] ?? '';
          entry['imageUrl'] = (detail['imageUrl'] ?? '').trim().isNotEmpty
              ? detail['imageUrl']
              : item['imageUrl'] ?? '';
        }
        detailEntries.add(entry);
      }

      final existingImagePath = (item['imagePath'] as String? ?? '').trim();
      final existingImageUrl = (item['imageUrl'] as String? ?? '').trim();
      final hasProductDetail = detailEntries.any(
        (detail) => detail['type'] == semiProductDetailTypeProduct,
      );
      if (!hasProductDetail &&
          (existingImagePath.isNotEmpty || existingImageUrl.isNotEmpty)) {
        final productEntry = _createDetailEntry(
          nextDetailId++,
          type: semiProductDetailTypeProduct,
        );
        productEntry['imagePath'] = existingImagePath;
        productEntry['imageUrl'] = existingImageUrl;
        detailEntries.add(productEntry);
      }
    }

    if (detailEntries.isEmpty) {
      detailEntries.add(_createDetailEntry(nextDetailId++));
    }
    _moveProductDetailToEnd(detailEntries);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableSemiProducts = _semiProducts
              .where((product) => product['code'] != currentSemiProductCode)
              .toList();

          return AlertDialog(
            title: Text(isEdit ? '编辑半成品' : '添加半成品'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEdit)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Code: ${item['code']}'),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCNController,
                      decoration: const InputDecoration(labelText: '中文名称'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameENController,
                      decoration: const InputDecoration(labelText: '英文名称'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: '描述'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedCategoryCode,
                      decoration: const InputDecoration(labelText: '分类'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('未分类'),
                        ),
                        ..._semiProductCategories.map((category) {
                          final code = category['code'] as String;
                          final nameCN = category['nameCN'] as String? ?? '';
                          final nameEN = category['nameEN'] as String? ?? '';
                          final label = _orderedNameWithCode(
                            nameCN,
                            nameEN,
                            code,
                          );
                          return DropdownMenuItem<String?>(
                            value: code,
                            child: Text(label, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryCode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '详情',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              detailEntries.add(
                                _createDetailEntry(nextDetailId++),
                              );
                              _moveProductDetailToEnd(detailEntries);
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: '添加一行详情',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: detailEntries.length,
                      onReorder: (oldIndex, newIndex) {
                        setDialogState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final movedItem = detailEntries.removeAt(oldIndex);
                          detailEntries.insert(newIndex, movedItem);
                          _moveProductDetailToEnd(detailEntries);
                        });
                      },
                      itemBuilder: (context, index) {
                        final detail = detailEntries[index];
                        final detailType =
                            detail['type'] as String? ??
                            semiProductDetailTypeStep;
                        final selectedReferenceCode =
                            detail['referenceCode'] as String? ?? '';
                        final selectedReferenceLabel =
                            detail['referenceLabel'] as String? ?? '';
                        final selectedQuantityValue =
                            detail['quantityValue'] as String? ?? '';
                        final selectedUnitCode =
                            detail['unitCode'] as String? ?? '';
                        final selectedUnitLabel =
                            detail['unitLabel'] as String? ?? '';
                        final selectedKitchenToolCode =
                            detail['kitchenToolCode'] as String? ?? '';
                        final selectedKitchenToolLabel =
                            detail['kitchenToolLabel'] as String? ?? '';
                        final selectedImagePath =
                            detail['imagePath'] as String? ?? '';
                        final selectedImageUrl =
                            detail['imageUrl'] as String? ?? '';
                        final selectedImageBytes =
                            detail['imageBytes'] as Uint8List?;
                        final selectedSemiProduct =
                            detailType == semiProductDetailTypeSemiProduct
                            ? _findByCode(_semiProducts, selectedReferenceCode)
                            : null;
                        return Card(
                          key: ValueKey('detail-card-${detail['id']}'),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${index + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 120,
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        detail['type'] as String? ??
                                        semiProductDetailTypeStep,
                                    decoration: const InputDecoration(
                                      labelText: '类型',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: semiProductDetailTypeRawMaterial,
                                        child: Text('原材料'),
                                      ),
                                      DropdownMenuItem(
                                        value: semiProductDetailTypeProduct,
                                        child: Text('成品'),
                                      ),
                                      DropdownMenuItem(
                                        value: semiProductDetailTypeSemiProduct,
                                        child: Text('半成品'),
                                      ),
                                      DropdownMenuItem(
                                        value: semiProductDetailTypeStep,
                                        child: Text('步骤'),
                                      ),
                                      DropdownMenuItem(
                                        value: semiProductDetailTypeTool,
                                        child: Text('实用工具'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      if (value ==
                                              semiProductDetailTypeProduct &&
                                          detailEntries.any(
                                            (entry) =>
                                                entry['type'] ==
                                                    semiProductDetailTypeProduct &&
                                                entry['id'] != detail['id'],
                                          )) {
                                        _showMessage('每个半成品只能有一条成品');
                                        return;
                                      }
                                      setDialogState(() {
                                        detail['type'] = value;
                                        detail['referenceCode'] = '';
                                        detail['referenceLabel'] = '';
                                        detail['quantityValue'] = '';
                                        detail['unitCode'] = '';
                                        detail['unitLabel'] = '';
                                        detail['kitchenToolCode'] = '';
                                        detail['kitchenToolLabel'] = '';
                                        detail['imagePath'] = '';
                                        detail['imageUrl'] = '';
                                        detail['imageBytes'] = null;
                                        detail['imageFileName'] = '';
                                        _moveProductDetailToEnd(detailEntries);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    children: [
                                      if (detailType ==
                                          semiProductDetailTypeRawMaterial)
                                        Autocomplete<Map<String, dynamic>>(
                                          key: ValueKey('raw-${detail['id']}'),
                                          initialValue: TextEditingValue(
                                            text:
                                                selectedReferenceLabel
                                                    .isNotEmpty
                                                ? selectedReferenceLabel
                                                : selectedReferenceCode,
                                          ),
                                          displayStringForOption:
                                              _rawMaterialOptionLabel,
                                          optionsBuilder:
                                              (
                                                TextEditingValue
                                                textEditingValue,
                                              ) {
                                                final keyword =
                                                    textEditingValue.text;
                                                return _rawMaterials.where((
                                                  material,
                                                ) {
                                                  final searchText = [
                                                    material['code']
                                                            as String? ??
                                                        '',
                                                    material['nameCN']
                                                            as String? ??
                                                        '',
                                                    material['nameEN']
                                                            as String? ??
                                                        '',
                                                    _rawMaterialOptionLabel(
                                                      material,
                                                    ),
                                                  ].join(' ');
                                                  return _matchesSearchText(
                                                    searchText,
                                                    keyword,
                                                  );
                                                });
                                              },
                                          onSelected: (selection) {
                                            setDialogState(() {
                                              detail['referenceCode'] =
                                                  selection['code']
                                                      as String? ??
                                                  '';
                                              detail['referenceLabel'] =
                                                  _rawMaterialOptionLabel(
                                                    selection,
                                                  );
                                            });
                                          },
                                          fieldViewBuilder:
                                              (
                                                context,
                                                textEditingController,
                                                focusNode,
                                                onFieldSubmitted,
                                              ) {
                                                return TextFormField(
                                                  controller:
                                                      textEditingController,
                                                  focusNode: focusNode,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: '选择原材料',
                                                        hintText:
                                                            '输入中文 / 英文 / 编号搜索',
                                                        prefixIcon: Icon(
                                                          Icons.search,
                                                        ),
                                                      ),
                                                  onChanged: (value) {
                                                    final trimmed = value
                                                        .trim();
                                                    if (trimmed.isEmpty) {
                                                      detail['referenceCode'] =
                                                          '';
                                                      detail['referenceLabel'] =
                                                          '';
                                                      return;
                                                    }

                                                    if (trimmed !=
                                                        selectedReferenceLabel) {
                                                      detail['referenceCode'] =
                                                          '';
                                                      detail['referenceLabel'] =
                                                          trimmed;
                                                    }
                                                  },
                                                  onFieldSubmitted: (_) =>
                                                      onFieldSubmitted(),
                                                );
                                              },
                                          optionsViewBuilder:
                                              (context, onSelected, options) {
                                                final optionList = options
                                                    .toList();
                                                return Align(
                                                  alignment: Alignment.topLeft,
                                                  child: Material(
                                                    elevation: 4,
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxWidth: 320,
                                                            maxHeight: 280,
                                                          ),
                                                      child: ListView.builder(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shrinkWrap: true,
                                                        itemCount:
                                                            optionList.length,
                                                        itemBuilder:
                                                            (
                                                              context,
                                                              optionIndex,
                                                            ) {
                                                              final option =
                                                                  optionList[optionIndex];
                                                              return ListTile(
                                                                dense: true,
                                                                title: Text(
                                                                  _rawMaterialOptionLabel(
                                                                    option,
                                                                  ),
                                                                ),
                                                                onTap: () =>
                                                                    onSelected(
                                                                      option,
                                                                    ),
                                                              );
                                                            },
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                        )
                                      else if (detailType ==
                                          semiProductDetailTypeSemiProduct)
                                        DropdownMenu<String>(
                                          key: ValueKey('semi-${detail['id']}'),
                                          width: 260,
                                          initialSelection:
                                              selectedReferenceCode.isEmpty
                                              ? null
                                              : selectedReferenceCode,
                                          enableFilter: true,
                                          enableSearch: true,
                                          requestFocusOnTap: true,
                                          label: const Text('选择半成品'),
                                          hintText: '从半成品列表中选择',
                                          onSelected: (value) {
                                            setDialogState(() {
                                              detail['referenceCode'] =
                                                  value ?? '';
                                              final selected =
                                                  availableSemiProducts
                                                      .firstWhere(
                                                        (product) =>
                                                            product['code'] ==
                                                            value,
                                                        orElse: () =>
                                                            <String, dynamic>{},
                                                      );
                                              detail['referenceLabel'] =
                                                  selected.isEmpty
                                                  ? ''
                                                  : _semiProductOptionLabel(
                                                      selected,
                                                    );
                                            });
                                          },
                                          dropdownMenuEntries:
                                              availableSemiProducts.map((
                                                product,
                                              ) {
                                                final code =
                                                    product['code'] as String;
                                                return DropdownMenuEntry<
                                                  String
                                                >(
                                                  value: code,
                                                  label:
                                                      _semiProductOptionLabel(
                                                        product,
                                                      ),
                                                );
                                              }).toList(),
                                        )
                                      else if (detailType ==
                                          semiProductDetailTypeTool)
                                        DropdownMenu<String>(
                                          key: ValueKey('tool-${detail['id']}'),
                                          width: 260,
                                          initialSelection:
                                              selectedReferenceCode.isEmpty
                                              ? null
                                              : selectedReferenceCode,
                                          enableFilter: true,
                                          enableSearch: true,
                                          requestFocusOnTap: true,
                                          label: const Text('选择工具设备'),
                                          hintText: '选择系统管理中的工具',
                                          onSelected: (value) {
                                            setDialogState(() {
                                              detail['referenceCode'] =
                                                  value ?? '';
                                              final selected = _tools
                                                  .firstWhere(
                                                    (tool) =>
                                                        tool['code'] == value,
                                                    orElse: () =>
                                                        <String, dynamic>{},
                                                  );
                                              detail['referenceLabel'] =
                                                  selected.isEmpty
                                                  ? ''
                                                  : _toolOptionLabel(selected);
                                            });
                                          },
                                          dropdownMenuEntries: _tools.map((
                                            tool,
                                          ) {
                                            final code = tool['code'] as String;
                                            return DropdownMenuEntry<String>(
                                              value: code,
                                              label: _toolOptionLabel(tool),
                                            );
                                          }).toList(),
                                        )
                                      else if (detailType ==
                                          semiProductDetailTypeProduct)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                FilledButton.icon(
                                                  onPressed: () async {
                                                    final picked =
                                                        await _pickAndCropFinishedImage();
                                                    if (picked == null) {
                                                      return;
                                                    }
                                                    setDialogState(() {
                                                      detail['imageBytes'] =
                                                          picked.bytes;
                                                      detail['imageFileName'] =
                                                          picked.fileName;
                                                      detail['imagePath'] = '';
                                                      detail['imageUrl'] = '';
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons
                                                        .photo_library_outlined,
                                                  ),
                                                  label: const Text('选择成品图片'),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  onPressed:
                                                      (selectedImageBytes ==
                                                                  null ||
                                                              selectedImageBytes
                                                                  .isEmpty) &&
                                                          selectedImagePath
                                                              .isEmpty &&
                                                          selectedImageUrl
                                                              .isEmpty
                                                      ? null
                                                      : () {
                                                          setDialogState(() {
                                                            detail['imageBytes'] =
                                                                null;
                                                            detail['imageFileName'] =
                                                                '';
                                                            detail['imagePath'] =
                                                                '';
                                                            detail['imageUrl'] =
                                                                '';
                                                          });
                                                        },
                                                  child: const Text('移除图片'),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '图片会裁剪并保存为 600 x 600。',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: 8),
                                            _buildSquareImagePreview(
                                              imageBytes: selectedImageBytes,
                                              imageUrl: selectedImageUrl,
                                              dimension: 140,
                                            ),
                                          ],
                                        )
                                      else
                                        const SizedBox.shrink(),
                                      if (detailType ==
                                          semiProductDetailTypeRawMaterial) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                key: ValueKey(
                                                  'quantity-${detail['id']}',
                                                ),
                                                initialValue:
                                                    selectedQuantityValue,
                                                onChanged: (value) {
                                                  detail['quantityValue'] =
                                                      value;
                                                },
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: '重量 / 含量',
                                                      hintText: '例如 250',
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 170,
                                              child: Autocomplete<Map<String, dynamic>>(
                                                key: ValueKey(
                                                  'unit-${detail['id']}',
                                                ),
                                                initialValue: TextEditingValue(
                                                  text:
                                                      selectedUnitLabel
                                                          .isNotEmpty
                                                      ? selectedUnitLabel
                                                      : selectedUnitCode,
                                                ),
                                                displayStringForOption:
                                                    _unitOptionLabel,
                                                optionsBuilder:
                                                    (
                                                      TextEditingValue
                                                      textEditingValue,
                                                    ) {
                                                      final keyword =
                                                          textEditingValue.text;
                                                      return _units.where((
                                                        unit,
                                                      ) {
                                                        final searchText = [
                                                          unit['code']
                                                                  as String? ??
                                                              '',
                                                          unit['nameCN']
                                                                  as String? ??
                                                              '',
                                                          unit['nameEN']
                                                                  as String? ??
                                                              '',
                                                          _unitOptionLabel(
                                                            unit,
                                                          ),
                                                        ].join(' ');
                                                        return _matchesSearchText(
                                                          searchText,
                                                          keyword,
                                                        );
                                                      });
                                                    },
                                                onSelected: (selection) {
                                                  setDialogState(() {
                                                    detail['unitCode'] =
                                                        selection['code']
                                                            as String? ??
                                                        '';
                                                    detail['unitLabel'] =
                                                        _unitOptionLabel(
                                                          selection,
                                                        );
                                                  });
                                                },
                                                fieldViewBuilder:
                                                    (
                                                      context,
                                                      textEditingController,
                                                      focusNode,
                                                      onFieldSubmitted,
                                                    ) {
                                                      return TextFormField(
                                                        controller:
                                                            textEditingController,
                                                        focusNode: focusNode,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText: '单位',
                                                              hintText:
                                                                  '输入单位搜索',
                                                              prefixIcon: Icon(
                                                                Icons.search,
                                                              ),
                                                            ),
                                                        onChanged: (value) {
                                                          final trimmed = value
                                                              .trim();
                                                          if (trimmed.isEmpty) {
                                                            detail['unitCode'] =
                                                                '';
                                                            detail['unitLabel'] =
                                                                '';
                                                            return;
                                                          }

                                                          if (trimmed !=
                                                              selectedUnitLabel) {
                                                            detail['unitCode'] =
                                                                '';
                                                            detail['unitLabel'] =
                                                                trimmed;
                                                          }
                                                        },
                                                        onFieldSubmitted: (_) =>
                                                            onFieldSubmitted(),
                                                      );
                                                    },
                                                optionsViewBuilder: (context, onSelected, options) {
                                                  final optionList = options
                                                      .toList();
                                                  return Align(
                                                    alignment:
                                                        Alignment.topLeft,
                                                    child: Material(
                                                      elevation: 4,
                                                      child: ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxWidth: 260,
                                                              maxHeight: 280,
                                                            ),
                                                        child: ListView.builder(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          shrinkWrap: true,
                                                          itemCount:
                                                              optionList.length,
                                                          itemBuilder:
                                                              (
                                                                context,
                                                                optionIndex,
                                                              ) {
                                                                final option =
                                                                    optionList[optionIndex];
                                                                return ListTile(
                                                                  dense: true,
                                                                  title: Text(
                                                                    _unitOptionLabel(
                                                                      option,
                                                                    ),
                                                                  ),
                                                                  onTap: () =>
                                                                      onSelected(
                                                                        option,
                                                                      ),
                                                                );
                                                              },
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Autocomplete<Map<String, dynamic>>(
                                          key: ValueKey(
                                            'kitchen-${detail['id']}',
                                          ),
                                          initialValue: TextEditingValue(
                                            text:
                                                selectedKitchenToolLabel
                                                    .isNotEmpty
                                                ? selectedKitchenToolLabel
                                                : selectedKitchenToolCode,
                                          ),
                                          displayStringForOption:
                                              _toolOptionLabel,
                                          optionsBuilder:
                                              (
                                                TextEditingValue
                                                textEditingValue,
                                              ) {
                                                final keyword =
                                                    textEditingValue.text;
                                                return _kitchenTools.where((
                                                  tool,
                                                ) {
                                                  final searchText = [
                                                    tool['code'] as String? ??
                                                        '',
                                                    tool['nameCN'] as String? ??
                                                        '',
                                                    tool['nameEN'] as String? ??
                                                        '',
                                                    _toolOptionLabel(tool),
                                                  ].join(' ');
                                                  return _matchesSearchText(
                                                    searchText,
                                                    keyword,
                                                  );
                                                });
                                              },
                                          onSelected: (selection) {
                                            setDialogState(() {
                                              detail['kitchenToolCode'] =
                                                  selection['code']
                                                      as String? ??
                                                  '';
                                              detail['kitchenToolLabel'] =
                                                  _toolOptionLabel(selection);
                                            });
                                          },
                                          fieldViewBuilder:
                                              (
                                                context,
                                                textEditingController,
                                                focusNode,
                                                onFieldSubmitted,
                                              ) {
                                                return TextFormField(
                                                  controller:
                                                      textEditingController,
                                                  focusNode: focusNode,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: '选择使用厨具',
                                                        hintText:
                                                            '输入厨具名称 / 编号搜索',
                                                        prefixIcon: Icon(
                                                          Icons.search,
                                                        ),
                                                      ),
                                                  onChanged: (value) {
                                                    final trimmed = value
                                                        .trim();
                                                    if (trimmed.isEmpty) {
                                                      detail['kitchenToolCode'] =
                                                          '';
                                                      detail['kitchenToolLabel'] =
                                                          '';
                                                      return;
                                                    }

                                                    if (trimmed !=
                                                        selectedKitchenToolLabel) {
                                                      detail['kitchenToolCode'] =
                                                          '';
                                                      detail['kitchenToolLabel'] =
                                                          trimmed;
                                                    }
                                                  },
                                                  onFieldSubmitted: (_) =>
                                                      onFieldSubmitted(),
                                                );
                                              },
                                          optionsViewBuilder:
                                              (context, onSelected, options) {
                                                final optionList = options
                                                    .toList();
                                                return Align(
                                                  alignment: Alignment.topLeft,
                                                  child: Material(
                                                    elevation: 4,
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxWidth: 320,
                                                            maxHeight: 280,
                                                          ),
                                                      child: ListView.builder(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shrinkWrap: true,
                                                        itemCount:
                                                            optionList.length,
                                                        itemBuilder:
                                                            (
                                                              context,
                                                              optionIndex,
                                                            ) {
                                                              final option =
                                                                  optionList[optionIndex];
                                                              return ListTile(
                                                                dense: true,
                                                                title: Text(
                                                                  _toolOptionLabel(
                                                                    option,
                                                                  ),
                                                                ),
                                                                onTap: () =>
                                                                    onSelected(
                                                                      option,
                                                                    ),
                                                              );
                                                            },
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ],
                                      if (detailType ==
                                          semiProductDetailTypeSemiProduct) ...[
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: _buildSquareImagePreview(
                                            imageUrl:
                                                selectedSemiProduct == null
                                                ? null
                                                : selectedSemiProduct['imageUrl']
                                                      as String?,
                                            dimension: 140,
                                          ),
                                        ),
                                      ],
                                      if (detailType !=
                                          semiProductDetailTypeStep)
                                        const SizedBox(height: 8),
                                      TextFormField(
                                        key: ValueKey('detail-${detail['id']}'),
                                        initialValue:
                                            detail['description'] as String? ??
                                            '',
                                        onChanged: (value) {
                                          detail['description'] = value;
                                        },
                                        decoration: InputDecoration(
                                          labelText:
                                              detailType ==
                                                  semiProductDetailTypeStep
                                              ? '文字描述'
                                              : detailType ==
                                                    semiProductDetailTypeProduct
                                              ? '成品说明'
                                              : '补充描述',
                                          helperText:
                                              detailType ==
                                                  semiProductDetailTypeStep
                                              ? null
                                              : detailType ==
                                                    semiProductDetailTypeProduct
                                              ? '成品只能有一条，并且固定在最后'
                                              : [
                                                  if (selectedReferenceLabel
                                                      .isNotEmpty)
                                                    selectedReferenceLabel,
                                                  if (detailType ==
                                                          semiProductDetailTypeRawMaterial &&
                                                      selectedQuantityValue
                                                          .trim()
                                                          .isNotEmpty)
                                                    '用量: $selectedQuantityValue ${selectedUnitLabel.isNotEmpty ? selectedUnitLabel : selectedUnitCode}',
                                                  if (detailType ==
                                                          semiProductDetailTypeRawMaterial &&
                                                      selectedKitchenToolLabel
                                                          .isNotEmpty)
                                                    '厨具: $selectedKitchenToolLabel',
                                                ].isEmpty
                                              ? null
                                              : [
                                                  if (selectedReferenceLabel
                                                      .isNotEmpty)
                                                    selectedReferenceLabel,
                                                  if (detailType ==
                                                          semiProductDetailTypeRawMaterial &&
                                                      selectedQuantityValue
                                                          .trim()
                                                          .isNotEmpty)
                                                    '用量: $selectedQuantityValue ${selectedUnitLabel.isNotEmpty ? selectedUnitLabel : selectedUnitCode}',
                                                  if (detailType ==
                                                          semiProductDetailTypeRawMaterial &&
                                                      selectedKitchenToolLabel
                                                          .isNotEmpty)
                                                    '厨具: $selectedKitchenToolLabel',
                                                ].join('\n'),
                                        ),
                                        minLines: 1,
                                        maxLines: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      onPressed: detailEntries.length == 1
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                detailEntries.removeAt(index);
                                                _moveProductDetailToEnd(
                                                  detailEntries,
                                                );
                                              });
                                            },
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.drag_handle,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final nameCN = nameCNController.text.trim();
                  if (nameCN.isEmpty) {
                    return;
                  }
                  final productCount = detailEntries
                      .where(
                        (detail) =>
                            detail['type'] == semiProductDetailTypeProduct,
                      )
                      .length;
                  if (productCount > 1) {
                    _showMessage('每个半成品只能有一条成品');
                    return;
                  }

                  _moveProductDetailToEnd(detailEntries);
                  final normalizedDetails = <Map<String, dynamic>>[];
                  String? finalProductImagePath;
                  for (final detail in detailEntries) {
                    final type =
                        detail['type'] as String? ?? semiProductDetailTypeStep;
                    final description = (detail['description'] as String? ?? '')
                        .trim();
                    final referenceCode =
                        (detail['referenceCode'] as String? ?? '').trim();
                    final referenceLabel =
                        (detail['referenceLabel'] as String? ?? '').trim();
                    final quantityValue =
                        (detail['quantityValue'] as String? ?? '').trim();
                    final unitCode = (detail['unitCode'] as String? ?? '')
                        .trim();
                    final unitLabel = (detail['unitLabel'] as String? ?? '')
                        .trim();
                    final kitchenToolCode =
                        (detail['kitchenToolCode'] as String? ?? '').trim();
                    final kitchenToolLabel =
                        (detail['kitchenToolLabel'] as String? ?? '').trim();
                    var imagePath = (detail['imagePath'] as String? ?? '')
                        .trim();
                    final imageUrl = (detail['imageUrl'] as String? ?? '')
                        .trim();
                    final imageBytes = detail['imageBytes'] as Uint8List?;
                    final imageFileName =
                        (detail['imageFileName'] as String? ?? '').trim();

                    if (type == semiProductDetailTypeStep) {
                      if (description.isEmpty) {
                        continue;
                      }
                      normalizedDetails.add({
                        'type': type,
                        'referenceCode': '',
                        'referenceLabel': '',
                        'quantityValue': '',
                        'unitCode': '',
                        'unitLabel': '',
                        'kitchenToolCode': '',
                        'kitchenToolLabel': '',
                        'imagePath': '',
                        'imageUrl': '',
                        'description': description,
                      });
                      continue;
                    }

                    if (type == semiProductDetailTypeProduct) {
                      if (imageBytes != null && imageBytes.isNotEmpty) {
                        final uploadedImagePath = await _systemService
                            .uploadImage(
                              imageBytes,
                              imageFileName.isEmpty ? null : imageFileName,
                            );
                        if (uploadedImagePath == null ||
                            uploadedImagePath.trim().isEmpty) {
                          _showMessage('成品图片上传失败');
                          return;
                        }
                        imagePath = uploadedImagePath.trim();
                      }

                      if (imagePath.isEmpty && imageUrl.isEmpty) {
                        _showMessage('成品请上传 600 x 600 图片');
                        return;
                      }

                      finalProductImagePath = imagePath.isEmpty
                          ? null
                          : imagePath;
                      normalizedDetails.add({
                        'type': type,
                        'referenceCode': '',
                        'referenceLabel': '成品图片',
                        'kitchenToolCode': '',
                        'kitchenToolLabel': '',
                        'imagePath': imagePath,
                        'imageUrl': imageUrl,
                        'description': description,
                      });
                      continue;
                    }

                    if (referenceCode.isEmpty) {
                      if (description.isEmpty) {
                        continue;
                      }
                      _showMessage(
                        type == semiProductDetailTypeRawMaterial
                            ? '请选择详情里的原材料'
                            : type == semiProductDetailTypeSemiProduct
                            ? '请选择详情里的半成品'
                            : '请选择详情里的工具设备',
                      );
                      return;
                    }

                    if (type == semiProductDetailTypeSemiProduct &&
                        referenceCode == currentSemiProductCode) {
                      _showMessage('半成品详情不能选择自己');
                      return;
                    }

                    if (type == semiProductDetailTypeRawMaterial &&
                        quantityValue.isEmpty) {
                      _showMessage('原材料详情请输入重量或含量');
                      return;
                    }

                    if (type == semiProductDetailTypeRawMaterial &&
                        unitCode.isEmpty) {
                      _showMessage('原材料详情请选择单位');
                      return;
                    }

                    if (type == semiProductDetailTypeRawMaterial &&
                        kitchenToolCode.isEmpty) {
                      _showMessage('原材料详情请选择使用厨具');
                      return;
                    }

                    normalizedDetails.add({
                      'type': type,
                      'referenceCode': referenceCode,
                      'referenceLabel': referenceLabel,
                      'quantityValue': type == semiProductDetailTypeRawMaterial
                          ? quantityValue
                          : '',
                      'unitCode': type == semiProductDetailTypeRawMaterial
                          ? unitCode
                          : '',
                      'unitLabel': type == semiProductDetailTypeRawMaterial
                          ? unitLabel
                          : '',
                      'kitchenToolCode':
                          type == semiProductDetailTypeRawMaterial
                          ? kitchenToolCode
                          : '',
                      'kitchenToolLabel':
                          type == semiProductDetailTypeRawMaterial
                          ? kitchenToolLabel
                          : '',
                      'imagePath': '',
                      'imageUrl': '',
                      'description': description,
                    });
                  }

                  final orderedDetails = [
                    ...normalizedDetails.where(
                      (detail) =>
                          detail['type'] != semiProductDetailTypeProduct,
                    ),
                    ...normalizedDetails.where(
                      (detail) =>
                          detail['type'] == semiProductDetailTypeProduct,
                    ),
                  ];

                  final mergedRawMaterialCodes = {
                    ...selectedRawMaterials,
                    ...orderedDetails
                        .where(
                          (detail) =>
                              detail['type'] ==
                              semiProductDetailTypeRawMaterial,
                        )
                        .map((detail) => detail['referenceCode'] as String)
                        .where((code) => code.isNotEmpty),
                  }.toList();

                  final mergedToolCodes = {
                    ...selectedToolCodes,
                    ...orderedDetails
                        .where(
                          (detail) =>
                              detail['type'] == semiProductDetailTypeTool,
                        )
                        .map((detail) => detail['referenceCode'] as String)
                        .where((code) => code.isNotEmpty),
                  }.toList();

                  final encodedDetails = encodeSemiProductDetails(
                    orderedDetails,
                  );
                  try {
                    final success = isEdit
                        ? await _systemService.updateSemiProduct(
                            item['code'] as String,
                            nameCN,
                            nameENController.text.trim(),
                            categoryCode: selectedCategoryCode,
                            description: descriptionController.text.trim(),
                            imagePath: finalProductImagePath,
                            rawMaterialCodes: mergedRawMaterialCodes,
                            toolCodes: mergedToolCodes,
                            steps: encodedDetails,
                          )
                        : await _systemService.addSemiProduct(
                            currentSemiProductCode,
                            nameCN,
                            nameENController.text.trim(),
                            categoryCode: selectedCategoryCode,
                            description: descriptionController.text.trim(),
                            imagePath: finalProductImagePath,
                            rawMaterialCodes: mergedRawMaterialCodes,
                            toolCodes: mergedToolCodes,
                            steps: encodedDetails,
                          );
                    if (success) {
                      await _loadAllData();
                      if (mounted) {
                        navigator.pop();
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      _showMessage(
                        '${isEdit ? 'Update' : 'Create'} failed: $e',
                      );
                    }
                  }
                },
                child: Text(isEdit ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSemiProducts = _filteredSemiProducts;
    final filterOptions = _semiProductFilterOptions;

    return Scaffold(
      appBar: AppBar(title: const Text('半成品管理')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadAllData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _showSemiProductDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Semi Product'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _showSemiProductCategoriesManager,
                          icon: const Icon(Icons.category_outlined),
                          label: const Text('Manage Categories'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filterOptions.map((option) {
                        final code = option['code'] as String?;
                        final isSelected =
                            _selectedSemiProductCategoryCode == code;
                        final label = option['label'] as String? ?? '-';
                        final count = option['count'] as int? ?? 0;
                        return ChoiceChip(
                          label: Text('$label ($count)'),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedSemiProductCategoryCode = code;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredSemiProducts.isEmpty
                        ? const Center(child: Text('No data'))
                        : ListView.builder(
                            itemCount: filteredSemiProducts.length,
                            itemBuilder: (context, index) {
                              final item = filteredSemiProducts[index];
                              final orderedName = _orderedName(
                                item['nameCN'] as String?,
                                item['nameEN'] as String?,
                              );
                              final orderedCategory = _orderedName(
                                item['categoryNameCN'] as String?,
                                item['categoryNameEN'] as String?,
                              );
                              final subtitleLines = <String>[];
                              if (orderedName.isNotEmpty) {
                                subtitleLines.add(orderedName);
                              }
                              if (orderedCategory.isNotEmpty) {
                                subtitleLines.add('分类: $orderedCategory');
                              }
                              return Card(
                                child: ListTile(
                                  onTap: () => _showSemiProductPreview(item),
                                  title: Text(
                                    '${item['code']} - ${orderedName.isEmpty ? '-' : orderedName}',
                                  ),
                                  subtitle: Text(
                                    subtitleLines.isEmpty
                                        ? '-'
                                        : subtitleLines.join('\n'),
                                  ),
                                  isThreeLine: subtitleLines.length > 1,
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _showSemiProductDialog(item: item),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        onPressed: () => _confirmDelete(
                                          title: item['code'] as String,
                                          onDelete: () =>
                                              _systemService.deleteSemiProduct(
                                                item['code'] as String,
                                              ),
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
