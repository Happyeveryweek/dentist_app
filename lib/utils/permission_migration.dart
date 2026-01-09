import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:convert';

/// 权限管理数据库迁移工具
/// 用于为现有的用户表添加权限字段
class PermissionMigration {
  
  /// 为SQLite数据库添加权限字段
  static Future<void> migrateSQLiteAddPermissionsField(Database database) async {
    try {
      print('开始为SQLite用户表添加权限字段...');
      
      // 检查字段是否已存在
      final tableInfo = await database.rawQuery('PRAGMA table_info(users)');
      final hasPermissionsField = tableInfo.any((column) => column['name'] == 'module_permissions');
      
      if (!hasPermissionsField) {
        // 添加权限字段
        await database.execute('ALTER TABLE users ADD COLUMN module_permissions TEXT');
        
        // 为现有用户设置默认权限配置
        await _setDefaultPermissions(database);
        
        print('✅ 成功为SQLite用户表添加权限字段');
      } else {
        print('ℹ️ SQLite用户表已包含权限字段，跳过迁移');
      }
    } catch (e) {
      print('❌ SQLite用户表添加权限字段失败: $e');
      rethrow;
    }
  }
  
  /// 为MySQL数据库添加权限字段
  static Future<void> migrateMySQLAddPermissionsField(MySqlConnection connection) async {
    try {
      print('开始为MySQL用户表添加权限字段...');
      
      // 检查字段是否已存在
      final results = await connection.query('''
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'module_permissions'
      ''');
      
      if (results.isEmpty) {
        // 添加权限字段
        await connection.query('''
          ALTER TABLE users 
          ADD COLUMN module_permissions JSON DEFAULT NULL
        ''');
        
        // 为现有用户设置默认权限配置
        await _setDefaultPermissionsMySQL(connection);
        
        print('✅ 成功为MySQL用户表添加权限字段');
      } else {
        print('ℹ️ MySQL用户表已包含权限字段，跳过迁移');
      }
    } catch (e) {
      print('❌ MySQL用户表添加权限字段失败: $e');
      rethrow;
    }
  }
  
  /// 为SQLite现有用户设置默认权限配置
  static Future<void> _setDefaultPermissions(Database database) async {
    try {
      // 管理员用户获得全权限
      final adminPermissions = jsonEncode({
        'dashboard': true,
        'patients': true,
        'appointments': true,
        'financial': true,
        'materials': true,
        'purchase': true,
        'users': true,
        'settings': true,
      });
      
      await database.execute('''
        UPDATE users 
        SET module_permissions = ? 
        WHERE role = 'admin'
      ''', [adminPermissions]);
      
      // 其他用户获得基础权限（仅仪表盘）
      final basicPermissions = jsonEncode({
        'dashboard': true,
        'patients': false,
        'appointments': false,
        'financial': false,
        'materials': false,
        'purchase': false,
        'users': false,
        'settings': false,
      });
      
      await database.execute('''
        UPDATE users 
        SET module_permissions = ? 
        WHERE role != 'admin'
      ''', [basicPermissions]);
      
      print('✅ 已为现有SQLite用户设置默认权限配置');
    } catch (e) {
      print('❌ 设置SQLite默认权限配置失败: $e');
      rethrow;
    }
  }
  
  /// 为MySQL现有用户设置默认权限配置
  static Future<void> _setDefaultPermissionsMySQL(MySqlConnection connection) async {
    try {
      // 管理员用户获得全权限
      final adminPermissions = jsonEncode({
        'dashboard': true,
        'patients': true,
        'appointments': true,
        'financial': true,
        'materials': true,
        'purchase': true,
        'users': true,
        'settings': true,
      });
      
      await connection.query('''
        UPDATE users 
        SET module_permissions = ? 
        WHERE role = 'admin'
      ''', [adminPermissions]);
      
      // 其他用户获得基础权限（仅仪表盘）
      final basicPermissions = jsonEncode({
        'dashboard': true,
        'patients': false,
        'appointments': false,
        'financial': false,
        'materials': false,
        'purchase': false,
        'users': false,
        'settings': false,
      });
      
      await connection.query('''
        UPDATE users 
        SET module_permissions = ? 
        WHERE role != 'admin'
      ''', [basicPermissions]);
      
      print('✅ 已为现有MySQL用户设置默认权限配置');
    } catch (e) {
      print('❌ 设置MySQL默认权限配置失败: $e');
      rethrow;
    }
  }
  
  /// 自动检测并执行权限迁移
  static Future<void> autoMigrate({
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
  }) async {
    try {
      if (sqliteDatabase != null) {
        await migrateSQLiteAddPermissionsField(sqliteDatabase);
      }
      
      if (mysqlConnection != null) {
        await migrateMySQLAddPermissionsField(mysqlConnection);
      }
      
      print('🎉 权限管理数据库迁移完成');
    } catch (e) {
      print('❌ 权限管理数据库迁移失败: $e');
      rethrow;
    }
  }
}