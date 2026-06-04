import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/database_config.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/message_toast_helper.dart';
import '../../../widgets/loading_dialog.dart';

/// SQLite 切换服务
class SQLiteDatabaseSwitchService {
  /// 切换到 SQLite 数据库
  static Future<void> switchToSQLite(BuildContext context) async {
    LoadingDialog.show(context, message: '正在切换到SQLite...');

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final dbConfig = await DatabaseConfig.loadConfig();
      dbConfig.dbType = 'sqlite';
      await dbConfig.saveConfig();

      await dbProvider.initDatabase();
      await userProvider.initializeFromDatabase(dbProvider);

      if (context.mounted) {
        LoadingDialog.hide(context);
        MessageToastHelper.showSuccess(context, '已成功切换到SQLite数据库');
      }
    } catch (e) {
      if (context.mounted) {
        LoadingDialog.hide(context);
        MessageToastHelper.showError(context, '切换到SQLite失败: ${e.toString()}');
      }
    }
  }
}
