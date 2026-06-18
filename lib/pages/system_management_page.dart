import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/session_service.dart';
import '../services/system_service.dart';

class SystemManagementPage extends StatefulWidget {
  final int initialTabIndex;

  const SystemManagementPage({super.key, this.initialTabIndex = 0});

  @override
  State<SystemManagementPage> createState() => _SystemManagementPageState();
}

class _SystemManagementPageState extends State<SystemManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SystemService _systemService = SystemService();

  final List<Map<String, dynamic>> _rawMaterials = [];
  final List<Map<String, dynamic>> _rawMaterialCategories = [];
  final List<Map<String, dynamic>> _rawMaterialLocations = [];
  final List<Map<String, dynamic>> _suppliers = [];
  final List<Map<String, dynamic>> _units = [];
  final List<Map<String, dynamic>> _regions = [];
  final List<Map<String, dynamic>> _stores = [];
  final List<Map<String, dynamic>> _semiProducts = [];
  final List<Map<String, dynamic>> _kitchenTools = [];
  final List<Map<String, dynamic>> _processes = [];
  final List<Map<String, dynamic>> _tools = [];

  bool _isLoading = true;
  String? _error;
  String? _selectedRawMaterialCategoryCode;
  String? _selectedRawMaterialListCode;

  bool get _isEnglish => SessionService().isEnglish;

  String _orderedName(String? nameCN, String? nameEN) {
    final cn = (nameCN ?? '').trim();
    final en = (nameEN ?? '').trim();
    if (cn.isEmpty || cn == '-') {
      return en.isEmpty ? '-' : en;
    }
    if (en.isEmpty || en == '-') {
      return cn;
    }
    return _isEnglish ? '$en / $cn' : '$cn / $en';
  }

  String _orderedNameWithCode(String? nameCN, String? nameEN, String code) {
    final ordered = _orderedName(nameCN, nameEN);
    if (ordered == '-') {
      return code;
    }
    return '$ordered ($code)';
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

  String _orDash(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? '-' : text;
  }

  String _displayImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http://127.0.0.1')) {
      return imageUrl.replaceFirst('http://127.0.0.1', 'http://localhost');
    }
    return imageUrl;
  }

  bool _matchesSearchText(String source, String keyword) {
    final normalizedSource = source.trim().toLowerCase();
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return true;
    }
    return normalizedSource.contains(normalizedKeyword);
  }

  String _rawMaterialOptionLabel(Map<String, dynamic> material) {
    final code = material['code'] as String? ?? '';
    final nameCN = material['nameCN'] as String? ?? '';
    final nameEN = material['nameEN'] as String? ?? '';
    return _orderedNameWithCode(nameCN, nameEN, code);
  }

  List<Map<String, dynamic>> get _filteredRawMaterials {
    if (_selectedRawMaterialCategoryCode == null) {
      return _rawMaterials;
    }
    if (_selectedRawMaterialCategoryCode == '__UNCATEGORIZED__') {
      return _rawMaterials.where((item) {
        final categoryCode = (item['categoryCode'] as String?)?.trim();
        return categoryCode == null || categoryCode.isEmpty;
      }).toList();
    }
    return _rawMaterials.where((item) {
      final categoryCode = (item['categoryCode'] as String?)?.trim();
      return categoryCode == _selectedRawMaterialCategoryCode;
    }).toList();
  }

  List<Map<String, dynamic>> get _rawMaterialFilterOptions {
    final options = <Map<String, dynamic>>[
      {'code': null, 'label': '全部', 'count': _rawMaterials.length},
    ];

    for (final category in _rawMaterialCategories) {
      final code = (category['code'] as String?)?.trim();
      if (code == null || code.isEmpty) {
        continue;
      }
      final count = _rawMaterials.where((item) {
        final itemCode = (item['categoryCode'] as String?)?.trim();
        return itemCode == code;
      }).length;
      options.add({
        'code': code,
        'label': _orDash(category['name'] as String?),
        'count': count,
      });
    }

    final uncategorizedCount = _rawMaterials.where((item) {
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
    final initialIndex = widget.initialTabIndex.clamp(0, 7);
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: initialIndex,
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final materials = await _systemService.getRawMaterials();
      final categories = await _systemService.getRawMaterialCategories();
      final locations = await _systemService.getRawMaterialLocations();
      final suppliers = await _systemService.getSuppliers();
      final units = await _systemService.getUnits();
      final regions = await _systemService.getRegions();
      final stores = await _systemService.getStores();
      final products = await _systemService.getSemiProducts();
      final kitchenTools = await _systemService.getKitchenTools();
      final processes = await _systemService.getProcesses();
      final tools = await _systemService.getTools();

      if (!mounted) {
        return;
      }

      setState(() {
        _rawMaterials
          ..clear()
          ..addAll(materials);
        _rawMaterialCategories
          ..clear()
          ..addAll(categories);
        _rawMaterialLocations
          ..clear()
          ..addAll(locations);
        _suppliers
          ..clear()
          ..addAll(suppliers);
        _units
          ..clear()
          ..addAll(units);
        _regions
          ..clear()
          ..addAll(regions);
        _stores
          ..clear()
          ..addAll(stores);
        _semiProducts
          ..clear()
          ..addAll(products);
        _kitchenTools
          ..clear()
          ..addAll(kitchenTools);
        _processes
          ..clear()
          ..addAll(processes);
        _tools
          ..clear()
          ..addAll(tools);
        final hasSelectedCategory =
            _selectedRawMaterialCategoryCode == null ||
            _rawMaterialFilterOptions.any(
              (option) => option['code'] == _selectedRawMaterialCategoryCode,
            );
        if (!hasSelectedCategory) {
          _selectedRawMaterialCategoryCode = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<({Uint8List bytes, String fileName})?> _pickAndEditImage() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) {
      return null;
    }

    final bytes = await imageFile.readAsBytes();
    final controller = CropController();
    var isCropping = false;

    return showDialog<({Uint8List bytes, String fileName})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Photo'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 320,
                    height: 320,
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
                    'Drag and zoom the image, then save the 600 x 600 result.',
                    textAlign: TextAlign.center,
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
                onPressed: isCropping
                    ? null
                    : () {
                        setDialogState(() {
                          isCropping = true;
                        });
                        controller.crop();
                      },
                child: Text(isCropping ? 'Cropping...' : 'Use Photo'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRawMaterialCategoryDialog({
    Map<String, dynamic>? item,
  }) async {
    final isEdit = item != null;
    final nameController = TextEditingController(
      text: item?['name'] as String? ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
        content: SizedBox(
          width: 320,
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
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              try {
                final success = isEdit
                    ? await _systemService.updateRawMaterialCategory(
                        item['code'] as String,
                        name,
                      )
                    : await _systemService.addRawMaterialCategory(
                        _generateCode('CAT', _rawMaterialCategories),
                        name,
                      );
                if (success) {
                  await _loadAllData();
                  if (mounted) {
                    Navigator.of(context).pop();
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

  Future<void> _showRawMaterialCategoriesManager() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raw Material Categories'),
        content: SizedBox(
          width: 420,
          child: _rawMaterialCategories.isEmpty
              ? const Center(child: Text('No categories'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rawMaterialCategories.length,
                  itemBuilder: (context, index) {
                    final item = _rawMaterialCategories[index];
                    return ListTile(
                      title: Text(item['name'] as String? ?? '-'),
                      subtitle: Text(item['code'] as String? ?? '-'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _showRawMaterialCategoryDialog(item: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(
                              title: item['name'] as String? ?? '-',
                              onDelete: () =>
                                  _systemService.deleteRawMaterialCategory(
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
          FilledButton(
            onPressed: _showRawMaterialCategoryDialog,
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRawMaterialLocationDialog({
    Map<String, dynamic>? item,
  }) async {
    final isEdit = item != null;
    final nameController = TextEditingController(
      text: item?['name'] as String? ?? '',
    );
    final noteController = TextEditingController(
      text: item?['note'] as String? ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Location' : 'Add Location'),
        content: SizedBox(
          width: 360,
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
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Location Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 2,
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
              final name = nameController.text.trim();
              final note = noteController.text.trim();
              if (name.isEmpty) {
                return;
              }
              try {
                final success = isEdit
                    ? await _systemService.updateRawMaterialLocation(
                        item['code'] as String,
                        name,
                        note,
                      )
                    : await _systemService.addRawMaterialLocation(
                        _generateCode('LOC', _rawMaterialLocations),
                        name,
                        note,
                      );
                if (success) {
                  await _loadAllData();
                  if (mounted) {
                    Navigator.of(context).pop();
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

  Future<void> _showRawMaterialLocationsManager() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raw Material Locations'),
        content: SizedBox(
          width: 420,
          child: _rawMaterialLocations.isEmpty
              ? const Center(child: Text('No locations'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rawMaterialLocations.length,
                  itemBuilder: (context, index) {
                    final item = _rawMaterialLocations[index];
                    return ListTile(
                      title: Text(item['name'] as String? ?? '-'),
                      subtitle: Text(
                        '${item['code'] ?? '-'}\n${_orDash(item['note'] as String?)}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _showRawMaterialLocationDialog(item: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(
                              title: item['name'] as String? ?? '-',
                              onDelete: () =>
                                  _systemService.deleteRawMaterialLocation(
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
          FilledButton(
            onPressed: _showRawMaterialLocationDialog,
            child: const Text('Add Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRawMaterialDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );
    final specificationController = TextEditingController(
      text: item?['specification'] as String? ?? '',
    );
    final minQuantityController = TextEditingController(
      text: item?['minQuantity']?.toString() ?? '0',
    );
    String? categoryCode = item?['categoryCode'] as String?;
    String? locationCode = item?['locationCode'] as String?;
    String? primarySupplierCode = item?['primarySupplierCode'] as String?;
    String? secondarySupplierCode = item?['secondarySupplierCode'] as String?;
    Uint8List? imageBytes = item?['imageBytes'] as Uint8List?;
    String? imageUrl = item?['imageUrl'] as String?;
    String? imageFileName = item?['imagePath'] as String?;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '编辑原材料' : '添加原材料'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
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
                    decoration: const InputDecoration(
                      labelText: 'Chinese Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameENController,
                    decoration: const InputDecoration(
                      labelText: 'English Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: specificationController,
                    decoration: const InputDecoration(labelText: '规格'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoryCode,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('无分类'),
                      ),
                      ..._rawMaterialCategories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category['code'] as String,
                          child: Text(category['name'] as String? ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        categoryCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: locationCode,
                    decoration: const InputDecoration(labelText: '位置'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('未设置位置'),
                      ),
                      ..._rawMaterialLocations.map(
                        (location) => DropdownMenuItem<String>(
                          value: location['code'] as String,
                          child: Text(location['name'] as String? ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        locationCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: primarySupplierCode,
                    decoration: const InputDecoration(labelText: '主要供应商'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('无主要供应商'),
                      ),
                      ..._suppliers.map(
                        (supplier) => DropdownMenuItem<String>(
                          value: supplier['code'] as String,
                          child: Text(supplier['name'] as String? ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        primarySupplierCode = value;
                        if (secondarySupplierCode == value) {
                          secondarySupplierCode = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: secondarySupplierCode,
                    decoration: const InputDecoration(labelText: '次要供应商'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('无次要供应商'),
                      ),
                      ..._suppliers
                          .where(
                            (supplier) =>
                                supplier['code'] != primarySupplierCode,
                          )
                          .map(
                            (supplier) => DropdownMenuItem<String>(
                              value: supplier['code'] as String,
                              child: Text(supplier['name'] as String? ?? '-'),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        secondarySupplierCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minQuantityController,
                    decoration: const InputDecoration(labelText: '最小数量'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final picked = await _pickAndEditImage();
                            if (picked != null) {
                              setDialogState(() {
                                imageBytes = picked.bytes;
                                imageFileName = picked.fileName;
                                imageUrl = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      imageBytes != null || imageUrl != null ? '更换照片' : '上传照片',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        imageBytes!,
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (imageUrl?.isNotEmpty == true)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _displayImageUrl(imageUrl!),
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              width: 180,
                              height: 180,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0x11000000),
                                ),
                                child: Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 180,
                      height: 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x11000000)),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final nameCN = nameCNController.text.trim();
                      final minQuantity =
                          double.tryParse(minQuantityController.text.trim()) ??
                          0;
                      if (nameCN.isEmpty) {
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                      });
                      try {
                        final success = isEdit
                            ? await _systemService.updateRawMaterial(
                                item['code'] as String,
                                nameCN,
                                nameENController.text.trim(),
                                specificationController.text.trim(),
                                categoryCode,
                                locationCode,
                                primarySupplierCode,
                                secondarySupplierCode,
                                minQuantity,
                                imageBytes,
                                imageFileName,
                              )
                            : await _systemService.addRawMaterial(
                                nameCN,
                                nameENController.text.trim(),
                                specificationController.text.trim(),
                                categoryCode,
                                locationCode,
                                primarySupplierCode,
                                secondarySupplierCode,
                                minQuantity,
                                imageBytes,
                                imageFileName,
                              );
                        if (success) {
                          await _loadAllData();
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                        });
                        if (mounted) {
                          _showMessage('${isEdit ? '更新' : '创建'}失败: $e');
                        }
                      }
                    },
              child: Text(isEdit ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSupplierDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final nameController = TextEditingController(
      text: item?['name'] as String? ?? '',
    );
    final aliasController = TextEditingController(
      text: item?['alias'] as String? ?? '',
    );
    final addressController = TextEditingController(
      text: item?['address'] as String? ?? '',
    );
    final contactController = TextEditingController(
      text: item?['contact'] as String? ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑供应商' : '添加供应商'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
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
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aliasController,
                  decoration: const InputDecoration(labelText: '别名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: '地址'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: '联系方式'),
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              try {
                final success = isEdit
                    ? await _systemService.updateSupplier(
                        item['code'] as String,
                        name,
                        aliasController.text.trim(),
                        addressController.text.trim(),
                        contactController.text.trim(),
                      )
                    : await _systemService.addSupplier(
                        _generateCode('SUP', _suppliers),
                        name,
                        aliasController.text.trim(),
                        addressController.text.trim(),
                        contactController.text.trim(),
                      );
                if (success) {
                  await _loadAllData();
                  if (mounted) {
                    Navigator.of(context).pop();
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

  Future<void> _showUnitDialog({Map<String, dynamic>? item}) async {
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
        title: Text(isEdit ? '编辑单位' : '添加单位'),
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
                    ? await _systemService.updateUnit(
                        item['code'] as String,
                        nameCN,
                        nameEN,
                      )
                    : await _systemService.addUnit(
                        _generateCode('UNIT', _units),
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

  Future<void> _showRegionDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );
    final noteController = TextEditingController(
      text: item?['note'] as String? ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑区域' : '添加区域'),
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
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: '备注'),
                minLines: 2,
                maxLines: 4,
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
              final note = noteController.text.trim();
              if (nameCN.isEmpty) {
                return;
              }
              try {
                final success = isEdit
                    ? await _systemService.updateRegion(
                        item['code'] as String,
                        nameCN,
                        nameEN,
                        note,
                      )
                    : await _systemService.addRegion(
                        _generateCode('REG', _regions),
                        nameCN,
                        nameEN,
                        note,
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

  Future<void> _showSemiProductDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );
    final descriptionController = TextEditingController(
      text: item?['description'] as String? ?? '',
    );
    final selectedRawMaterials = <String>[];
    final selectedToolCodes = <String>[];
    final selectedSteps = <String>[];

    if (item != null) {
      selectedRawMaterials.addAll(
        List<String>.from(item['rawMaterialCodes'] as List<dynamic>? ?? []),
      );
      selectedToolCodes.addAll(
        List<String>.from(item['toolCodes'] as List<dynamic>? ?? []),
      );
      selectedSteps.addAll(
        List<String>.from(item['steps'] as List<dynamic>? ?? []),
      );
    }

    String? selectedRawMaterialCode = _rawMaterials
        .map((e) => e['code'] as String)
        .firstWhere(
          (code) => !selectedRawMaterials.contains(code),
          orElse: () => _rawMaterials.isNotEmpty
              ? _rawMaterials.first['code'] as String
              : '',
        );
    if (selectedRawMaterialCode == '') {
      selectedRawMaterialCode = null;
    }
    String rawMaterialSearchText = selectedRawMaterialCode == null
        ? ''
        : _rawMaterials
              .firstWhere(
                (material) => material['code'] == selectedRawMaterialCode,
                orElse: () => <String, dynamic>{},
              )
              .isEmpty
        ? ''
        : _orderedNameWithCode(
            _rawMaterials.firstWhere(
                  (material) => material['code'] == selectedRawMaterialCode,
                )['nameCN']
                as String?,
            _rawMaterials.firstWhere(
                  (material) => material['code'] == selectedRawMaterialCode,
                )['nameEN']
                as String?,
            selectedRawMaterialCode!,
          );

    String? selectedToolCode = _kitchenTools
        .map((e) => e['code'] as String)
        .firstWhere(
          (code) => !selectedToolCodes.contains(code),
          orElse: () => _kitchenTools.isNotEmpty
              ? _kitchenTools.first['code'] as String
              : '',
        );
    if (selectedToolCode == '') {
      selectedToolCode = null;
    }

    final stepController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String rawMaterialLabel(String code) {
            final material = _rawMaterials.firstWhere(
              (entry) => entry['code'] == code,
              orElse: () => {'nameCN': code, 'nameEN': ''},
            );
            return _orderedName(
              material['nameCN'] as String?,
              material['nameEN'] as String?,
            );
          }

          String rawMaterialOptionLabel(Map<String, dynamic> material) {
            final code = material['code'] as String? ?? '';
            final nameCN = material['nameCN'] as String? ?? '';
            final nameEN = material['nameEN'] as String? ?? '';
            return _orderedNameWithCode(nameCN, nameEN, code);
          }

          String toolLabel(String code) {
            final tool = _kitchenTools.firstWhere(
              (entry) => entry['code'] == code,
              orElse: () => {'nameCN': code, 'nameEN': ''},
            );
            return _orderedName(
              tool['nameCN'] as String?,
              tool['nameEN'] as String?,
            );
          }

          final availableRawMaterials = _rawMaterials
              .where(
                (material) => !selectedRawMaterials.contains(material['code']),
              )
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
                    const SizedBox(height: 16),
                    const Text(
                      '原材料',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<Map<String, dynamic>>(
                            key: ValueKey(
                              'system-raw-material-${selectedRawMaterialCode ?? 'none'}-${selectedRawMaterials.length}',
                            ),
                            initialValue: TextEditingValue(
                              text: rawMaterialSearchText,
                            ),
                            displayStringForOption: rawMaterialOptionLabel,
                            optionsBuilder: (textEditingValue) {
                              final keyword = textEditingValue.text;
                              return availableRawMaterials.where((material) {
                                final searchText = [
                                  material['code'] as String? ?? '',
                                  material['nameCN'] as String? ?? '',
                                  material['nameEN'] as String? ?? '',
                                  rawMaterialOptionLabel(material),
                                ].join(' ');
                                return _matchesSearchText(searchText, keyword);
                              });
                            },
                            onSelected: (selection) {
                              setDialogState(() {
                                selectedRawMaterialCode =
                                    selection['code'] as String?;
                                rawMaterialSearchText = rawMaterialOptionLabel(
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
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: '选择原材料',
                                      hintText: '输入中文 / 英文 / 编号搜索',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        rawMaterialSearchText = value;
                                        final exactMatch = availableRawMaterials
                                            .where(
                                              (material) =>
                                                  rawMaterialOptionLabel(
                                                    material,
                                                  ) ==
                                                  value,
                                            )
                                            .cast<Map<String, dynamic>?>()
                                            .firstWhere(
                                              (_) => true,
                                              orElse: () => null,
                                            );
                                        selectedRawMaterialCode =
                                            exactMatch == null
                                            ? null
                                            : exactMatch['code'] as String?;
                                      });
                                    },
                                    onFieldSubmitted: (_) => onFieldSubmitted(),
                                  );
                                },
                            optionsViewBuilder: (context, onSelected, options) {
                              final optionList = options.toList();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                      maxHeight: 280,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: optionList.length,
                                      itemBuilder: (context, optionIndex) {
                                        final option = optionList[optionIndex];
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            rawMaterialOptionLabel(option),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onTap: () => onSelected(option),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: selectedRawMaterialCode == null
                              ? null
                              : () {
                                  setDialogState(() {
                                    if (!selectedRawMaterials.contains(
                                      selectedRawMaterialCode,
                                    )) {
                                      selectedRawMaterials.add(
                                        selectedRawMaterialCode!,
                                      );
                                    }
                                    selectedRawMaterialCode = _rawMaterials
                                        .map((e) => e['code'] as String)
                                        .firstWhere(
                                          (code) => !selectedRawMaterials
                                              .contains(code),
                                          orElse: () => '',
                                        );
                                    if (selectedRawMaterialCode == '') {
                                      selectedRawMaterialCode = null;
                                    }
                                    rawMaterialSearchText =
                                        selectedRawMaterialCode == null
                                        ? ''
                                        : '${rawMaterialLabel(selectedRawMaterialCode!)} ($selectedRawMaterialCode)';
                                  });
                                },
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedRawMaterials.map((code) {
                        return Chip(
                          label: Text(rawMaterialLabel(code)),
                          onDeleted: () {
                            setDialogState(() {
                              selectedRawMaterials.remove(code);
                              if (selectedRawMaterialCode == null) {
                                selectedRawMaterialCode = _rawMaterials
                                    .map((e) => e['code'] as String)
                                    .firstWhere(
                                      (code) =>
                                          !selectedRawMaterials.contains(code),
                                      orElse: () => '',
                                    );
                                if (selectedRawMaterialCode == '') {
                                  selectedRawMaterialCode = null;
                                }
                                rawMaterialSearchText =
                                    selectedRawMaterialCode == null
                                    ? ''
                                    : '${rawMaterialLabel(selectedRawMaterialCode!)} ($selectedRawMaterialCode)';
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '工具',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedToolCode,
                            hint: const Text('选择工具'),
                            items: _kitchenTools
                                .where(
                                  (tool) =>
                                      !selectedToolCodes.contains(tool['code']),
                                )
                                .map((tool) {
                                  final code = tool['code'] as String;
                                  return DropdownMenuItem<String>(
                                    value: code,
                                    child: Text(
                                      _orderedNameWithCode(
                                        tool['nameCN'] as String?,
                                        tool['nameEN'] as String?,
                                        code,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedToolCode = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: selectedToolCode == null
                              ? null
                              : () {
                                  setDialogState(() {
                                    if (!selectedToolCodes.contains(
                                      selectedToolCode,
                                    )) {
                                      selectedToolCodes.add(selectedToolCode!);
                                    }
                                    selectedToolCode = _kitchenTools
                                        .map((e) => e['code'] as String)
                                        .firstWhere(
                                          (code) =>
                                              !selectedToolCodes.contains(code),
                                          orElse: () => '',
                                        );
                                    if (selectedToolCode == '') {
                                      selectedToolCode = null;
                                    }
                                  });
                                },
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedToolCodes.map((code) {
                        return Chip(
                          label: Text(toolLabel(code)),
                          onDeleted: () {
                            setDialogState(() {
                              selectedToolCodes.remove(code);
                              if (selectedToolCode == null) {
                                selectedToolCode = _kitchenTools
                                    .map((e) => e['code'] as String)
                                    .firstWhere(
                                      (code) =>
                                          !selectedToolCodes.contains(code),
                                      orElse: () => '',
                                    );
                                if (selectedToolCode == '') {
                                  selectedToolCode = null;
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '步骤',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stepController,
                            decoration: const InputDecoration(
                              labelText: '输入步骤说明',
                            ),
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final value = stepController.text.trim();
                            if (value.isEmpty) {
                              return;
                            }
                            setDialogState(() {
                              selectedSteps.add(value);
                              stepController.clear();
                            });
                          },
                          child: const Text('添加步骤'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: selectedSteps.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final stepText = entry.value;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${idx + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(stepText)),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_upward,
                                        size: 20,
                                      ),
                                      onPressed: idx == 0
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                final temp =
                                                    selectedSteps[idx - 1];
                                                selectedSteps[idx - 1] =
                                                    selectedSteps[idx];
                                                selectedSteps[idx] = temp;
                                              });
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 20,
                                      ),
                                      onPressed: idx == selectedSteps.length - 1
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                final temp =
                                                    selectedSteps[idx + 1];
                                                selectedSteps[idx + 1] =
                                                    selectedSteps[idx];
                                                selectedSteps[idx] = temp;
                                              });
                                            },
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedSteps.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
                  final nameCN = nameCNController.text.trim();
                  if (nameCN.isEmpty) {
                    return;
                  }
                  try {
                    final success = isEdit
                        ? await _systemService.updateSemiProduct(
                            item['code'] as String,
                            nameCN,
                            nameENController.text.trim(),
                            description: descriptionController.text.trim(),
                            rawMaterialCodes: selectedRawMaterials,
                            toolCodes: selectedToolCodes,
                            steps: selectedSteps,
                          )
                        : await _systemService.addSemiProduct(
                            _generateCode('CURN', _semiProducts),
                            nameCN,
                            nameENController.text.trim(),
                            description: descriptionController.text.trim(),
                            rawMaterialCodes: selectedRawMaterials,
                            toolCodes: selectedToolCodes,
                            steps: selectedSteps,
                          );
                    if (success) {
                      await _loadAllData();
                      if (mounted) {
                        Navigator.of(context).pop();
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

  Future<({Uint8List bytes, String fileName})?> _pickImageAsset() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) {
      return null;
    }

    return (bytes: await imageFile.readAsBytes(), fileName: imageFile.name);
  }

  Future<void> _showKitchenToolDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );
    Uint8List? toolImage = item?['imageBytes'] as Uint8List?;
    String? toolImageUrl = item?['imageUrl'] as String?;
    String? toolImageFileName = item?['imagePath'] as String?;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '编辑厨具' : '添加厨具'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
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
                    decoration: const InputDecoration(
                      labelText: 'Chinese Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameENController,
                    decoration: const InputDecoration(
                      labelText: 'English Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final picked = await _pickImageAsset();
                            if (picked != null) {
                              setDialogState(() {
                                toolImage = picked.bytes;
                                toolImageFileName = picked.fileName;
                                toolImageUrl = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.image),
                    label: Text(toolImage == null ? '选择图片' : '更换图片'),
                  ),
                  const SizedBox(height: 12),
                  if (toolImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        toolImage!,
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (toolImageUrl?.isNotEmpty == true)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _displayImageUrl(toolImageUrl!),
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              width: 150,
                              height: 150,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0x11000000),
                                ),
                                child: Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 150,
                      height: 150,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x11000000)),
                        child: Icon(Icons.kitchen, size: 40),
                      ),
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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final nameCN = nameCNController.text.trim();
                      if (nameCN.isEmpty) {
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                      });
                      try {
                        final success = isEdit
                            ? await _systemService.updateKitchenTool(
                                item['code'] as String,
                                nameCN,
                                nameENController.text.trim(),
                                toolImage,
                                toolImageFileName,
                              )
                            : await _systemService.addKitchenTool(
                                _generateCode('TOOL', _kitchenTools),
                                nameCN,
                                nameENController.text.trim(),
                                toolImage,
                                toolImageFileName,
                              );
                        if (success) {
                          await _loadAllData();
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                        });
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
        ),
      ),
    );
  }

  Future<void> _showProcessDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );
    List<String> selectedToolCodes = List<String>.from(
      item?['toolCodes'] ?? [],
    );

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Process' : 'Add Process'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
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
                    decoration: const InputDecoration(
                      labelText: 'Chinese Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameENController,
                    decoration: const InputDecoration(
                      labelText: 'English Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Tools:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tools.map((tool) {
                      final toolCode = tool['code'] as String;
                      final isSelected = selectedToolCodes.contains(toolCode);
                      return FilterChip(
                        label: Text(
                          _orderedName(
                            tool['nameCN'] as String?,
                            tool['nameEN'] as String?,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedToolCodes.add(toolCode);
                            } else {
                              selectedToolCodes.remove(toolCode);
                            }
                          });
                        },
                      );
                    }).toList(),
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
                final nameCN = nameCNController.text.trim();
                if (nameCN.isEmpty) {
                  return;
                }
                try {
                  final success = isEdit
                      ? await _systemService.updateProcess(
                          item['code'] as String,
                          nameCN,
                          nameENController.text.trim(),
                          selectedToolCodes,
                        )
                      : await _systemService.addProcess(
                          nameCN,
                          nameENController.text.trim(),
                          selectedToolCodes,
                        );
                  if (success) {
                    await _loadAllData();
                    if (mounted) {
                      Navigator.of(context).pop();
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
      ),
    );
  }

  Future<void> _showToolDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final nameCNController = TextEditingController(
      text: item?['nameCN'] as String? ?? '',
    );
    final nameENController = TextEditingController(
      text: item?['nameEN'] as String? ?? '',
    );
    Uint8List? toolImage = item?['imageBytes'] as Uint8List?;
    String? toolImageUrl = item?['imageUrl'] as String?;
    String? toolImageFileName = item?['imagePath'] as String?;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Tool' : 'Add Tool'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
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
                    decoration: const InputDecoration(
                      labelText: 'Chinese Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameENController,
                    decoration: const InputDecoration(
                      labelText: 'English Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final picked = await _pickAndEditImage();
                            if (picked != null) {
                              setDialogState(() {
                                toolImage = picked.bytes;
                                toolImageFileName = picked.fileName;
                                toolImageUrl = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      toolImage != null || toolImageUrl != null
                          ? 'Replace Photo'
                          : 'Upload Photo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (toolImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        toolImage!,
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (toolImageUrl?.isNotEmpty == true)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _displayImageUrl(toolImageUrl!),
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              width: 180,
                              height: 180,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0x11000000),
                                ),
                                child: Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 180,
                      height: 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x11000000)),
                        child: Icon(Icons.build, size: 40),
                      ),
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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final nameCN = nameCNController.text.trim();
                      if (nameCN.isEmpty) {
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                      });
                      try {
                        final success = isEdit
                            ? await _systemService.updateTool(
                                item['code'] as String,
                                nameCN,
                                nameENController.text.trim(),
                                toolImage,
                                toolImageFileName,
                              )
                            : await _systemService.addTool(
                                nameCN,
                                nameENController.text.trim(),
                                toolImage,
                                toolImageFileName,
                              );
                        if (success) {
                          await _loadAllData();
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                        });
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
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadAllData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildRawMaterialTab(),
        _buildSupplierTab(),
        _buildUnitTab(),
        _buildRegionTab(),
        _buildStoreTab(),
        _buildKitchenToolTab(),
        _buildProcessTab(),
        _buildToolTab(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '原材料'),
            Tab(text: '供应商'),
            Tab(text: '单位'),
            Tab(text: '区域'),
            Tab(text: '门店'),
            Tab(text: '厨具'),
            Tab(text: '工艺'),
            Tab(text: '工具'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildProcessTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _showProcessDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Process'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _processes.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: _processes.length,
                    itemBuilder: (context, index) {
                      final item = _processes[index];
                      final toolCodes =
                          item['toolCodes'] as List<dynamic>? ?? [];
                      final toolNames = toolCodes
                          .map((code) {
                            final tool = _tools.firstWhere(
                              (t) => t['code'] == code,
                              orElse: () => {'nameCN': code, 'nameEN': ''},
                            );
                            return _orderedName(
                              tool['nameCN'] as String?,
                              tool['nameEN'] as String?,
                            );
                          })
                          .join(', ');
                      final displayName = _orderedName(
                        item['nameCN'] as String?,
                        item['nameEN'] as String?,
                      );
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      'Tools: $toolNames',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    Text(
                                      'Code: ${item['code']}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _showProcessDialog(item: item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    onPressed: () => _confirmDelete(
                                      title: displayName,
                                      onDelete: () =>
                                          _systemService.deleteProcess(
                                            item['code'] as String,
                                          ),
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
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
    );
  }

  Widget _buildToolTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _showToolDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Tool'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tools.isEmpty
                ? const Center(child: Text('No data'))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: _tools.length,
                    itemBuilder: (context, index) {
                      final item = _tools[index];
                      final imageUrl = item['imageUrl'] as String?;
                      final displayName = _orderedName(
                        item['nameCN'] as String?,
                        item['nameEN'] as String?,
                      );
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Expanded(
                                child: imageUrl?.isNotEmpty == true
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _displayImageUrl(imageUrl!),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: Color(0x11000000),
                                                    ),
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 40,
                                                    ),
                                                  ),
                                        ),
                                      )
                                    : const DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(0x11000000),
                                        ),
                                        child: Icon(Icons.build, size: 40),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item['code'] as String? ?? '-',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _showToolDialog(item: item),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _confirmDelete(
                                      title: displayName,
                                      onDelete: () => _systemService.deleteTool(
                                        item['code'] as String,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
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
          ),
        ],
      ),
    );
  }

  Widget _buildRawMaterialTab() {
    final filteredRawMaterials = _filteredRawMaterials.where((item) {
      if (_selectedRawMaterialListCode == null) {
        return true;
      }
      return item['code'] == _selectedRawMaterialListCode;
    }).toList();
    final filterOptions = _rawMaterialFilterOptions;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _showRawMaterialDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Raw Material'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showRawMaterialCategoriesManager,
                icon: const Icon(Icons.category_outlined),
                label: const Text('Manage Categories'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showRawMaterialLocationsManager,
                icon: const Icon(Icons.place_outlined),
                label: const Text('Manage Locations'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownMenu<String>(
                  key: ValueKey(
                    'raw-material-list-search-${_selectedRawMaterialListCode ?? 'all'}-${_rawMaterials.length}',
                  ),
                  initialSelection: _selectedRawMaterialListCode,
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  label: const Text('搜索原材料'),
                  hintText: '选择或搜索中文 / 英文 / 编号',
                  onSelected: (value) {
                    setState(() {
                      _selectedRawMaterialListCode = value;
                    });
                  },
                  dropdownMenuEntries: _rawMaterials.map((material) {
                    final code = material['code'] as String;
                    return DropdownMenuEntry<String>(
                      value: code,
                      label: _rawMaterialOptionLabel(material),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _selectedRawMaterialListCode == null
                    ? null
                    : () {
                        setState(() {
                          _selectedRawMaterialListCode = null;
                        });
                      },
                icon: const Icon(Icons.clear),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filterOptions.map((option) {
                final code = option['code'] as String?;
                final isSelected = _selectedRawMaterialCategoryCode == code;
                final label = option['label'] as String? ?? '-';
                final count = option['count'] as int? ?? 0;
                return ChoiceChip(
                  label: Text('$label ($count)'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedRawMaterialCategoryCode = code;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredRawMaterials.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: filteredRawMaterials.length,
                    itemBuilder: (context, index) {
                      final item = filteredRawMaterials[index];
                      final imageBytes = item['imageBytes'] as Uint8List?;
                      final imageUrl = item['imageUrl'] as String?;
                      final displayName = _orderedName(
                        item['nameCN'] as String?,
                        item['nameEN'] as String?,
                      );
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              imageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.memory(
                                        imageBytes,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : imageUrl != null && imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        _displayImageUrl(imageUrl),
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const SizedBox(
                                                  width: 64,
                                                  height: 64,
                                                  child: Icon(
                                                    Icons.broken_image,
                                                  ),
                                                ),
                                      ),
                                    )
                                  : const SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Icon(Icons.inventory_2_outlined),
                                    ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['code']} - $displayName',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Spec: ${_orDash(item['specification'] as String?)}',
                                    ),
                                    Text(
                                      'Category: ${_orDash(item['categoryName'] as String?)}',
                                    ),
                                    Text(
                                      'Location: ${_orDash(item['locationName'] as String?)}',
                                    ),
                                    Text(
                                      'Primary Supplier: ${_orDash(item['primarySupplierName'] as String?)}',
                                    ),
                                    Text(
                                      'Secondary Supplier: ${_orDash(item['secondarySupplierName'] as String?)}',
                                    ),
                                    Text(
                                      'Minimum Quantity: ${item['minQuantity'] ?? 0}',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _showRawMaterialDialog(item: item),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    onPressed: () => _confirmDelete(
                                      title: item['code'] as String,
                                      onDelete: () =>
                                          _systemService.deleteRawMaterial(
                                            item['code'] as String,
                                          ),
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete',
                                  ),
                                ],
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
    );
  }

  Widget _buildSupplierTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showSupplierDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Supplier'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _suppliers.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: _suppliers.length,
                    itemBuilder: (context, index) {
                      final item = _suppliers[index];
                      final alias = (item['alias'] as String?)?.trim();
                      final contact = (item['contact'] as String?)?.trim();
                      final address = (item['address'] as String?)?.trim();
                      return Card(
                        child: ListTile(
                          title: Text('${item['code']} - ${item['name']}'),
                          subtitle: Text(
                            'Alias: ${alias?.isNotEmpty == true ? alias : '-'}\n'
                            'Contact: ${contact?.isNotEmpty == true ? contact : '-'}\n'
                            'Address: ${address?.isNotEmpty == true ? address : '-'}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _showSupplierDialog(item: item),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(
                                  title: item['code'] as String,
                                  onDelete: () => _systemService.deleteSupplier(
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
    );
  }

  Widget _buildUnitTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showUnitDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Unit'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _units.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: _units.length,
                    itemBuilder: (context, index) {
                      final item = _units[index];
                      final displayName = _orderedName(
                        item['nameCN'] as String?,
                        item['nameEN'] as String?,
                      );
                      return Card(
                        child: ListTile(
                          title: Text('${item['code']} - $displayName'),
                          subtitle: const Text('-'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () => _showUnitDialog(item: item),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(
                                  title: item['code'] as String,
                                  onDelete: () => _systemService.deleteUnit(
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
    );
  }

  Widget _buildRegionTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showRegionDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Region'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _regions.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: _regions.length,
                    itemBuilder: (context, index) {
                      final item = _regions[index];
                      final displayName = _orderedName(
                        item['nameCN'] as String?,
                        item['nameEN'] as String?,
                      );
                      final note = (item['note'] as String?)?.trim();
                      return Card(
                        child: ListTile(
                          title: Text('${item['code']} - $displayName'),
                          subtitle: Text(
                            [if (note?.isNotEmpty == true) note!].isEmpty
                                ? '-'
                                : [
                                    if (note?.isNotEmpty == true) note!,
                                  ].join('\n'),
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () => _showRegionDialog(item: item),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(
                                  title: item['code'] as String,
                                  onDelete: () => _systemService.deleteRegion(
                                    item['code'] as String,
                                  ),
                                ),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                          isThreeLine: false,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStoreDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final codeController = TextEditingController(
      text: item?['code'] as String? ?? '',
    );
    final nameController = TextEditingController(
      text: item?['name'] as String? ?? '',
    );
    final noteController = TextEditingController(
      text: item?['note'] as String? ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑门店' : '新增门店'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdit)
                TextField(
                  controller: codeController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '编码'),
                )
              else
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: '编码'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: '备注'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              final name = nameController.text.trim();
              final note = noteController.text.trim();
              if (code.isEmpty || name.isEmpty) {
                _showMessage('编码和名称必填');
                return;
              }

              try {
                final success = isEdit
                    ? await _systemService.updateStore(code, name, note)
                    : await _systemService.addStore(code, name, note);
                if (success) {
                  await _loadAllData();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              } catch (e) {
                if (mounted) {
                  _showMessage('保存失败: $e');
                }
              }
            },
            child: Text(isEdit ? '保存' : '新增'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showStoreDialog(),
              icon: const Icon(Icons.add_business),
              label: const Text('新增门店'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _stores.isEmpty
                ? const Center(child: Text('暂无门店'))
                : ListView.builder(
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final item = _stores[index];
                      final code = item['code'] as String? ?? '-';
                      final name = item['name'] as String? ?? '-';
                      final note = (item['note'] as String?)?.trim();
                      return Card(
                        child: ListTile(
                          title: Text('$code - $name'),
                          subtitle: Text(
                            note?.isNotEmpty == true ? note! : '-',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () => _showStoreDialog(item: item),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(
                                  title: code,
                                  onDelete: () =>
                                      _systemService.deleteStore(code),
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
    );
  }

  Widget _buildSemiProductTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showSemiProductDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Semi Product'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _semiProducts.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: _semiProducts.length,
                    itemBuilder: (context, index) {
                      final item = _semiProducts[index];
                      final displayName = _orderedName(
                        item['nameCN'] as String?,
                        item['nameEN'] as String?,
                      );
                      return Card(
                        child: ListTile(
                          title: Text('${item['code']} - $displayName'),
                          subtitle: const Text('-'),
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
    );
  }

  Widget _buildKitchenToolTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showKitchenToolDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Kitchen Tool'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _kitchenTools.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: _kitchenTools.length,
                    itemBuilder: (context, index) {
                      final item = _kitchenTools[index];
                      final imageBytes = item['imageBytes'] as Uint8List?;
                      final imageUrl = item['imageUrl'] as String?;
                      final displayName = _orderedName(
                        item['nameCN'] as String?,
                        item['nameEN'] as String?,
                      );
                      return Card(
                        child: ListTile(
                          leading: imageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(
                                    imageBytes,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : imageUrl != null && imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    _displayImageUrl(imageUrl),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: Icon(Icons.broken_image),
                                            ),
                                  ),
                                )
                              : const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Icon(Icons.kitchen),
                                ),
                          title: Text('${item['code']} - $displayName'),
                          subtitle: const Text('-'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _showKitchenToolDialog(item: item),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(
                                  title: item['code'] as String,
                                  onDelete: () =>
                                      _systemService.deleteKitchenTool(
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
    );
  }
}
