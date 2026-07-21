import 'package:flutter/material.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../widgets/clickable.dart';
import 'data_source_form_widgets.dart';

/// 备份数据源设置区域组件
/// 包含备份数据源选择和信息显示
class BackupDataSourceSection extends StatelessWidget {
  final String backupDataSource;
  final bool isBackupDataSourceEditing;
  final String sqliteDbPath;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController databaseController;
  final VoidCallback onCancelBackupDataSourceChanges;
  final VoidCallback onSaveBackupDataSourceSettingsOnly;
  final VoidCallback onSetBackupDataSourceEditing;
  final Function(String) onSetBackupDataSource;

  const BackupDataSourceSection({
    Key? key,
    required this.backupDataSource,
    required this.isBackupDataSourceEditing,
    required this.sqliteDbPath,
    required this.hostController,
    required this.portController,
    required this.databaseController,
    required this.onCancelBackupDataSourceChanges,
    required this.onSaveBackupDataSourceSettingsOnly,
    required this.onSetBackupDataSourceEditing,
    required this.onSetBackupDataSource,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, '备份数据源设置', Icons.backup_rounded,
            context.tokens.secondaryAccent),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isBackupDataSourceEditing
                ? context.tokens.secondaryAccent.withValues(alpha: 0.06)
                : context.tokens.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBackupDataSourceEditing
                  ? context.tokens.secondaryAccent.withValues(alpha: 0.65)
                  : Colors.transparent,
              width: isBackupDataSourceEditing ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.tokens.shadow.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBackupDataSourceConfiguration(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupDataSourceConfiguration(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tokens.secondaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.backup_rounded,
                color: context.tokens.secondaryAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '备份数据源设置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isBackupDataSourceEditing) ...[
              const SizedBox(width: 12),
              DataSourceFormWidgets.buildEditingBadge(
                context,
                color: context.tokens.secondaryAccent,
              ),
            ],
            const Spacer(),
            if (!isBackupDataSourceEditing) ...[
              ElevatedButton.icon(
                onPressed: onSetBackupDataSourceEditing,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('编辑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.tokens.primaryAccent,
                  foregroundColor: context.tokens.cardBackground,
                  elevation: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: onCancelBackupDataSourceChanges,
                icon: const Icon(Icons.close_rounded),
                label: const Text('取消'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.onSurfaceVariant,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onSaveBackupDataSourceSettingsOnly,
                icon: const Icon(Icons.save_rounded),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.tokens.primaryAccent,
                  foregroundColor: context.tokens.cardBackground,
                  elevation: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildCompactBackupDataSourceContent(context),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.tokens.primaryAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: context.tokens.primaryAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: context.tokens.primaryAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '备份数据源设置决定了备份管理功能将备份哪个数据源的数据',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.tokens.primaryAccent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBackupDataSourceContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.secondaryAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.secondaryAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildCompactBackupDataSourceSelection(context),
          const SizedBox(height: 16),
          _buildCompactBackupDataSourceInfo(context),
        ],
      ),
    );
  }

  Widget _buildCompactBackupDataSourceSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.radio_button_checked_rounded,
              size: 16,
              color: context.tokens.secondaryAccent,
            ),
            const SizedBox(width: 8),
            Text(
              '选择备份数据源',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: context.tokens.secondaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCompactBackupDataSourceOption(
                context,
                'sqlite',
                'SQLite 本地数据库',
                Icons.storage_rounded,
                context.tokens.primaryAccent,
                backupDataSource == 'sqlite',
                isBackupDataSourceEditing
                    ? () {
                        onSetBackupDataSource('sqlite');
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactBackupDataSourceOption(
                context,
                'mysql',
                'MySQL 远程数据库',
                Icons.cloud_done_rounded,
                context.tokens.success,
                backupDataSource == 'mysql',
                isBackupDataSourceEditing
                    ? () {
                        onSetBackupDataSource('mysql');
                      }
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactBackupDataSourceOption(
    BuildContext context,
    String value,
    String title,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback? onTap,
  ) {
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : context.tokens.mutedBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : context.tokens.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : context.tokens.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : context.colors.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? color : context.colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '已选择',
                  style: TextStyle(
                    color: context.tokens.cardBackground,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBackupDataSourceInfo(BuildContext context) {
    if (backupDataSource == 'sqlite') {
      return _buildCompactSQLiteBackupInfo(context);
    } else {
      return _buildCompactMySQLBackupInfo(context);
    }
  }

  Widget _buildCompactSQLiteBackupInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.primaryAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.tokens.primaryAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_rounded,
                color: context.tokens.primaryAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'SQLite 备份信息',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: context.tokens.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份类型',
            '数据库文件复制',
            Icons.file_copy_rounded,
            context.tokens.primaryAccent,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份位置',
            sqliteDbPath.isEmpty ? '默认数据库位置' : sqliteDbPath,
            Icons.folder_rounded,
            context.tokens.success,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份格式',
            '.db 文件',
            Icons.description_rounded,
            context.tokens.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMySQLBackupInfo(BuildContext context) {
    final hasMySQLConfig = hostController.text.isNotEmpty &&
        databaseController.text.isNotEmpty &&
        hostController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasMySQLConfig
            ? context.tokens.success.withValues(alpha: 0.05)
            : context.tokens.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasMySQLConfig
              ? context.tokens.success.withValues(alpha: 0.2)
              : context.tokens.warning.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasMySQLConfig
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                color: hasMySQLConfig
                    ? context.tokens.success
                    : context.tokens.warning,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'MySQL 备份信息',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: hasMySQLConfig
                      ? context.tokens.success
                      : context.tokens.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份类型',
            'SQL导出备份',
            Icons.code_rounded,
            context.tokens.success,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份位置',
            hasMySQLConfig
                ? '${hostController.text}:${portController.text}/${databaseController.text}'
                : 'MySQL配置不完整',
            Icons.cloud_rounded,
            hasMySQLConfig ? context.tokens.success : context.tokens.warning,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份格式',
            '.sql 文件',
            Icons.description_rounded,
            context.tokens.primaryAccent,
          ),
          if (!hasMySQLConfig) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tokens.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: context.tokens.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.tokens.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MySQL配置不完整，无法执行备份操作',
                      style: TextStyle(
                        color: context.tokens.warning,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
