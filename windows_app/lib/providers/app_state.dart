import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  // 全局导航键
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 应用刷新计数器
  int _refreshCounter = 0;
  int get refreshCounter => _refreshCounter;

  // 强制整个应用重建
  void forceAppRebuild() {
    _refreshCounter++;
    notifyListeners();
  }

  // 显示全局消息
  void showMessage(String message, {bool isError = false}) {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: isError ? 5 : 3),
        ),
      );
    }
  }

  // 显示加载指示器
  Future<T?> showLoading<T>(Future<T> future, {String? message}) async {
    if (navigatorKey.currentContext == null) {
      return await future;
    }

    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(message ?? '加载中...'),
              ],
            ),
          ),
    );

    try {
      final result = await future;
      if (navigatorKey.currentState?.mounted ?? false) {
        navigatorKey.currentState?.pop();
      }
      return result;
    } catch (e) {
      if (navigatorKey.currentState?.mounted ?? false) {
        navigatorKey.currentState?.pop();
      }
      showMessage('操作失败: $e', isError: true);
      rethrow;
    }
  }

  // Windows特定状态 - 窗口状态
  bool _isMaximized = false;
  bool get isMaximized => _isMaximized;
  set isMaximized(bool value) {
    if (_isMaximized != value) {
      _isMaximized = value;
      notifyListeners();
    }
  }

  // 当前活动页面索引
  int _activePageIndex = 0;
  int get activePageIndex => _activePageIndex;
  set activePageIndex(int value) {
    if (_activePageIndex != value) {
      _activePageIndex = value;
      notifyListeners();
    }
  }
}
