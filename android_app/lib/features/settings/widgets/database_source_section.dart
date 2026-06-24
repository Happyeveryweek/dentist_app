import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/database_config.dart';

/// 数据源设置区域组件
/// 负责显示数据库类型选择、MySQL配置、SQLite路径选择等功能
class DatabaseSourceSection extends StatelessWidget {
  final String selectedDbType;
  final bool showMysqlConfig;
  final bool isEditingMysql;
  final bool mysqlTestSuccess;
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择数据源类型',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatabaseTypeOption(
                          title: 'SQLite',
                          subtitle: '本地数据库',
                          icon: Icons.storage,
                          isSelected: selectedDbType == 'sqlite',
                          onTap: onSwitchToSqlite,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDatabaseTypeOption(
                          title: 'MySQL',
                          subtitle: '远程数据库',
                          icon: Icons.cloud,
                          isSelected: selectedDbType == 'mysql',
                          onTap: onSwitchToMysql,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // MySQL配置区域
          if (showMysqlConfig)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MySQL配置',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // 编辑按钮
                              ElevatedButton.icon(
                                onPressed: onToggleMysqlEdit,
                                icon: Icon(
                                  isEditingMysql ? Icons.lock_open : Icons.edit,
                                  size: 16,
                                ),
                                label: Text(isEditingMysql ? '完成编辑' : '编辑配置'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isEditingMysql
                                          ? Colors.green
                                          : AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 根据编辑状态显示不同的UI
                      isEditingMysql
                          ? _buildMySQLEditForm()
                          : _buildMySQLConfigDetails(),
                    ],
                  ),
                ),
              ),
            ),

          // 当前数据库信息
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前数据库信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selectedDbType == 'sqlite')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SQLite数据库配置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 显示当前数据库文件路径
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.folder_open,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '当前数据库路径:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF555555),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    dbConfig.sqlite.path.isNotEmpty
                                        ? dbConfig.sqlite.path
                                        : '未设置数据库路径',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '数据库类型: SQLite 3 (本地文件数据库)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: onSelectCustomDbPath,
                              icon: const Icon(Icons.folder_open, size: 20),
                              label: const Text(
                                '选择自定义数据库路径',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MySQL数据库配置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildConfigItem(
                                  '主机名/IP地址',
                                  dbConfig.mysql.host,
                                  Icons.computer,
                                  Colors.blue,
                                ),
                                const Divider(),
                                _buildConfigItem(
                                  '端口',
                                  dbConfig.mysql.port,
                                  Icons.settings_ethernet,
                                  Colors.orange,
                                ),
                                const Divider(),
                                _buildConfigItem(
                                  '数据库名称',
                                  dbConfig.mysql.database,
                                  Icons.storage,
                                  Colors.green,
                                ),
                                const Divider(),
                                _buildConfigItem(
                                  '用户名',
                                  dbConfig.mysql.username,
                                  Icons.person,
                                  Colors.purple,
                                ),
                                const Divider(),
                                _buildConfigItem(
                                  '密码',
                                  '••••••••',
                                  Icons.lock,
                                  Colors.red,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '数据库类型: MySQL (远程数据库)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : Colors.black,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySQLEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: hostController,
          decoration: const InputDecoration(
            labelText: '主机名/IP地址',
            hintText: '例如: localhost或10.0.2.2',
            prefixIcon: Icon(Icons.computer),
          ),
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: portController,
          decoration: const InputDecoration(
            labelText: '端口',
            hintText: '默认: 3306',
            prefixIcon: Icon(Icons.settings_ethernet),
          ),
          keyboardType: TextInputType.number,
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: databaseController,
          decoration: const InputDecoration(
            labelText: '数据库名称',
            hintText: '例如: dental_clinic',
            prefixIcon: Icon(Icons.storage),
          ),
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '例如: root',
            prefixIcon: Icon(Icons.person),
          ),
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: '密码',
            hintText: '******',
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
          enabled: true,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onTestNetwork,
                icon: const Icon(Icons.network_check, size: 14),
                label: const Text('测网络'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onTestConnection,
                icon: const Icon(Icons.link, size: 14),
                label: const Text('测连接'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSaveMysql,
                icon: const Icon(Icons.save, size: 14),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMySQLConfigDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfigItem(
                '主机名/IP地址',
                hostController.text,
                Icons.computer,
                Colors.blue,
              ),
              const Divider(),
              _buildConfigItem(
                '端口',
                portController.text,
                Icons.settings_ethernet,
                Colors.orange,
              ),
              const Divider(),
              _buildConfigItem(
                '数据库名称',
                databaseController.text,
                Icons.storage,
                Colors.green,
              ),
              const Divider(),
              _buildConfigItem(
                '用户名',
                usernameController.text,
                Icons.person,
                Colors.purple,
              ),
              const Divider(),
              _buildConfigItem('密码', '••••••••', Icons.lock, Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '提示: 点击"编辑配置"按钮可以修改MySQL连接设置',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onToggleMysqlEdit,
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('编辑配置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigItem(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
