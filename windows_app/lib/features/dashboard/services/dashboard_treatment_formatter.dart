import 'dart:convert';

/// 仪表盘治疗类型格式化服务
/// 职责：治疗类型 JSON 解析和格式化
class DashboardTreatmentFormatter {
  /// 格式化治疗类型
  /// 将治疗类型的 JSON 字符串格式化为可读文本
  static String formatTreatmentType(String? treatmentType) {
    if (treatmentType == null || treatmentType.isEmpty) {
      return '常规检查';
    }

    try {
      final data = json.decode(treatmentType);
      List<String> displayParts = [];

      // 处理牙位信息
      if (data.containsKey('teethData') &&
          data['teethData'] is List &&
          (data['teethData'] as List).isNotEmpty) {
        List teethData = data['teethData'];

        for (int i = 0; i < teethData.length; i++) {
          List<String> positions = [];
          Map<String, dynamic> tooth = Map<String, dynamic>.from(teethData[i]);

          // 检查所有可能的字段名称
          final fieldMapping = {
            'topLeft': '右上',
            'topRight': '左上',
            'bottomLeft': '右下',
            'bottomRight': '左下',
            'upperLeft': '右上',
            'upperRight': '左上',
            'lowerLeft': '右下',
            'lowerRight': '左下',
          };

          fieldMapping.forEach((field, label) {
            if (tooth.containsKey(field) &&
                tooth[field] != null &&
                tooth[field].toString().isNotEmpty) {
              positions.add('$label ${tooth[field]}');
            }
          });

          if (positions.isNotEmpty) {
            displayParts.add('牙位${i + 1}: ${positions.join('，')}');
          }
        }
      }

      // 处理治疗项目
      if (data.containsKey('treatments') && data['treatments'] is List) {
        List<String> treatments = List<String>.from(data['treatments']);
        if (treatments.isNotEmpty) {
          if (displayParts.isNotEmpty) {
            displayParts.add('- ${treatments.join("、")}');
          } else {
            displayParts.add(treatments.join("、"));
          }
        }
      }

      return displayParts.isNotEmpty ? displayParts.join(' ') : '常规检查';
    } catch (e) {
      // 如果不是JSON格式，直接返回
      return treatmentType;
    }
  }
}
