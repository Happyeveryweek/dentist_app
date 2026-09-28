import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

// 全局应用状态管理类
class AppState extends ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 退出应用方法 - 用于重启应用
  void exitApp() {
    AppLogger.info('退出应用以便重启');
    // 使用平台通道退出应用
    SystemNavigator.pop();
  }
}
