import 'dart:convert';

const String semiProductDetailTypeRawMaterial = 'raw_material';
const String semiProductDetailTypeStep = 'step';
const String semiProductDetailTypeTool = 'tool';
const String semiProductDetailTypeProduct = 'product';
const String semiProductDetailTypeSemiProduct = 'semi_product';

List<Map<String, String>> decodeSemiProductDetails(List<dynamic>? rawDetails) {
  if (rawDetails == null) {
    return [];
  }

  return rawDetails.map((item) {
    if (item is Map) {
      final type = (item['type'] as String?)?.trim();
      final description = (item['description'] as String?)?.trim();
      return {
        'type': _normalizeDetailType(type),
        'referenceCode': (item['referenceCode'] as String?)?.trim() ?? '',
        'referenceLabel': (item['referenceLabel'] as String?)?.trim() ?? '',
        'quantityValue': (item['quantityValue'] as String?)?.trim() ?? '',
        'unitCode': (item['unitCode'] as String?)?.trim() ?? '',
        'unitLabel': (item['unitLabel'] as String?)?.trim() ?? '',
        'kitchenToolCode': (item['kitchenToolCode'] as String?)?.trim() ?? '',
        'kitchenToolLabel': (item['kitchenToolLabel'] as String?)?.trim() ?? '',
        'imagePath': (item['imagePath'] as String?)?.trim() ?? '',
        'imageUrl': (item['imageUrl'] as String?)?.trim() ?? '',
        'description': description ?? '',
      };
    }

    if (item is String) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          final type = (decoded['type'] as String?)?.trim();
          final description = (decoded['description'] as String?)?.trim();
          return {
            'type': _normalizeDetailType(type),
            'referenceCode':
                (decoded['referenceCode'] as String?)?.trim() ?? '',
            'referenceLabel':
                (decoded['referenceLabel'] as String?)?.trim() ?? '',
            'quantityValue':
                (decoded['quantityValue'] as String?)?.trim() ?? '',
            'unitCode': (decoded['unitCode'] as String?)?.trim() ?? '',
            'unitLabel': (decoded['unitLabel'] as String?)?.trim() ?? '',
            'kitchenToolCode':
                (decoded['kitchenToolCode'] as String?)?.trim() ?? '',
            'kitchenToolLabel':
                (decoded['kitchenToolLabel'] as String?)?.trim() ?? '',
            'imagePath': (decoded['imagePath'] as String?)?.trim() ?? '',
            'imageUrl': (decoded['imageUrl'] as String?)?.trim() ?? '',
            'description': description ?? '',
          };
        }
      } catch (_) {
        return {
          'type': semiProductDetailTypeStep,
          'referenceCode': '',
          'referenceLabel': '',
          'quantityValue': '',
          'unitCode': '',
          'unitLabel': '',
          'kitchenToolCode': '',
          'kitchenToolLabel': '',
          'imagePath': '',
          'imageUrl': '',
          'description': item.trim(),
        };
      }
    }

    return {
      'type': semiProductDetailTypeStep,
      'referenceCode': '',
      'referenceLabel': '',
      'quantityValue': '',
      'unitCode': '',
      'unitLabel': '',
      'kitchenToolCode': '',
      'kitchenToolLabel': '',
      'imagePath': '',
      'imageUrl': '',
      'description': item?.toString() ?? '',
    };
  }).toList();
}

List<String> encodeSemiProductDetails(List<Map<String, dynamic>> details) {
  return details.map((detail) {
    return jsonEncode({
      'type': _normalizeDetailType(detail['type'] as String?),
      'referenceCode': (detail['referenceCode'] as String? ?? '').trim(),
      'referenceLabel': (detail['referenceLabel'] as String? ?? '').trim(),
      'quantityValue': (detail['quantityValue'] as String? ?? '').trim(),
      'unitCode': (detail['unitCode'] as String? ?? '').trim(),
      'unitLabel': (detail['unitLabel'] as String? ?? '').trim(),
      'kitchenToolCode': (detail['kitchenToolCode'] as String? ?? '').trim(),
      'kitchenToolLabel': (detail['kitchenToolLabel'] as String? ?? '').trim(),
      'imagePath': (detail['imagePath'] as String? ?? '').trim(),
      'imageUrl': (detail['imageUrl'] as String? ?? '').trim(),
      'description': (detail['description'] as String? ?? '').trim(),
    });
  }).toList();
}

String semiProductDetailTypeLabel(String type) {
  switch (_normalizeDetailType(type)) {
    case semiProductDetailTypeRawMaterial:
      return '原材料';
    case semiProductDetailTypeTool:
      return '实用工具';
    case semiProductDetailTypeProduct:
      return '成品';
    case semiProductDetailTypeSemiProduct:
      return '半成品';
    case semiProductDetailTypeStep:
      return '步骤';
    default:
      return '步骤';
  }
}

String _normalizeDetailType(String? type) {
  switch (type) {
    case semiProductDetailTypeRawMaterial:
      return semiProductDetailTypeRawMaterial;
    case semiProductDetailTypeTool:
      return semiProductDetailTypeTool;
    case semiProductDetailTypeProduct:
      return semiProductDetailTypeProduct;
    case semiProductDetailTypeSemiProduct:
      return semiProductDetailTypeSemiProduct;
    case semiProductDetailTypeStep:
    default:
      return semiProductDetailTypeStep;
  }
}
