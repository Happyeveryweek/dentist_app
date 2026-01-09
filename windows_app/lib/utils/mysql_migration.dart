import 'package:mysql1/mysql1.dart';

/// MySQL数据库迁移工具
class MySQLMigration {
  /// 迁移users表，添加module_permissions列
  static Future<void> migrateUsersPermissionsTable(MySqlConnection connection) async {
    try {
      // 检查module_permissions列是否存在
      final result = await connection.query('''
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'users' 
        AND COLUMN_NAME = 'module_permissions'
      ''');
      
      if (result.isEmpty) {
        print('正在为users表添加module_permissions列...');
        
        // 添加module_permissions列
        await connection.query('ALTER TABLE users ADD COLUMN module_permissions JSON');
        
        // 为现有用户设置默认权限配置
        // 管理员用户获得全权限
        await connection.query('''
          UPDATE users 
          SET module_permissions = JSON_OBJECT(
            'dashboard', true,
            'patients', true,
            'appointments', true,
            'financial', true,
            'materials', true,
            'purchase', true,
            'users', true,
            'settings', true
          )
          WHERE role = 'admin'
        ''');
        
        // 其他用户获得基础权限（仅仪表盘）
        await connection.query('''
          UPDATE users 
          SET module_permissions = JSON_OBJECT(
            'dashboard', true,
            'patients', false,
            'appointments', false,
            'financial', false,
            'materials', false,
            'purchase', false,
            'users', false,
            'settings', false
          )
          WHERE role != 'admin'
        ''');
        
        print('module_permissions列添加成功，已为现有用户设置默认权限');
      } else {
        print('module_permissions列已存在，跳过迁移');
      }
      
      print('MySQL users表权限迁移完成');
    } catch (e) {
      print('迁移MySQL users表权限时出错: $e');
      rethrow;
    }
  }

  /// 执行所有MySQL数据库迁移
  static Future<void> migrateAll(MySqlConnection connection) async {
    print('开始执行MySQL数据库迁移...');
    
    try {
      await migrateUsersPermissionsTable(connection);
      print('所有MySQL数据库迁移完成');
    } catch (e) {
      print('MySQL数据库迁移失败: $e');
      rethrow;
    }
  }

  /// 检查表是否存在
  static Future<bool> tableExists(MySqlConnection connection, String tableName) async {
    try {
      final result = await connection.query('''
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = ?
      ''', [tableName]);
      return result.isNotEmpty;
    } catch (e) {
      print('检查MySQL表是否存在时出错: $e');
      return false;
    }
  }

  /// 获取表结构信息
  static Future<List<Map<String, dynamic>>> getTableInfo(MySqlConnection connection, String tableName) async {
    try {
      final result = await connection.query('''
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = ?
        ORDER BY ORDINAL_POSITION
      ''', [tableName]);
      
      return result.map((row) => {
        'name': row['COLUMN_NAME'],
        'type': row['DATA_TYPE'],
        'nullable': row['IS_NULLABLE'],
        'default': row['COLUMN_DEFAULT'],
      }).toList();
    } catch (e) {
      print('获取MySQL表结构信息时出错: $e');
      return [];
    }
  }

  /// 备份现有数据（如果需要）
  static Future<void> backupTableData(MySqlConnection connection, String tableName) async {
    try {
      if (await tableExists(connection, tableName)) {
        final result = await connection.query('SELECT COUNT(*) as count FROM $tableName');
        final count = result.first['count'];
        print('表 $tableName 包含 $count 条记录');
        // 这里可以添加备份逻辑
      }
    } catch (e) {
      print('备份MySQL表数据时出错: $e');
    }
  }
}