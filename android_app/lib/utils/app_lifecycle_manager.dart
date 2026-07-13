import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/database_provider.dart';
import './app_logger.dart';

/// 应用生命周期管理器
/// 处理应用前后台切换时的数据库连接管理
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  DateTime? _lastPausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.paused:
        _handleAppPaused(dbProvider);
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed(dbProvider);
        break;
      case AppLifecycleState.detached:
        _handleAppDetached(dbProvider);
        break;
      case AppLifecycleState.inactive:
        // 应用变为非活跃状态（如接电话、通知栏下拉等）
        AppLogger.info('📱 应用变为非活跃状态');
        break;
      case AppLifecycleState.hidden:
        // 应用被隐藏
        AppLogger.info('📱 应用被隐藏');
        break;
    }
  }

  /// 处理应用进入后台
  void _handleAppPaused(DatabaseProvider dbProvider) {
    AppLogger.info('📱 应用进入后台，记录时间并准备连接管理');
    _lastPausedTime = DateTime.now();

    // 只对MySQL连接进行后台管理，SQLite不需要
    if (dbProvider.dbType == 'mysql') {
      AppLogger.info('🔄 MySQL模式：暂停后台健康检查');
      dbProvider.pauseMySqlHealthMonitoring();
    } else {
      AppLogger.info('📱 SQLite模式：无需后台连接管理');
    }
  }

  /// 处理应用恢复到前台
  void _handleAppResumed(DatabaseProvider dbProvider) {
    AppLogger.info('📱 应用恢复到前台');

    if (_lastPausedTime != null) {
      final backgroundDuration = DateTime.now().difference(_lastPausedTime!);
      AppLogger.info('📱 应用在后台运行了 ${backgroundDuration.inSeconds} 秒');

      // 只对MySQL连接进行恢复检查
      if (dbProvider.dbType == 'mysql') {
        // 如果在后台超过60秒，强制重连
        if (backgroundDuration.inSeconds > 60) {
          AppLogger.info('🔄 MySQL模式：长时间后台返回，执行强制重连');
          _handleLongBackgroundReturn(dbProvider);
        } else if (backgroundDuration.inSeconds > 10) {
          AppLogger.info('🔄 MySQL模式：中等时间后台返回，执行连接检查');
          _handleMediumBackgroundReturn(dbProvider);
        } else {
          AppLogger.info('🔄 MySQL模式：短时间后台返回，执行快速连接检查');
          _handleShortBackgroundReturn(dbProvider);
        }
      } else {
        AppLogger.info('📱 SQLite模式：无需连接恢复检查');
      }
    }

    _lastPausedTime = null;
  }

  /// 处理应用被完全关闭
  void _handleAppDetached(DatabaseProvider dbProvider) {
    AppLogger.info('📱 应用被完全关闭，清理资源');
    dbProvider.closeDatabase();
  }

  /// 处理长时间后台返回
  void _handleLongBackgroundReturn(DatabaseProvider dbProvider) {
    // 只处理MySQL连接
    if (dbProvider.dbType != 'mysql') return;

    AppLogger.info('🔄 MySQL长时间后台返回，强制重新建立连接');

    unawaited(_restoreMySqlConnection(dbProvider));
  }

  /// 处理中等时间后台返回
  void _handleMediumBackgroundReturn(DatabaseProvider dbProvider) {
    // 只处理MySQL连接
    if (dbProvider.dbType != 'mysql') return;

    AppLogger.info('🔄 MySQL中等时间后台返回，执行连接检查和可能的重连');

    unawaited(_restoreMySqlConnection(dbProvider));
  }

  /// 处理短时间后台返回
  void _handleShortBackgroundReturn(DatabaseProvider dbProvider) {
    // 只处理MySQL连接
    if (dbProvider.dbType != 'mysql') return;

    AppLogger.info('🔄 MySQL短时间后台返回，强制重新建立连接');

    unawaited(_restoreMySqlConnection(dbProvider));
  }

  /// 前台恢复只通过这一条链路重建 MySQL 连接。
  Future<void> _restoreMySqlConnection(DatabaseProvider dbProvider) async {
    try {
      final isConnected = await dbProvider.checkConnectionOnAppResume();
      if (isConnected) {
        AppLogger.info('✅ MySQL应用恢复重连成功');
      } else {
        AppLogger.info('❌ MySQL应用恢复重连失败，将在用户操作时自动重连');
      }
    } catch (e) {
      AppLogger.info('❌ MySQL应用恢复时重连失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
