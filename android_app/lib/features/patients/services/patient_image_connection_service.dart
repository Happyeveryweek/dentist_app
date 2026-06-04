import 'package:mysql1/mysql1.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'dart:async';

/// 患者图片连接管理服务
/// 
/// 职责：
/// - MySQL 连接检查
/// - 自动重连
/// - SQLite 连接检查
/// - 应用恢复时连接检查
class PatientImageConnectionService {
  final DatabaseProvider _databaseProvider;
  
  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  
  // MySQL 连接
  MySqlConnection? _mysqlConnection;
  
  PatientImageConnectionService(this._databaseProvider);
  
  /// 获取连接状态
  bool get isConnected => _isConnected;
  
  /// 获取重连状态
  bool get isReconnecting => _isReconnecting;
  
  /// 设置 MySQL 连接
  void setMysqlConnection(MySqlConnection? connection) {
    _mysqlConnection = connection;
  }
  
  /// 检查并确保连接可用
  Future<bool> ensureConnection() async {
    if (_mysqlConnection == null) {
      print('PatientImageConnectionService: MySQL连接对象为null');
      return false;
    }
    
    try {
      // 测试连接
      await _mysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      print('PatientImageConnectionService: MySQL连接检查成功');
      _isConnected = true;
      return true;
    } catch (e) {
      print('PatientImageConnectionService: 连接检查失败: $e');
      _isConnected = false;
      return false;
    }
  }
  
  /// 自动重连
  Future<bool> autoReconnect() async {
    try {
      print('PatientImageConnectionService: 尝试自动重连MySQL...');
      _isReconnecting = true;
      
      // 等待一段时间后重试
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 重新获取连接
      _mysqlConnection = _databaseProvider.mysqlConnection;
      
      if (_mysqlConnection == null) {
        print('PatientImageConnectionService: 无法自动重连，DatabaseProvider返回null');
        _isReconnecting = false;
        return false;
      }
      
      // 重新检查连接
      final success = await ensureConnection();
      
      if (success) {
        print('PatientImageConnectionService: 自动重连成功');
        _isReconnecting = false;
        return true;
      } else {
        throw Exception('重连失败');
      }
    } catch (e) {
      print('PatientImageConnectionService: 自动重连失败: $e');
      _isReconnecting = false;
      return false;
    }
  }
  
  /// 检查SQLite数据库状态
  Future<bool> checkSQLiteConnection(dynamic sqliteDatabase) async {
    try {
      if (sqliteDatabase == null) {
        print('PatientImageConnectionService: SQLite数据库对象为null');
        return false;
      }
      
      await sqliteDatabase.rawQuery('SELECT 1');
      print('PatientImageConnectionService: SQLite连接检查成功');
      _isConnected = true;
      return true;
    } catch (e) {
      print('PatientImageConnectionService: SQLite连接检查失败: $e');
      _isConnected = false;
      return false;
    }
  }
  
  /// 应用恢复时检查连接状态
  Future<void> checkConnectionOnResume() async {
    if (_mysqlConnection != null) {
      try {
        print('PatientImageConnectionService: 检查MySQL连接状态...');
        final isHealthy = await ensureConnection();
        
        if (!isHealthy) {
          print('PatientImageConnectionService: 连接异常，尝试重连...');
          await autoReconnect();
        } else {
          print('PatientImageConnectionService: 连接状态正常');
        }
      } catch (e) {
        print('PatientImageConnectionService: 检查连接状态失败: $e');
      }
    }
  }
  
  /// 重置连接状态
  void resetConnectionState() {
    _isConnected = true;
    _isReconnecting = false;
  }
}
