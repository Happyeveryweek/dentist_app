import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/message_toast_helper.dart';
import '../../../utils/app_logger.dart';

/// 登录初始化服务
class LoginInitializationService {
  /// 等待数据库和用户表初始化完成
  static Future<bool> waitForInitialization(
    BuildContext context,
    ValueChanged<bool> onInitializationComplete,
  ) async {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      AppLogger.info('🔄 等待数据库初始化...');

      // 第一步：等待数据库初始化（最多等待10秒）
      int retryCount = 0;
      while (!dbProvider.isInitialized && retryCount < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }

      if (!dbProvider.isInitialized) {
        AppLogger.info('❌ 数据库初始化超时');
        if (context.mounted) {
          onInitializationComplete(false);
          MessageToastHelper.showError(context, '数据库初始化超时，请重启应用');
        }
        return false;
      }

      AppLogger.info('✅ 数据库初始化完成 (${dbProvider.dbType})');

      // 如果是自动切换到SQLite，显示提示
      if (dbProvider.isAutoSwitchedToSQLite) {
        AppLogger.info('⚠️ MySQL连接失败，已自动切换到SQLite');
      }

      AppLogger.info('🔄 等待 UserProvider 初始化...');

      // 第二步：等待 UserProvider 初始化
      if (!userProvider.initialized ||
          userProvider.dataSourceType != dbProvider.dbType) {
        try {
          await userProvider.initializeFromDatabase(dbProvider);
        } catch (e) {
          AppLogger.info('❌ UserProvider 初始化失败: $e');
          if (context.mounted) {
            onInitializationComplete(false);
            MessageToastHelper.showError(
              context,
              'UserProvider初始化失败: ${e.toString()}',
            );
          }
          return false;
        }
      }

      // 等待 UserProvider 完全初始化（最多等待2秒）
      retryCount = 0;
      while ((!userProvider.initialized ||
              userProvider.dataSourceType != dbProvider.dbType) &&
          retryCount < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }

      if (!userProvider.initialized ||
          userProvider.dataSourceType != dbProvider.dbType) {
        AppLogger.info('❌ UserProvider 初始化超时');
        if (context.mounted) {
          onInitializationComplete(false);
          MessageToastHelper.showError(context, 'UserProvider初始化超时，请重启应用');
        }
        return false;
      }

      AppLogger.info('✅ UserProvider 初始化完成');
      AppLogger.info('✅ 系统初始化完成，可以登录');

      if (context.mounted) {
        onInitializationComplete(true);
      }
      return true;
    } catch (e) {
      AppLogger.info('❌ 等待初始化失败: $e');
      if (context.mounted) {
        onInitializationComplete(false);
        MessageToastHelper.showError(context, '初始化失败: ${e.toString()}');
      }
      return false;
    }
  }
}
