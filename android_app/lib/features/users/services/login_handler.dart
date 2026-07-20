import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../utils/message_toast_helper.dart';
import '../../../widgets/loading_dialog.dart';
import 'login_credentials_service.dart';

/// 登录处理服务
class LoginHandler {
  /// 处理登录
  static Future<void> handleLogin(
    BuildContext context,
    String username,
    String password,
    bool rememberPassword,
  ) async {
    if (username.isEmpty || password.isEmpty) {
      MessageToastHelper.showError(context, '请输入用户名和密码');
      return;
    }

    // 显示加载提示
    LoadingDialog.show(context, message: '正在登录...');

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 再次确认数据库已初始化
      if (!dbProvider.isInitialized) {
        if (context.mounted) LoadingDialog.hide(context);
        MessageToastHelper.showError(context, '数据库未初始化，请重启应用');
        return;
      }

      // 登录前确保用户认证服务已绑定到当前运行时数据源。
      await userProvider.initializeFromDatabase(dbProvider);
      if (!userProvider.initialized ||
          userProvider.dataSourceType != dbProvider.dbType) {
        if (context.mounted) {
          LoadingDialog.hide(context);
          MessageToastHelper.showError(context, '本地数据库切换失败，请重启应用');
        }
        return;
      }

      final user = await userProvider.authenticateUser(username, password);

      // 隐藏加载提示
      if (context.mounted) LoadingDialog.hide(context);

      if (user != null) {
        // 保存登录信息
        await LoginCredentialsService.saveCredentials(
          username,
          password,
          rememberPassword,
        );

        if (context.mounted) {
          MessageToastHelper.showSuccess(context, '登录成功！欢迎回来，${user.username}');
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // 登录失败
        if (context.mounted) {
          MessageToastHelper.showError(context, '用户名或密码错误');
        }
      }
    } catch (e) {
      // 隐藏加载提示
      if (context.mounted) LoadingDialog.hide(context);

      if (context.mounted) {
        // 检查是否是数据库连接错误
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('连接') ||
            errorMessage.contains('connection') ||
            errorMessage.contains('socketexception') ||
            errorMessage.contains('无法连接') ||
            errorMessage.contains('timeout')) {
          throw LoginDatabaseException();
        } else {
          MessageToastHelper.showError(context, '登录失败: ${e.toString()}');
        }
      }
    }
  }
}

/// 登录数据库异常
class LoginDatabaseException implements Exception {
  final String message;

  LoginDatabaseException([this.message = '数据库连接错误']);

  @override
  String toString() => message;
}
