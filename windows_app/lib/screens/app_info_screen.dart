import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../utils/app_paths.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/log_manager.dart';

/// 应用信息页面
/// 显示应用路径、配置存储等信息
class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({Key? key}) : super(key: key);

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  Map<String, dynamic>? _appInfo;
  Map<String, dynamic>? _configInfo;
  Map<String, dynamic>? _logStats;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      final appInfo = AppPaths.appInfo;
      final configInfo = settingsProvider.getConfigStorageInfo();
      final logStats = await LogManager.getLogStats();
      
      setState(() {
        _appInfo = appInfo;
        _configInfo = configInfo;
        _logStats = logStats;
      });
    } catch (e) {
      print('加载应用信息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用信息'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 顶部概览卡片
            _buildOverviewCard(),
            
            const SizedBox(height: 12),
            
            // 主要内容区域 - 使用网格布局
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧列
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(flex: 1, child: _buildCompactConfigStorageCard()),
                        const SizedBox(height: 8),
                        Expanded(flex: 2, child: _buildCompactDirectoryStatusCard()),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 右侧列
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(flex: 1, child: _buildCompactLogInfoCard()),
                        const SizedBox(height: 8),
                        Expanded(flex: 2, child: _buildCompactMySQLToolsCard()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 底部操作按钮
            _buildCompactActionButtons(),
          ],
        ),
      ),
    );
  }

  // 顶部概览卡片
  Widget _buildOverviewCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '牙医诊所管理系统',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '应用目录: ${_appInfo?['appDirectory'] ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '数据目录: ${_appInfo?['dataDirectory'] ?? 'Unknown'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (_appInfo?['isPortableMode'] == 'true') 
                    ? Colors.green.shade100 
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (_appInfo?['isPortableMode'] == 'true') ? '便携模式' : '标准模式',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: (_appInfo?['isPortableMode'] == 'true') 
                      ? Colors.green.shade700 
                      : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, Map<String, dynamic> info) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...info.entries.map((entry) => _buildInfoRow(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              value.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 紧凑的配置存储卡片
  Widget _buildCompactConfigStorageCard() {
    final useFileStorage = _configInfo?['useFileStorage'] == true;
    return Card(
      elevation: 2,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('配置存储', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: useFileStorage ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    useFileStorage ? '文件' : '系统',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: useFileStorage ? Colors.green.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              useFileStorage ? '📁 文件存储模式' : '⚙️ 系统存储模式',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _configInfo?['configPath']?.toString() ?? 'Unknown',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigStorageCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '配置存储信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 当前存储模式状态
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_configInfo?['useFileStorage'] == true) 
                    ? Colors.green.shade50 
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_configInfo?['useFileStorage'] == true) 
                      ? Colors.green.shade300 
                      : Colors.blue.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        (_configInfo?['useFileStorage'] == true) 
                            ? Icons.folder 
                            : Icons.settings_applications,
                        color: (_configInfo?['useFileStorage'] == true) 
                            ? Colors.green.shade700 
                            : Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '当前存储模式',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: (_configInfo?['useFileStorage'] == true) 
                              ? Colors.green.shade800 
                              : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_configInfo?['useFileStorage'] == true) 
                        ? '📁 文件存储模式' 
                        : '⚙️ 系统存储模式 (SharedPreferences)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (_configInfo?['useFileStorage'] == true) 
                          ? Colors.green.shade800 
                          : Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (_configInfo?['useFileStorage'] == true) 
                        ? '配置文件存储在应用目录下，便于备份和迁移' 
                        : '配置存储在系统标准位置，由系统管理',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 存储位置信息
            _buildStorageLocationInfo(),
            
            const SizedBox(height: 16),
            
            // 技术详情（可折叠）
            ExpansionTile(
              title: const Text(
                '技术详情',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTechnicalDetail('存储模式', _configInfo?['storageMode']?.toString() ?? 'Unknown'),
                      _buildTechnicalDetail('文件存储', _configInfo?['useFileStorage']?.toString() ?? 'Unknown'),
                      _buildTechnicalDetail('配置路径', _configInfo?['configPath']?.toString() ?? 'Unknown'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageLocationInfo() {
    final useFileStorage = _configInfo?['useFileStorage'] == true;
    final configPath = _configInfo?['configPath']?.toString() ?? 'Unknown';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                '存储位置',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (useFileStorage) ...[
            // 文件存储模式的详细信息
            _buildLocationItem(
              '配置文件',
              configPath,
              Icons.description,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildLocationItem(
              '数据目录',
              _appInfo?['dataDirectory']?.toString() ?? 'Unknown',
              Icons.folder,
              Colors.blue,
            ),
          ] else ...[
            // SharedPreferences模式的信息
            _buildLocationItem(
              '系统配置',
              'Windows注册表 / AppData',
              Icons.settings_applications,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(
              '具体位置由系统管理，通常在：\n• HKEY_CURRENT_USER\\Software\\Flutter\n• %APPDATA%\\Roaming\\[应用名]',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, String path, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                path,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 紧凑的目录状态卡片
  Widget _buildCompactDirectoryStatusCard() {
    return Card(
      elevation: 2,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('目录状态', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _checkDirectoryStatus(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final directories = snapshot.data ?? [];
                  final existingCount = directories.where((d) => d['exists'] == true).length;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('$existingCount/${directories.length} 个目录可用'),
                          const Spacer(),
                          Icon(
                            existingCount == directories.length ? Icons.check_circle : Icons.warning,
                            color: existingCount == directories.length ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 显示所有目录，不使用滚动条
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: directories.map((dir) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    dir['exists'] ? Icons.check_circle : Icons.error,
                                    color: dir['exists'] ? Colors.green : Colors.red,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dir['name'],
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dir['path'],
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade600,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '目录状态检查',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _checkDirectoryStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final directories = snapshot.data ?? [];
                return Column(
                  children: directories.map((dir) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          dir['exists'] ? Icons.check_circle : Icons.error,
                          color: dir['exists'] ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dir['name'],
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                dir['path'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }



  // 紧凑的操作按钮
  Widget _buildCompactActionButtons() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loadAppInfo,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('刷新信息', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openDataDirectory,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('打开数据目录', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _switchStorageMode,
                icon: Icon(
                  (_configInfo?['useFileStorage'] == true) 
                      ? Icons.settings_applications 
                      : Icons.folder,
                  size: 16,
                ),
                label: Text(
                  (_configInfo?['useFileStorage'] == true) 
                      ? '切换到系统存储' 
                      : '切换到文件存储',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_configInfo?['useFileStorage'] == true) 
                      ? Colors.blue.shade600 
                      : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '操作',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadAppInfo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新信息'),
                ),
                ElevatedButton.icon(
                  onPressed: _openDataDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('打开数据目录'),
                ),
                ElevatedButton.icon(
                  onPressed: _switchStorageMode,
                  icon: Icon(
                    (_configInfo?['useFileStorage'] == true) 
                        ? Icons.settings_applications 
                        : Icons.folder,
                  ),
                  label: Text(
                    (_configInfo?['useFileStorage'] == true) 
                        ? '切换到系统存储' 
                        : '切换到文件存储',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_configInfo?['useFileStorage'] == true) 
                        ? Colors.blue.shade600 
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _testFileOperations,
                  icon: const Icon(Icons.science),
                  label: const Text('测试文件操作'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 紧凑的日志信息卡片
  Widget _buildCompactLogInfoCard() {
    return Card(
      elevation: 2,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.article, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('日志信息', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _logStats != null 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildCompactStatItem('文件', '${_logStats!['fileCount']}', Icons.description, Colors.blue),
                          const SizedBox(width: 8),
                          _buildCompactStatItem('大小', _logStats!['totalSizeFormatted'], Icons.storage, Colors.green),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            '日志目录: ${_logStats!['logDirectory']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openLogDirectory,
                              icon: const Icon(Icons.folder_open, size: 14),
                              label: const Text('打开', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _exportLogs,
                              icon: const Icon(Icons.file_download, size: 14),
                              label: const Text('导出', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.article, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '日志信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_logStats != null) ...[
              // 日志统计信息
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '日志统计',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLogStatItem(
                            '文件数量',
                            '${_logStats!['fileCount']} 个',
                            Icons.description,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildLogStatItem(
                            '总大小',
                            _logStats!['totalSizeFormatted'],
                            Icons.storage,
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildLogStatItem(
                            '总行数',
                            '${_logStats!['totalLines']} 行',
                            Icons.format_list_numbered,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 日志目录路径
              _buildLocationItem(
                '日志目录',
                _logStats!['logDirectory'],
                Icons.folder,
                Colors.purple,
              ),
              
              const SizedBox(height: 16),
              
              // 日志操作按钮
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openLogDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('打开日志目录'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportLogs,
                    icon: const Icon(Icons.file_download),
                    label: const Text('导出日志'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _cleanupLogs,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('清理日志'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 紧凑的MySQL工具卡片
  Widget _buildCompactMySQLToolsCard() {
    final mysqlInfo = AppPaths.mysqlToolsInfo;
    final allToolsAvailable = mysqlInfo['allToolsAvailable'] as bool;
    
    return Card(
      elevation: 2,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('MySQL工具', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: allToolsAvailable ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    allToolsAvailable ? '可用' : '不可用',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: allToolsAvailable ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        mysqlInfo['toolsDirectory'],
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildToolStatusChip('mysql.exe', mysqlInfo['mysqlExists'] as bool),
                      const SizedBox(width: 4),
                      _buildToolStatusChip('mysqldump.exe', mysqlInfo['mysqldumpExists'] as bool),
                      const SizedBox(width: 4),
                      _buildToolStatusChip('libmysql.dll', mysqlInfo['libmysqlExists'] as bool),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openMySQLToolsDirectory,
                          icon: const Icon(Icons.folder_open, size: 14),
                          label: const Text('打开', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: allToolsAvailable ? _testMySQLTools : null,
                          icon: const Icon(Icons.science, size: 14),
                          label: const Text('测试', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allToolsAvailable ? Colors.green.shade600 : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolStatusChip(String toolName, bool exists) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: exists ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: exists ? Colors.green.shade300 : Colors.red.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              exists ? Icons.check_circle : Icons.cancel,
              color: exists ? Colors.green.shade700 : Colors.red.shade700,
              size: 14,
            ),
            const SizedBox(height: 2),
            Text(
              toolName.split('.').first,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: exists ? Colors.green.shade800 : Colors.red.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySQLToolsCard() {
    final mysqlInfo = AppPaths.mysqlToolsInfo;
    final allToolsAvailable = mysqlInfo['allToolsAvailable'] as bool;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'MySQL工具状态',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 工具状态总览
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: allToolsAvailable 
                    ? Colors.green.shade50 
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: allToolsAvailable 
                      ? Colors.green.shade300 
                      : Colors.red.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        allToolsAvailable ? Icons.check_circle : Icons.error,
                        color: allToolsAvailable 
                            ? Colors.green.shade700 
                            : Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        allToolsAvailable ? 'MySQL工具可用' : 'MySQL工具不可用',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: allToolsAvailable 
                              ? Colors.green.shade800 
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    allToolsAvailable 
                        ? '所有MySQL工具都已正确安装，可以使用MySQL备份功能' 
                        : 'MySQL工具缺失或不完整，MySQL备份功能将不可用',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 工具详细信息
            _buildToolDetailSection('工具目录', mysqlInfo['toolsDirectory']),
            
            const SizedBox(height: 12),
            
            // 各个工具的状态
            Row(
              children: [
                Expanded(
                  child: _buildToolStatusItem(
                    'mysql.exe',
                    mysqlInfo['mysqlExists'] as bool,
                    mysqlInfo['mysqlPath'],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToolStatusItem(
                    'mysqldump.exe',
                    mysqlInfo['mysqldumpExists'] as bool,
                    mysqlInfo['mysqldumpPath'],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToolStatusItem(
                    'libmysql.dll',
                    mysqlInfo['libmysqlExists'] as bool,
                    mysqlInfo['libmysqlPath'],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 操作按钮
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openMySQLToolsDirectory(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('打开工具目录'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _testMySQLTools,
                  icon: const Icon(Icons.science),
                  label: const Text('测试工具'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allToolsAvailable 
                        ? Colors.green.shade600 
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SelectableText(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolStatusItem(String toolName, bool exists, String toolPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: exists ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: exists ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(
            exists ? Icons.check_circle : Icons.cancel,
            color: exists ? Colors.green.shade700 : Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            toolName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: exists ? Colors.green.shade800 : Colors.red.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            exists ? '可用' : '缺失',
            style: TextStyle(
              fontSize: 10,
              color: exists ? Colors.green.shade600 : Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _checkDirectoryStatus() async {
    final directories = [
      {'name': '应用目录', 'path': AppPaths.appDirectory, 'exists': false},
      {'name': '数据目录', 'path': AppPaths.dataDirectory, 'exists': false},
      {'name': '配置目录', 'path': AppPaths.configDirectory, 'exists': false},
      {'name': '缓存目录', 'path': AppPaths.cacheDirectory, 'exists': false},
      {'name': '日志目录', 'path': AppPaths.logDirectory, 'exists': false},
      {'name': '备份目录', 'path': AppPaths.defaultBackupDirectory, 'exists': false},
      {'name': '导出目录', 'path': AppPaths.exportDirectory, 'exists': false},
      {'name': '临时目录', 'path': AppPaths.tempDirectory, 'exists': false},
      {'name': '数据库文件', 'path': AppPaths.databasePath, 'exists': false},
      {'name': '缩略图缓存', 'path': AppPaths.thumbnailCacheDirectory, 'exists': false},
    ];

    for (final dir in directories) {
      final path = dir['path'] as String;
      try {
        if (path.endsWith('.db') || path.endsWith('.json')) {
          // 文件检查
          dir['exists'] = await File(path).exists();
        } else {
          // 目录检查
          dir['exists'] = await Directory(path).exists();
        }
      } catch (e) {
        print('检查路径失败 $path: $e');
        dir['exists'] = false;
      }
    }

    return directories;
  }

  Future<void> _openDataDirectory() async {
    try {
      final dataDir = Directory(AppPaths.dataDirectory);
      if (await dataDir.exists()) {
        // 在Windows上打开文件夹
        if (Platform.isWindows) {
          await Process.run('explorer', [dataDir.path]);
        }
      } else {
        _showMessage('数据目录不存在: ${dataDir.path}');
      }
    } catch (e) {
      _showMessage('打开数据目录失败: $e');
    }
  }

  Future<void> _switchStorageMode() async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final currentMode = settingsProvider.useFileStorage;
      
      // 显示确认对话框
      final confirmed = await _showSwitchConfirmDialog(currentMode);
      if (!confirmed) return;
      
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在切换存储模式...'),
            ],
          ),
        ),
      );
      
      String resultMessage;
      bool success = false;
      
      if (currentMode) {
        // 从文件存储切换到SharedPreferences
        await settingsProvider.switchToPreferencesStorage();
        resultMessage = '''
✅ 已成功切换到系统存储模式

📍 新的存储位置：
• Windows注册表或AppData目录
• 由系统自动管理配置

💡 提示：
• 原配置文件仍保留在应用目录中作为备份
• 后续所有配置将保存到系统标准位置
        ''';
        success = true;
      } else {
        // 从SharedPreferences切换到文件存储
        success = await settingsProvider.switchToFileStorage();
        if (success) {
          final configPath = AppPaths.configPath;
          resultMessage = '''
✅ 已成功切换到文件存储模式

📍 新的存储位置：
• 配置文件：$configPath
• 数据目录：${AppPaths.dataDirectory}

💡 提示：
• 所有配置现在存储在应用目录下
• 便于备份和迁移整个应用
• 支持便携模式使用
          ''';
        } else {
          resultMessage = '''
❌ 切换到文件存储模式失败

可能的原因：
• 应用目录没有写入权限
• 磁盘空间不足
• 文件被其他程序占用

💡 建议：
• 以管理员身份运行应用
• 检查磁盘空间
• 关闭可能占用文件的程序
          ''';
        }
      }
      
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      // 显示结果对话框
      await _showResultDialog(success, resultMessage);
      
      // 刷新信息
      await _loadAppInfo();
      
    } catch (e) {
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      await _showResultDialog(false, '''
❌ 切换存储模式时发生错误

错误信息：$e

💡 建议：
• 重启应用后重试
• 检查应用权限
• 联系技术支持
      ''');
    }
  }

  Future<bool> _showSwitchConfirmDialog(bool currentUseFileStorage) async {
    final targetMode = currentUseFileStorage ? '系统存储模式' : '文件存储模式';
    final currentMode = currentUseFileStorage ? '文件存储模式' : '系统存储模式';
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('确认切换存储模式'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前模式：$currentMode'),
            Text('目标模式：$targetMode'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '切换说明',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentUseFileStorage 
                        ? '• 配置将从应用目录迁移到系统标准位置\n• 原配置文件将保留作为备份\n• 后续配置由系统管理'
                        : '• 配置将从系统位置迁移到应用目录\n• 便于备份和便携使用\n• 需要应用目录写入权限',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认切换'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showResultDialog(bool success, String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(success ? '切换成功' : '切换失败'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _testFileOperations() async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // 测试保存和加载配置
      final testKey = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final testValue = 'Test Value ${DateTime.now()}';
      
      final saveSuccess = await settingsProvider.saveConfigValue(testKey, testValue);
      if (!saveSuccess) {
        _showMessage('保存测试配置失败');
        return;
      }
      
      final loadedValue = await settingsProvider.loadConfigValue<String>(testKey);
      if (loadedValue != testValue) {
        _showMessage('加载测试配置失败: 期望 $testValue, 实际 $loadedValue');
        return;
      }
      
      _showMessage('文件操作测试成功');
      await _loadAppInfo();
    } catch (e) {
      _showMessage('文件操作测试失败: $e');
    }
  }

  Future<void> _openLogDirectory() async {
    try {
      final logDir = Directory(AppPaths.logDirectory);
      if (await logDir.exists()) {
        // 在Windows上打开文件夹
        if (Platform.isWindows) {
          await Process.run('explorer', [logDir.path]);
        }
      } else {
        _showMessage('日志目录不存在: ${logDir.path}');
      }
    } catch (e) {
      _showMessage('打开日志目录失败: $e');
    }
  }

  Future<void> _exportLogs() async {
    try {
      // 选择导出目录
      final exportPath = await _selectExportDirectory();
      if (exportPath == null) return;

      // 显示导出进度
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在导出日志...'),
            ],
          ),
        ),
      );

      final exportedFile = await LogManager.exportLogs(exportPath);
      
      // 关闭进度对话框
      Navigator.of(context).pop();

      if (exportedFile != null) {
        _showMessage('日志导出成功: $exportedFile');
      } else {
        _showMessage('日志导出失败');
      }
    } catch (e) {
      Navigator.of(context).pop(); // 关闭进度对话框
      _showMessage('导出日志失败: $e');
    }
  }

  Future<String?> _selectExportDirectory() async {
    // 这里可以使用文件选择器，暂时使用默认导出目录
    try {
      return AppPaths.exportDirectory;
    } catch (e) {
      return null;
    }
  }

  Future<void> _cleanupLogs() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认清理日志'),
          content: const Text('这将删除30天前的旧日志文件，确定要继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('确定清理'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await LogManager.cleanupOldLogs();
        await _loadAppInfo(); // 刷新日志统计
        _showMessage('日志清理完成');
      }
    } catch (e) {
      _showMessage('清理日志失败: $e');
    }
  }

  Future<void> _openMySQLToolsDirectory() async {
    try {
      final toolsDir = Directory(AppPaths.mysqlToolsDirectory);
      if (await toolsDir.exists()) {
        // 在Windows上打开文件夹
        if (Platform.isWindows) {
          await Process.run('explorer', [toolsDir.path]);
        }
      } else {
        _showMessage('MySQL工具目录不存在: ${toolsDir.path}');
      }
    } catch (e) {
      _showMessage('打开MySQL工具目录失败: $e');
    }
  }

  Future<void> _testMySQLTools() async {
    try {
      if (!AppPaths.hasMySQLTools) {
        _showMessage('MySQL工具不可用，无法进行测试');
        return;
      }

      // 显示测试进度
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在测试MySQL工具...'),
            ],
          ),
        ),
      );

      // 测试mysql.exe
      final mysqlResult = await Process.run(
        AppPaths.mysqlExePath,
        ['--version'],
        runInShell: true,
      );

      // 测试mysqldump.exe
      final mysqldumpResult = await Process.run(
        AppPaths.mysqldumpExePath,
        ['--version'],
        runInShell: true,
      );

      // 关闭进度对话框
      Navigator.of(context).pop();

      // 显示测试结果
      final mysqlVersion = mysqlResult.exitCode == 0 
          ? mysqlResult.stdout.toString().trim()
          : '测试失败: ${mysqlResult.stderr}';
      
      final mysqldumpVersion = mysqldumpResult.exitCode == 0 
          ? mysqldumpResult.stdout.toString().trim()
          : '测试失败: ${mysqldumpResult.stderr}';

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('MySQL工具测试结果'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'mysql.exe:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  mysqlVersion,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text(
                  'mysqldump.exe:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  mysqldumpVersion,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );

    } catch (e) {
      // 关闭进度对话框
      Navigator.of(context).pop();
      _showMessage('测试MySQL工具失败: $e');
    }
  }



  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}