import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
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
        _buildSectionHeader(
            '备份数据源设置', Icons.backup_rounded, AppTheme.accentColor),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBackupDataSourceConfiguration(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
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

  Widget _buildBackupDataSourceConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.backup_rounded,
                color: AppTheme.accentColor,
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
            const Spacer(),
            if (!isBackupDataSourceEditing) ...[
              ElevatedButton.icon(
                onPressed: onSetBackupDataSourceEditing,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('编辑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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
                  foregroundColor: Colors.grey.shade600,
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
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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
        _buildCompactBackupDataSourceContent(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '备份数据源设置决定了备份管理功能将备份哪个数据源的数据',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
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

  Widget _buildCompactBackupDataSourceContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildCompactBackupDataSourceSelection(),
          const SizedBox(height: 16),
          _buildCompactBackupDataSourceInfo(),
        ],
      ),
    );
  }

  Widget _buildCompactBackupDataSourceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.radio_button_checked_rounded,
              size: 16,
              color: AppTheme.accentColor,
            ),
            SizedBox(width: 8),
            Text(
              '选择备份数据源',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCompactBackupDataSourceOption(
                'sqlite',
                'SQLite 本地数据库',
                Icons.storage_rounded,
                Colors.blue,
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
                'mysql',
                'MySQL 远程数据库',
                Icons.cloud_done_rounded,
                Colors.green,
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
    String value,
    String title,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
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
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? color : Colors.grey.shade700,
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
                child: const Text(
                  '已选择',
                  style: TextStyle(
                    color: Colors.white,
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

  Widget _buildCompactBackupDataSourceInfo() {
    if (backupDataSource == 'sqlite') {
      return _buildCompactSQLiteBackupInfo();
    } else {
      return _buildCompactMySQLBackupInfo();
    }
  }

  Widget _buildCompactSQLiteBackupInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
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
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'SQLite 备份信息',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份类型',
            '数据库文件复制',
            Icons.file_copy_rounded,
            Colors.blue,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份位置',
            sqliteDbPath.isEmpty ? '默认数据库位置' : sqliteDbPath,
            Icons.folder_rounded,
            Colors.green,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份格式',
            '.db 文件',
            Icons.description_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMySQLBackupInfo() {
    final hasMySQLConfig = hostController.text.isNotEmpty &&
        databaseController.text.isNotEmpty &&
        hostController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasMySQLConfig
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasMySQLConfig
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
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
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'MySQL 备份信息',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: hasMySQLConfig
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份类型',
            'SQL导出备份',
            Icons.code_rounded,
            Colors.green,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份位置',
            hasMySQLConfig
                ? '${hostController.text}:${portController.text}/${databaseController.text}'
                : 'MySQL配置不完整',
            Icons.cloud_rounded,
            hasMySQLConfig ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 4),
          DataSourceFormWidgets.buildCompactBackupInfoItem(
            '备份格式',
            '.sql 文件',
            Icons.description_rounded,
            Colors.blue,
          ),
          if (!hasMySQLConfig) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MySQL配置不完整，无法执行备份操作',
                      style: TextStyle(
                        color: Colors.orange.shade700,
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
