import 'dart:io';

/// 时间格式迁移脚本
/// 批量替换代码中的时间格式处理
class TimeFormatMigration {
  
  /// 批量替换文件中的时间格式
  static Future<void> migrateFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      print('文件不存在: $filePath');
      return;
    }
    
    String content = await file.readAsString();
    
    // 替换所有的 toIso8601String() 为 DateTimeFormatter.toDbString()
    content = content.replaceAll(
      RegExp(r'(\w+)\.toIso8601String\(\)'),
      'DateTimeFormatter.toDbString(\$1)'
    );
    
    // 替换 DateTime.parse() 为 DateTimeFormatter.fromDbString()
    content = content.replaceAll(
      RegExp(r'DateTime\.parse\(([^)]+)\)'),
      'DateTimeFormatter.fromDbString(\$1)'
    );
    
    // 添加导入语句（如果不存在）
    if (!content.contains("import '../utils/datetime_formatter.dart';")) {
      // 在第一个import语句后添加
      content = content.replaceFirst(
        RegExp(r"(import '[^']+';)"),
        "\$1\nimport '../utils/datetime_formatter.dart';"
      );
    }
    
    await file.writeAsString(content);
    print('已更新文件: $filePath');
  }
  
  /// 批量迁移所有数据源文件
  static Future<void> migrateAllDataSources() async {
    final dataSources = [
      'windows_app/lib/data_sources/patient_data_source.dart',
      'windows_app/lib/data_sources/purchase_data_source.dart',
      'windows_app/lib/data_sources/financial_data_source.dart',
      'windows_app/lib/data_sources/material_data_source.dart',
      'windows_app/lib/data_sources/appointment_data_source.dart',
      'windows_app/lib/data_sources/user_data_source.dart',
    ];
    
    for (final filePath in dataSources) {
      await migrateFile(filePath);
    }
  }
}