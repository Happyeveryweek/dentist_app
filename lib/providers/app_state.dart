import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 全局应用状态管理类
class AppState extends ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  int _refreshCounter = 0;

  int get refreshCounter => _refreshCounter;

  // 强制重建整个应用
  void forceRefresh() {
    print('强制刷新整个应用');
    _refreshCounter++;
    notifyListeners();
  }

  // 重置当前页面并导航到首页
  void resetToHome() {
    print('重置到首页');
    // 回到根页面
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  // 重置应用状态 - 用于数据库恢复后
  void resetState() {
    print('重置应用状态');
    _refreshCounter++;
    notifyListeners();
    resetToHome();
  }

  // 退出应用方法 - 用于重启应用
  void exitApp() {
    print('退出应用以便重启');
    // 使用平台通道退出应用
    SystemNavigator.pop();
  }
}
