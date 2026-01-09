import 'dart:convert';

/// 牙齿状况集成工具类
/// 用于解析和处理患者的牙齿状况数据，支持病历与牙齿状况的关联
class DentalConditionIntegration {
  /// 从患者的dental_condition字段解析牙齿状况数据
  /// 
  /// [dentalConditionJson] 患者的dental_condition字段内容（JSON字符串）
  /// 返回解析后的Map数据，如果解析失败返回空Map
  static Map<String, dynamic> parseDentalCondition(String? dentalConditionJson) {
    if (dentalConditionJson == null || dentalConditionJson.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(dentalConditionJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        print('DentalConditionIntegration: 解析结果不是Map类型');
        return {};
      }
    } catch (e) {
      print('DentalConditionIntegration: JSON解析失败: $e');
      return {};
    }
  }

  /// 根据日期获取特定的牙齿状况记录
  /// 
  /// [dentalData] 解析后的牙齿状况数据
  /// [targetDate] 目标日期字符串
  /// 返回包含chart1、chart2、chart3数据的Map
  static Map<String, String> getDentalConditionByDate(
    Map<String, dynamic> dentalData, 
    String targetDate
  ) {
    if (dentalData.isEmpty || targetDate.isEmpty) {
      return {};
    }

    // 查找匹配的日期索引
    int? matchingIndex;
    dentalData.forEach((key, value) {
      if (key.startsWith('date-') && value.toString() == targetDate) {
        final indexStr = key.substring(5); // 移除 'date-' 前缀
        try {
          matchingIndex = int.parse(indexStr);
        } catch (e) {
          print('DentalConditionIntegration: 解析日期索引失败: $e');
        }
      }
    });

    if (matchingIndex == null) {
      return {};
    }

    // 提取对应索引的图表数据
    final result = <String, String>{};
    final index = matchingIndex!;

    // 提取chart1数据
    result['chart1-top-left'] = dentalData['chart1-top-left-$index']?.toString() ?? '';
    result['chart1-top-right'] = dentalData['chart1-top-right-$index']?.toString() ?? '';
    result['chart1-bottom-left'] = dentalData['chart1-bottom-left-$index']?.toString() ?? '';
    result['chart1-bottom-right'] = dentalData['chart1-bottom-right-$index']?.toString() ?? '';
    result['chart1-note'] = dentalData['chart1-note-$index']?.toString() ?? '';

    // 提取chart2数据
    result['chart2-top-left'] = dentalData['chart2-top-left-$index']?.toString() ?? '';
    result['chart2-top-right'] = dentalData['chart2-top-right-$index']?.toString() ?? '';
    result['chart2-bottom-left'] = dentalData['chart2-bottom-left-$index']?.toString() ?? '';
    result['chart2-bottom-right'] = dentalData['chart2-bottom-right-$index']?.toString() ?? '';
    result['chart2-note'] = dentalData['chart2-note-$index']?.toString() ?? '';

    // 提取chart3数据
    result['chart3-top-left'] = dentalData['chart3-top-left-$index']?.toString() ?? '';
    result['chart3-top-right'] = dentalData['chart3-top-right-$index']?.toString() ?? '';
    result['chart3-bottom-left'] = dentalData['chart3-bottom-left-$index']?.toString() ?? '';
    result['chart3-bottom-right'] = dentalData['chart3-bottom-right-$index']?.toString() ?? '';
    result['chart3-note'] = dentalData['chart3-note-$index']?.toString() ?? '';

    // 添加日期信息
    result['date'] = targetDate;

    return result;
  }

  /// 获取所有可用的牙齿状况日期列表
  /// 
  /// [dentalData] 解析后的牙齿状况数据
  /// 返回按时间排序的日期列表（最新的在前）
  static List<String> getAvailableDates(Map<String, dynamic> dentalData) {
    if (dentalData.isEmpty) {
      return [];
    }

    final dates = <String>[];
    dentalData.forEach((key, value) {
      if (key.startsWith('date-') && value != null && value.toString().isNotEmpty) {
        dates.add(value.toString());
      }
    });

    // 去重并排序（最新的在前）
    final uniqueDates = dates.toSet().toList();
    uniqueDates.sort((a, b) {
      try {
        final dateA = DateTime.parse(a);
        final dateB = DateTime.parse(b);
        return dateB.compareTo(dateA); // 降序排列
      } catch (e) {
        // 如果日期解析失败，按字符串排序
        return b.compareTo(a);
      }
    });

    return uniqueDates;
  }

  /// 检查指定日期是否存在牙齿状况记录
  /// 
  /// [dentalData] 解析后的牙齿状况数据
  /// [targetDate] 目标日期字符串
  /// 返回是否存在该日期的记录
  static bool hasRecordForDate(Map<String, dynamic> dentalData, String targetDate) {
    if (dentalData.isEmpty || targetDate.isEmpty) {
      return false;
    }

    return dentalData.values.any((value) => value.toString() == targetDate);
  }

  /// 获取牙齿状况记录的摘要信息
  /// 
  /// [dentalData] 解析后的牙齿状况数据
  /// [targetDate] 目标日期字符串
  /// 返回该日期记录的摘要信息
  static String getRecordSummary(Map<String, dynamic> dentalData, String targetDate) {
    final record = getDentalConditionByDate(dentalData, targetDate);
    if (record.isEmpty) {
      return '无记录';
    }

    final notes = <String>[];
    if (record['chart1-note']?.isNotEmpty == true) {
      notes.add('图表1: ${record['chart1-note']}');
    }
    if (record['chart2-note']?.isNotEmpty == true) {
      notes.add('图表2: ${record['chart2-note']}');
    }
    if (record['chart3-note']?.isNotEmpty == true) {
      notes.add('图表3: ${record['chart3-note']}');
    }

    if (notes.isEmpty) {
      return '有记录但无备注';
    }

    return notes.join('; ');
  }

  /// 格式化日期显示
  /// 
  /// [dateString] 日期字符串
  /// 返回格式化后的日期显示文本
  static String formatDateForDisplay(String dateString) {
    if (dateString.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(dateString);
      return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
    } catch (e) {
      // 如果解析失败，返回原始字符串
      return dateString;
    }
  }

  /// 获取日期选择器选项列表
  /// 
  /// [dentalData] 解析后的牙齿状况数据
  /// 返回用于下拉选择器的选项列表，包含"无关联"选项
  static List<Map<String, String>> getDateSelectorOptions(Map<String, dynamic> dentalData) {
    final options = <Map<String, String>>[];
    
    // 添加"无关联"选项
    options.add({
      'value': '',
      'display': '无关联',
    });

    // 添加可用日期选项
    final dates = getAvailableDates(dentalData);
    for (final date in dates) {
      options.add({
        'value': date,
        'display': formatDateForDisplay(date),
      });
    }

    return options;
  }

  /// 验证牙齿状况数据的完整性
  /// 
  /// [dentalData] 解析后的牙齿状况数据
  /// 返回验证结果和错误信息
  static Map<String, dynamic> validateDentalData(Map<String, dynamic> dentalData) {
    final result = {
      'isValid': true,
      'errors': <String>[],
      'warnings': <String>[],
    };

    if (dentalData.isEmpty) {
      (result['warnings'] as List<String>).add('牙齿状况数据为空');
      return result;
    }

    // 检查日期字段的完整性
    final dateKeys = dentalData.keys.where((key) => key.startsWith('date-')).toList();
    for (final dateKey in dateKeys) {
      final indexStr = dateKey.substring(5);
      int? index;
      try {
        index = int.parse(indexStr);
      } catch (e) {
        (result['errors'] as List<String>).add('无效的日期索引: $dateKey');
        result['isValid'] = false;
        continue;
      }

      // 检查对应的图表数据是否存在
      final requiredKeys = [
        'chart1-top-left-$index',
        'chart1-top-right-$index',
        'chart1-bottom-left-$index',
        'chart1-bottom-right-$index',
        'chart1-note-$index',
        'chart2-top-left-$index',
        'chart2-top-right-$index',
        'chart2-bottom-left-$index',
        'chart2-bottom-right-$index',
        'chart2-note-$index',
        'chart3-top-left-$index',
        'chart3-top-right-$index',
        'chart3-bottom-left-$index',
        'chart3-bottom-right-$index',
        'chart3-note-$index',
      ];

      for (final key in requiredKeys) {
        if (!dentalData.containsKey(key)) {
          (result['warnings'] as List<String>).add('缺少字段: $key');
        }
      }
    }

    return result;
  }
}