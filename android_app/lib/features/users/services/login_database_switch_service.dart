import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/database_provider.dart';
import '../../../utils/notification_helper.dart';

/// 登录页数据库切换监听服务
class LoginDatabaseSwitchService {
  static void setupDatabaseSwitchListener(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      void listener() {
        if (context.mounted &&
            dbProvider.databaseChanged &&
            dbProvider.dbType == 'sqlite') {
          dbProvider.removeListener(listener);

          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              NotificationHelper.showDatabaseSwitchDialog(
                context,
                fromType: 'MySQL',
                toType: 'SQLite',
                reason: '无法连接到MySQL服务器',
              );
              dbProvider.resetDatabaseChanged();
            }
          });
        }
      }

      dbProvider.addListener(listener);
    });
  }
}
