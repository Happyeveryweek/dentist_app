import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 数据源配置页面标题组件
/// 包含页面标题和数据源状态显示
class DataSourcePageHeader extends StatelessWidget {
  final String dataSourceMode;
  final String selectedDataSource;
  final Map<String, String> moduleDataSources;
  final String Function(String) getModuleDisplayName;

  const DataSourcePageHeader({
    Key? key,
    required this.dataSourceMode,
    required this.selectedDataSource,
    required this.moduleDataSources,
    required this.getModuleDisplayName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '数据源配置中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '配置SQLite本地数据库或MySQL远程数据库连接',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: _buildDataSourceStatusDisplay(),
          ),
        ],
      ),
    );
  }

  /// 构建数据源状态显示
  Widget _buildDataSourceStatusDisplay() {
    if (dataSourceMode == 'global') {
      // 全局配置模式
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selectedDataSource == 'sqlite'
                ? Icons.storage_rounded
                : Icons.cloud_done_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '全局配置',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                selectedDataSource == 'sqlite' ? 'SQLite' : 'MySQL',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
              Text(
                '所有模块使用相同数据源',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // 模块化配置模式
      // 统计各数据源的模块数量
      final sqliteModules =
          moduleDataSources.values.where((ds) => ds == 'sqlite').length;
      final mysqlModules =
          moduleDataSources.values.where((ds) => ds == 'mysql').length;

      // 获取具体的模块名称
      final sqliteModuleNames = moduleDataSources.entries
          .where((entry) => entry.value == 'sqlite')
          .map((entry) => getModuleDisplayName(entry.key))
          .toList();
      final mysqlModuleNames = moduleDataSources.entries
          .where((entry) => entry.value == 'mysql')
          .map((entry) => getModuleDisplayName(entry.key))
          .toList();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.grid_view_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '模块化配置',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (sqliteModules > 0)
                Text(
                  'SQLite: ${sqliteModuleNames.join(', ')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (mysqlModules > 0)
                Text(
                  'MySQL: ${mysqlModuleNames.join(', ')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      );
    }
  }
}
