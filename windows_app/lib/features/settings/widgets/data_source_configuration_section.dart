import 'package:flutter/material.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../config/app_defaults.dart';
import 'data_source_form_widgets.dart';

/// 数据源配置区域组件
/// 包含 SQLite 和 MySQL 配置
class DataSourceConfigurationSection extends StatelessWidget {
  final String sqliteDbPath;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController databaseController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool isSqliteEditing;
  final bool isEditing;
  final bool connectionTested;
  final bool connectionSuccess;
  final bool isTestingConnection;
  final VoidCallback onSelectSqliteDatabase;
  final VoidCallback onTestMySQLConnection;
  final VoidCallback onSaveSqliteSettings;
  final VoidCallback onSaveMySQLSettings;
  final VoidCallback onSetSqliteEditing;
  final VoidCallback onSetEditing;
  final VoidCallback onCancelSqliteEdit;
  final VoidCallback onCancelMySQLEdit;
  final GlobalKey<FormState> formKey;

  const DataSourceConfigurationSection({
    Key? key,
    required this.sqliteDbPath,
    required this.hostController,
    required this.portController,
    required this.databaseController,
    required this.usernameController,
    required this.passwordController,
    required this.isSqliteEditing,
    required this.isEditing,
    required this.connectionTested,
    required this.connectionSuccess,
    required this.isTestingConnection,
    required this.onSelectSqliteDatabase,
    required this.onTestMySQLConnection,
    required this.onSaveSqliteSettings,
    required this.onSaveMySQLSettings,
    required this.onSetSqliteEditing,
    required this.onSetEditing,
    required this.onCancelSqliteEdit,
    required this.onCancelMySQLEdit,
    required this.formKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            '数据源配置', Icons.settings_rounded, context.tokens.primaryAccent),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: context.tokens.cardBackground,
            borderRadius: BorderRadius.circular(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSqliteConfiguration(context),
                const Divider(height: 32, thickness: 1),
                _buildMySQLConfiguration(context),
              ],
            ),
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

  Widget _buildSqliteConfiguration(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.storage_rounded,
                color: context.tokens.primaryAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'SQLite 配置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isSqliteEditing) ...[
              const SizedBox(width: 12),
              DataSourceFormWidgets.buildEditingBadge(context),
            ],
            const Spacer(),
            if (!isSqliteEditing) ...[
              ElevatedButton.icon(
                onPressed: onSetSqliteEditing,
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
                onPressed: onCancelSqliteEdit,
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
                onPressed: onSaveSqliteSettings,
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.primaryAccent
                .withValues(alpha: isSqliteEditing ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.tokens.primaryAccent
                  .withValues(alpha: isSqliteEditing ? 0.65 : 0.2),
              width: isSqliteEditing ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sqliteDbPath.isEmpty ? '使用默认数据库文件' : '已选择数据库文件',
                              style: TextStyle(
                                color: sqliteDbPath.isEmpty
                                    ? context.colors.onSurfaceVariant
                                    : context.tokens.success,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (sqliteDbPath.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.tokens.successContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.tokens.success
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: context.tokens.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '已配置',
                                      style: TextStyle(
                                        color: context.tokens.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: sqliteDbPath.isNotEmpty
                              ? BoxDecoration(
                                  color: context.tokens.success
                                      .withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: context.tokens.success
                                        .withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                )
                              : null,
                          child: Text(
                            sqliteDbPath.isEmpty
                                ? '系统将使用默认位置的数据库文件'
                                : sqliteDbPath,
                            style: TextStyle(
                              color: sqliteDbPath.isEmpty
                                  ? context.tokens.textMuted
                                  : context.tokens.success,
                              fontSize: 12,
                              fontWeight: sqliteDbPath.isNotEmpty
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (isSqliteEditing)
                    ElevatedButton.icon(
                      onPressed: onSelectSqliteDatabase,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('选择文件'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.tokens.primaryAccent,
                        foregroundColor: context.tokens.cardBackground,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: context.tokens.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '如不选择，将使用默认位置的数据库文件',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokens.warning,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMySQLConfiguration(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.tokens.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.cloud_done_rounded,
                color: context.tokens.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'MySQL 配置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isEditing) ...[
              const SizedBox(width: 12),
              DataSourceFormWidgets.buildEditingBadge(context),
            ],
            const Spacer(),
            if (!isEditing) ...[
              ElevatedButton.icon(
                onPressed: onSetEditing,
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
                onPressed: onCancelMySQLEdit,
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
                onPressed: onSaveMySQLSettings,
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
        const SizedBox(height: 16),
        if (!isEditing) ...[
          _buildMySQLReadOnlyMode(context),
        ] else ...[
          _buildMySQLEditMode(context),
        ],
      ],
    );
  }

  Widget _buildMySQLReadOnlyMode(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.success.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DataSourceFormWidgets.buildCompactSettingItem(
                  icon: Icons.computer_rounded,
                  title: '主机地址',
                  value:
                      hostController.text.isEmpty ? '未设置' : hostController.text,
                  iconColor: context.tokens.primaryAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DataSourceFormWidgets.buildCompactSettingItem(
                  icon: Icons.settings_ethernet_rounded,
                  title: '端口',
                  value:
                      portController.text.isEmpty ? '未设置' : portController.text,
                  iconColor: context.tokens.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DataSourceFormWidgets.buildCompactSettingItem(
                  icon: Icons.account_tree_rounded,
                  title: '数据库名称',
                  value: databaseController.text.isEmpty
                      ? '未设置'
                      : databaseController.text,
                  iconColor: context.tokens.secondaryAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DataSourceFormWidgets.buildCompactSettingItem(
                  icon: Icons.person_rounded,
                  title: '用户名',
                  value: usernameController.text.isEmpty
                      ? '未设置'
                      : usernameController.text,
                  iconColor: context.tokens.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DataSourceFormWidgets.buildCompactSettingItem(
                  icon: Icons.lock_rounded,
                  title: '密码',
                  value: passwordController.text.isEmpty ? '未设置' : '••••••',
                  iconColor: context.tokens.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.tokens.inputBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.tokens.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '点击上方的"编辑"按钮可以修改MySQL连接配置',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySQLEditMode(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.primaryAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.primaryAccent.withValues(alpha: 0.65),
          width: 2,
        ),
      ),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DataSourceFormWidgets.buildCompactFormField(
                    controller: hostController,
                    labelText: '主机地址',
                    hintText: 'localhost 或 IP地址',
                    icon: Icons.computer_rounded,
                    iconColor: context.tokens.primaryAccent,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入主机地址';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DataSourceFormWidgets.buildCompactFormField(
                    controller: portController,
                    labelText: '端口',
                    hintText: '${MySqlConnectionPolicy.defaultPort}',
                    icon: Icons.settings_ethernet_rounded,
                    iconColor: context.tokens.info,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入端口号';
                      }
                      if (int.tryParse(value) == null) {
                        return '端口号必须是数字';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DataSourceFormWidgets.buildCompactFormField(
                    controller: databaseController,
                    labelText: '数据库名称',
                    hintText: '输入数据库名称',
                    icon: Icons.account_tree_rounded,
                    iconColor: context.tokens.secondaryAccent,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入数据库名称';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DataSourceFormWidgets.buildCompactFormField(
                    controller: usernameController,
                    labelText: '用户名',
                    hintText: '输入数据库用户名',
                    icon: Icons.person_rounded,
                    iconColor: context.tokens.warning,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DataSourceFormWidgets.buildCompactFormField(
                    controller: passwordController,
                    labelText: '密码',
                    hintText: '输入数据库密码',
                    icon: Icons.lock_rounded,
                    iconColor: context.tokens.error,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.tokens.primaryAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.tokens.primaryAccent.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: context.tokens.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '请先测试连接确保配置正确，然后再保存设置',
                      style: TextStyle(
                        color: context.tokens.primaryAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (connectionTested && connectionSuccess)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: context.tokens.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: context.tokens.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: context.tokens.success,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '连接测试成功',
                      style: TextStyle(
                        color: context.tokens.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isTestingConnection ? null : onTestMySQLConnection,
                  icon: isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: const Text('测试连接'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.tokens.primaryAccent,
                    foregroundColor: context.tokens.cardBackground,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
