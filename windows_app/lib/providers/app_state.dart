import 'package:flutter/material.dart';
import '../theme/theme_context_extensions.dart';
import '../utils/log_manager.dart';

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
    final context = navigatorKey.currentContext;
    if (context != null) {
      final tokens = context.tokens;
      final colors = context.colors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: colors.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? tokens.error : tokens.success,
          duration: Duration(seconds: isError ? 4 : 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
    }
  }

  // 显示加载指示器
  Future<T?> showLoading<T>(Future<T> future, {String? message}) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return await future;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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

  // MySQL连接状态管理
  bool _isMySQLConnected = false;
  bool get isMySQLConnected => _isMySQLConnected;

  // MySQL连接失败标志（用于区分主动选择SQLite和MySQL失败降级）
  bool _isMySQLConnectionFailed = false;
  bool get isMySQLConnectionFailed => _isMySQLConnectionFailed;

  // 受影响的MySQL模块列表
  List<String> _affectedMySQLModules = [];
  List<String> get affectedMySQLModules => _affectedMySQLModules;

  // 模块名称映射（英文 -> 中文）
  static const Map<String, String> _moduleNameMap = {
    'financial': '财务管理',
    'materials': '材料管理',
    'purchase': '采购管理',
    'users': '用户管理',
    'appointments': '预约管理',
    'patients': '患者管理',
    'medical': '病历管理',
  };

  // 获取中文模块名称列表
  List<String> getAffectedModulesInChinese() {
    return _affectedMySQLModules
        .map((module) => _moduleNameMap[module] ?? module)
        .toList();
  }

  // 设置MySQL连接状态
  void setMySQLConnectionStatus(
    bool isConnected, {
    List<String>? affectedModules,
    bool isFailure = false, // 新增参数：是否是连接失败
  }) {
    _isMySQLConnected = isConnected;
    _isMySQLConnectionFailed = isFailure;
    _affectedMySQLModules = affectedModules ?? [];
    notifyListeners();
    LogManager.e('AppState',
        'AppState: MySQL连接状态已更新 - 已连接: $_isMySQLConnected, 连接失败: $_isMySQLConnectionFailed, 受影响模块: $_affectedMySQLModules');
  }
}
