import 'package:flutter/material.dart';
import 'database_provider.dart';

// 连接池测试类
class ConnectionPoolTester {
  static Future<void> testConnectionPool() async {
    try {
      print('开始测试MySQL连接池...');
      
      final dbProvider = DatabaseProvider();
      await dbProvider.initDatabase();
      
      if (dbProvider.dbType == 'mysql') {
        final pool = dbProvider.connectionPool;
        if (pool != null) {
          print('连接池已初始化');
          
          // 测试连接池健康状态
          final isHealthy = await pool.checkHealth();
          print('连接池健康状态: $isHealthy');
          
          // 获取连接池统计信息
          final stats = pool.getPoolStats();
          print('连接池统计: $stats');
          
          // 测试简单查询
          final results = await pool.query('SELECT 1 as test_value');
          print('测试查询结果: $results');
          
          // 测试获取详细统计信息
          final detailedStats = pool.getDetailedStats();
          print('详细连接池信息: $detailedStats');
          
          print('连接池测试完成！');
        } else {
          print('连接池未初始化');
        }
      } else {
        print('当前不是MySQL模式，跳过连接池测试');
      }
      
      await dbProvider.closeDatabase();
    } catch (e) {
      print('连接池测试失败: $e');
    }
  }
}