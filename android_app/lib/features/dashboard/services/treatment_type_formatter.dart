import 'dart:convert';

/// 治疗类型格式化辅助类
class TreatmentTypeFormatter {
  // 牙位映射表 - 从医生视角看患者牙齿
  static const Map<String, String> positionMap = {
    'topLeft': '右上',
    'topRight': '左上',
    'bottomLeft': '右下',
    'bottomRight': '左下',
  };

  /// 格式化治疗类型显示
  static String formatTreatmentType(String? treatmentType) {
    if (treatmentType == null || treatmentType.isEmpty) {
      return '常规复诊';
    }

    try {
      // 尝试解析JSON
      final data = json.decode(treatmentType);
      final List<String> displayParts = [];

      // 处理牙位信息
      if (data.containsKey('teethData') &&
          data['teethData'] is List &&
          (data['teethData'] as List).isNotEmpty) {
        for (var i = 0; i < (data['teethData'] as List).length; i++) {
          final teethData = data['teethData'][i];
          final List<String> positions = [];

          // 获取各个牙位的值
          teethData.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              // 使用牙位映射表转换位置名称
              if (positionMap.containsKey(key)) {
                positions.add('${positionMap[key]} $value');
              }
            }
          });

          if (positions.isNotEmpty) {
            displayParts.add('牙位${i + 1}: ${positions.join('，')}');
          }
        }
      }

      // 处理治疗项目
      if (data.containsKey('treatments') &&
          data['treatments'] is List &&
          (data['treatments'] as List).isNotEmpty) {
        final treatments = (data['treatments'] as List).join('、');
        if (displayParts.isNotEmpty) {
          displayParts.add('- $treatments');
        } else {
          displayParts.add(treatments);
        }
      }

      // 返回格式化后的显示文本
      return displayParts.isEmpty ? '常规复诊' : displayParts.join(' ');
    } catch (e) {
      print('解析治疗类型JSON失败: $e');
      return treatmentType; // 如果解析失败，直接返回原始字符串
    }
  }
}
