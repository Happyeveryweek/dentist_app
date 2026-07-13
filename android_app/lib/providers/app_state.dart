import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../utils/app_logger.dart';

// 全局应用状态管理类
class AppState extends ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 登录状态管理
  bool _isLoggedIn = false;
  User? _currentUser;

  bool get isLoggedIn => _isLoggedIn;
  User? get currentUser => _currentUser;

  // 设置登录状态
  void setLoggedIn(bool value) {
    _isLoggedIn = value;
    notifyListeners();
  }

  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
    _isLoggedIn = true;
    notifyListeners();
  }

  // 清除用户信息并登出
  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // 强制重建整个应用
  void forceRefresh() {
    AppLogger.info('强制刷新整个应用');
    notifyListeners();
  }

  // 重置当前页面并导航到首页
  void resetToHome() {
    AppLogger.info('重置到首页');
    // 回到根页面
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  // 重置应用状态 - 用于数据库恢复后
  void resetState() {
    AppLogger.info('重置应用状态');
    notifyListeners();
    resetToHome();
  }

  // 退出应用方法 - 用于重启应用
  void exitApp() {
    AppLogger.info('退出应用以便重启');
    // 使用平台通道退出应用
    SystemNavigator.pop();
  }
}
