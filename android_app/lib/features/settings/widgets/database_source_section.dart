import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// 移动端数据源配置页。
class DatabaseSourceSection extends StatelessWidget {
  final String selectedDbType;
  final bool showMysqlConfig;
  final bool isEditingMysql;
  final bool mysqlTestSuccess;
  final bool isTestingNetwork;
  final bool isTestingMysql;
  final DatabaseConfig dbConfig;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController databaseController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onSwitchToSqlite;
  final VoidCallback onSwitchToMysql;
  final VoidCallback onToggleMysqlEdit;
  final VoidCallback onTestNetwork;
  final VoidCallback onTestConnection;
  final VoidCallback? onSaveMysql;
  final VoidCallback onSelectCustomDbPath;

  const DatabaseSourceSection({
    super.key,
    required this.selectedDbType,
    required this.showMysqlConfig,
    required this.isEditingMysql,
    required this.mysqlTestSuccess,
    required this.isTestingNetwork,
    required this.isTestingMysql,
    required this.dbConfig,
    required this.hostController,
    required this.portController,
    required this.databaseController,
    required this.usernameController,
    required this.passwordController,
    required this.onSwitchToSqlite,
    required this.onSwitchToMysql,
    required this.onToggleMysqlEdit,
    required this.onTestNetwork,
    required this.onTestConnection,
    required this.onSaveMysql,
    required this.onSelectCustomDbPath,
  });

  bool get _isMysql => selectedDbType == 'mysql' && showMysqlConfig;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentSourceCard(),
          const SizedBox(height: 20),
          const Text('选择数据源', style: AppTheme.subtitleStyle),
          const SizedBox(height: 6),
          Text(
            '选择应用读取和写入业务数据的位置',
            style: AppTheme.bodyStyle.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 12),
          _buildSourceSelector(),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                _isMysql
                    ? _buildMysqlSection(key: const ValueKey('mysql'))
                    : _buildSqliteSection(key: const ValueKey('sqlite')),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSourceCard() {
    final currentIsMysql = dbConfig.dbType == 'mysql';
    final icon = currentIsMysql ? Icons.cloud_outlined : Icons.storage_rounded;
    final type = currentIsMysql ? 'MySQL' : 'SQLite';
    final description =
        currentIsMysql
            ? '${dbConfig.mysql.host}:${dbConfig.mysql.port}/${dbConfig.mysql.database}'
            : _sqlitePath;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(type, style: AppTheme.subtitleStyle),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '当前使用',
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyStyle.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.lightText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSourceOption(
              label: 'SQLite',
              icon: Icons.storage_rounded,
              selected: !_isMysql,
              onTap: onSwitchToSqlite,
            ),
          ),
          Expanded(
            child: _buildSourceOption(
              label: 'MySQL',
              icon: Icons.cloud_outlined,
              selected: _isMysql,
              onTap: onSwitchToMysql,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppTheme.cardBackground : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color:
                    selected ? AppTheme.primaryColor : AppTheme.secondaryText,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? AppTheme.primaryColor : AppTheme.secondaryText,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _sqlitePath {
    final value = dbConfig.sqlite.path.trim();
    return value.isEmpty ? '应用默认数据库' : value;
  }

  Widget _buildSqliteSection({required Key key}) {
    return _buildSectionCard(
      key: key,
      title: 'SQLite 配置',
      subtitle: '数据保存在当前设备的数据库文件中',
      icon: Icons.phone_android_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.insert_drive_file_outlined,
            label: '数据库文件',
            value: _sqlitePath,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.secondaryText,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '选择其他数据库文件后，应用将切换到该文件中的数据。',
                    style: AppTheme.bodyStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSelectCustomDbPath,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('更换数据库文件'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMysqlSection({required Key key}) {
    return _buildSectionCard(
      key: key,
      title: 'MySQL 配置',
      subtitle: isEditingMysql ? '填写连接信息，测试成功后保存' : '远程数据库连接信息',
      icon: Icons.dns_outlined,
      trailing:
          isEditingMysql
              ? null
              : TextButton.icon(
                onPressed:
                    isTestingNetwork || isTestingMysql
                        ? null
                        : onToggleMysqlEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑'),
              ),
      child: isEditingMysql ? _buildMysqlForm() : _buildMysqlDetails(),
    );
  }

  Widget _buildSectionCard({
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.lightText.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.subtitleStyle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.captionStyle),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildMysqlDetails() {
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.computer_outlined,
          label: '主机地址',
          value: hostController.text,
        ),
        _buildDivider(),
        _buildInfoRow(
          icon: Icons.settings_ethernet_rounded,
          label: '端口',
          value: portController.text,
        ),
        _buildDivider(),
        _buildInfoRow(
          icon: Icons.storage_outlined,
          label: '数据库',
          value: databaseController.text,
        ),
        _buildDivider(),
        _buildInfoRow(
          icon: Icons.person_outline_rounded,
          label: '用户名',
          value: usernameController.text,
        ),
        _buildDivider(),
        _buildInfoRow(
          icon: Icons.lock_outline_rounded,
          label: '密码',
          value: '••••••••',
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.secondaryText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.captionStyle),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 25,
      indent: 32,
      color: AppTheme.lightText.withValues(alpha: 0.22),
    );
  }

  Widget _buildMysqlForm() {
    return Column(
      children: [
        _buildTextField(
          controller: hostController,
          label: '主机名或 IP 地址',
          hint: '例如：192.168.1.10',
          icon: Icons.computer_outlined,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: portController,
          label: '端口',
          hint: '默认：3306',
          icon: Icons.settings_ethernet_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: databaseController,
          label: '数据库名称',
          hint: '例如：dental_clinic',
          icon: Icons.storage_outlined,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: usernameController,
          label: '用户名',
          hint: '请输入用户名',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: passwordController,
          label: '密码',
          hint: '请输入密码',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isTestingNetwork ? null : onTestNetwork,
                child: _buildButtonContent(
                  loading: isTestingNetwork,
                  icon: Icons.network_check_rounded,
                  label: isTestingNetwork ? '测试中' : '测试网络',
                  loadingColor: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: isTestingMysql ? null : onTestConnection,
                child: _buildButtonContent(
                  loading: isTestingMysql,
                  icon: Icons.link_rounded,
                  label: isTestingMysql ? '测试中' : '测试连接',
                  loadingColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                onSaveMysql == null || isTestingNetwork || isTestingMysql
                    ? null
                    : onSaveMysql,
            icon: const Icon(Icons.save_outlined),
            label: Text(mysqlTestSuccess ? '保存并应用配置' : '测试连接后保存'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed:
              isTestingNetwork || isTestingMysql ? null : onToggleMysqlEdit,
          child: const Text('取消编辑'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildButtonContent({
    required bool loading,
    required IconData icon,
    required String label,
    required Color loadingColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: loadingColor,
            ),
          )
        else
          Icon(icon, size: 18),
        const SizedBox(width: 7),
        Text(label),
      ],
    );
  }
}
