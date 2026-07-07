import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../utils/datetime_formatter.dart';
import 'database_check_widgets.dart';

/// 数据库结构检测结果对话框
/// 显示数据库结构检测的详细结果
class StructureCheckResultDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const StructureCheckResultDialog({
    Key? key,
    required this.result,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final state = _buildDisplayState(tokens);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            state.icon,
            color: state.color,
          ),
          const SizedBox(width: 8),
          const Text('数据库结构检测结果'),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 检测状态卡片
              _buildStatusCard(tokens, colors, state),

              const SizedBox(height: 20),

              // 检测统计
              _buildStatisticsSection(tokens),

              const SizedBox(height: 20),

              // 表检测汇总
              DatabaseCheckWidgets.buildTableSummary(result),

              const SizedBox(height: 20),

              // 详细变化信息和检测日志
              DatabaseCheckWidgets.buildDetailedChanges(result),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  _StructureCheckDisplayState _buildDisplayState(AppThemeTokens tokens) {
    final errors =
        (result['errors'] as List?)?.cast<String>() ?? const <String>[];
    final missingTables = (result['missingTables'] as int?) ?? 0;
    final structureChanges =
        DatabaseCheckWidgets.getActionableStructureChangeCount(result);

    final hasStructuralIssues = missingTables > 0 || structureChanges > 0;
    final hasWarnings = !hasStructuralIssues && errors.isNotEmpty;

    if (!hasStructuralIssues && !hasWarnings) {
      return _StructureCheckDisplayState(
        color: tokens.success,
        containerColor: tokens.successContainer,
        icon: Icons.check_circle,
        title: '数据库结构完整',
        hasStructuralIssues: false,
        hasWarnings: false,
      );
    }

    if (hasWarnings) {
      return _StructureCheckDisplayState(
        color: tokens.warning,
        containerColor: tokens.warningContainer,
        icon: Icons.info,
        title: '检测完成，存在警告',
        hasStructuralIssues: false,
        hasWarnings: true,
      );
    }

    return _StructureCheckDisplayState(
      color: errors.isNotEmpty ? tokens.error : tokens.warning,
      containerColor:
          errors.isNotEmpty ? tokens.errorContainer : tokens.warningContainer,
      icon: errors.isNotEmpty ? Icons.error : Icons.info,
      title: errors.isNotEmpty ? '检测发现问题' : '检测到结构变更',
      hasStructuralIssues: true,
      hasWarnings: false,
    );
  }

  Widget _buildStatusCard(
    AppThemeTokens tokens,
    ColorScheme colors,
    _StructureCheckDisplayState state,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: state.containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            state.icon,
            size: 56,
            color: state.color,
          ),
          const SizedBox(height: 16),
          Text(
            state.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: state.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(result['dataSourceType']?.toString() ?? '').toUpperCase()} 数据库',
            style: TextStyle(
              fontSize: 16,
              color: state.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '检测时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTimeFormatter.fromDbString(result['detectionTime']))}',
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(AppThemeTokens tokens) {
    final actionableChanges =
        DatabaseCheckWidgets.getActionableStructureChangeCount(result);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.infoContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.info),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 24, color: tokens.primaryAccent),
              const SizedBox(width: 12),
              Text(
                '检测统计',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: tokens.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DatabaseCheckWidgets.buildStatCard(
                  '系统表',
                  '${result['requiredTables']}',
                  Icons.table_chart,
                  tokens.primaryAccent,
                  '个必需表',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DatabaseCheckWidgets.buildStatCard(
                  '缺失表',
                  '${result['missingTables']}',
                  Icons.table_rows_outlined,
                  tokens.warning,
                  '个缺失',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DatabaseCheckWidgets.buildStatCard(
                  '结构变化',
                  '$actionableChanges',
                  Icons.update,
                  tokens.success,
                  '项更新',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 显示对话框
  static Future<void> show(BuildContext context, Map<String, dynamic> result) {
    return showDialog(
      context: context,
      builder: (context) => StructureCheckResultDialog(result: result),
    );
  }
}

class _StructureCheckDisplayState {
  final Color color;
  final Color containerColor;
  final IconData icon;
  final String title;
  final bool hasStructuralIssues;
  final bool hasWarnings;

  const _StructureCheckDisplayState({
    required this.color,
    required this.containerColor,
    required this.icon,
    required this.title,
    required this.hasStructuralIssues,
    required this.hasWarnings,
  });
}
