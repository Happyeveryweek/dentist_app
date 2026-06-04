import 'dart:io';

import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/app_paths.dart';

/// 应用重置服务
/// 负责应用数据重置的业务逻辑
class AppResetService {
  final DatabaseProvider _dbProvider;
  final SettingsProvider _settingsProvider;

  AppResetService({
    required DatabaseProvider dbProvider,
    required SettingsProvider settingsProvider,
  })  : _dbProvider = dbProvider,
        _settingsProvider = settingsProvider;

  /// 执行应用数据重置
  /// 
  /// 返回重置结果
  Future<AppResetResult> resetAppData() async {
    try {
      // 1. 关闭数据库连接（但不删除数据库文件）
      await _dbProvider.closeDatabase();
      
      // 2. 清除所有配置（恢复到默认值）
      await _settingsProvider.clearAllSettings();
      
      // 3. 重新初始化配置（加载默认值）
      await _settingsProvider.init();
      
      // 4. 清除缓存目录（但保留数据目录）
      try {
        final cacheDir = Directory(AppPaths.cacheDirectory);
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          await cacheDir.create(recursive: true);
        }
        
        final thumbnailDir = Directory(AppPaths.thumbnailCacheDirectory);
        if (await thumbnailDir.exists()) {
          await thumbnailDir.delete(recursive: true);
          await thumbnailDir.create(recursive: true);
        }
      } catch (e) {
        print('清除缓存目录失败: $e');
      }
      
      return AppResetResult(
        success: true,
        errorMessage: null,
      );
    } catch (e) {
      return AppResetResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// 应用重置结果
class AppResetResult {
  final bool success;
  final String? errorMessage;

  AppResetResult({
    required this.success,
    required this.errorMessage,
  });
}
