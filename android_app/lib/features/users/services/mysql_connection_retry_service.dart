import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/database_provider.dart';
import '../../../utils/message_toast_helper.dart';
import '../../../widgets/loading_dialog.dart';

/// MySQL 连接重试服务
class MySQLConnectionRetryService {
  /// 重试 MySQL 连接
  static Future<void> retry(BuildContext context) async {
    LoadingDialog.show(context, message: '正在重试MySQL连接...');

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      await dbProvider.initDatabase();

      if (context.mounted) {
        LoadingDialog.hide(context);

        if (dbProvider.isConnected) {
          MessageToastHelper.showSuccess(context, 'MySQL连接成功！');
        } else {
          MessageToastHelper.showWarning(context, 'MySQL连接失败，请检查配置');
        }
      }
    } catch (e) {
      if (context.mounted) {
        LoadingDialog.hide(context);
        MessageToastHelper.showError(context, '重试MySQL连接失败: ${e.toString()}');
      }
    }
  }
}
