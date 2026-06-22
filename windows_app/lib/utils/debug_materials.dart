import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

/// 调试工具：检查患者材料数据
class DebugMaterials {
  static Future<void> debugPatientMaterials(String dbPath) async {
    try {
      print('=== 开始调试患者材料数据 ===');
      print('数据库路径: $dbPath');
      
      final database = await openDatabase(dbPath);
      
      // 检查患者材料表
      print('\n--- 检查 patient_materials 表 ---');
      final materialResults = await database.query('patient_materials');
      print('患者材料记录数量: ${materialResults.length}');
      
      for (var material in materialResults) {
        try {
          final id = material['id'] ?? material['ID'] ?? 'unknown';
          final desc = material['description'] ?? material['desc'] ?? '';
          print('材料记录: ID=$id, 描述=${desc.toString().replaceAll(RegExp(r"\s+"), ' ').trim()}');
        } catch (_) {
          print('材料记录: 无法解析该记录的完整信息');
        }
      }
      
      // 检查材料图片表
      print('\n--- 检查 material_images 表 ---');
      final imageResults = await database.query('material_images');
      print('材料图片记录数量: ${imageResults.length}');
      
      for (var image in imageResults) {
        try {
          final id = image['id'] ?? 'unknown';
          final mid = image['material_id'] ?? 'unknown';
          final size = image['file_size'] ?? 0;
          final type = image['image_type'] ?? '';
          final name = image['original_name'] ?? '';
          print('图片记录: ID=$id, 材料ID=$mid, 名称=$name, 大小=$size, 类型=$type');
        } catch (_) {
          print('图片记录: 无法解析该图片记录的完整信息');
        }
      }
      
      // 检查表结构
      print('\n--- 检查表结构 ---');
      final materialTableInfo = await database.query('sqlite_master', 
        where: 'type = ? AND name = ?', 
        whereArgs: ['table', 'patient_materials']
      );
      
      if (materialTableInfo.isNotEmpty) {
        print('patient_materials 表存在，详情省略');
      }
      
      final imageTableInfo = await database.query('sqlite_master', 
        where: 'type = ? AND name = ?', 
        whereArgs: ['table', 'material_images']
      );
      
      if (imageTableInfo.isNotEmpty) {
        print('material_images 表存在，详情省略');
      }
      
      await database.close();
      print('\n=== 调试完成 ===');
      
    } catch (e) {
      print('调试过程中出错: $e');
      print('错误堆栈: ${StackTrace.current}');
    }
  }
}
