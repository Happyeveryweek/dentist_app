import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../utils/app_paths.dart';
import '../features/settings/widgets/app_info_widgets.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/log_manager.dart';

/// App Info Screen - Redesigned
/// Modern, clean, and dashboard-style presentation of system paths and status.
class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({Key? key}) : super(key: key);

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  Map<String, dynamic>? _logStats;
  bool _defaultDbExists = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    setState(() => _isLoading = true);
    try {
      final logStats = await LogManager.getLogStats();

      final dbFile = File(AppPaths.databasePath);
      final dbExists = await dbFile.exists();

      if (mounted) {
        setState(() {
          _logStats = logStats;
          _defaultDbExists = dbExists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('系统信息'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Header Section
                  _buildHeaderCard(),
                  const SizedBox(height: 24),

                  // Main Content Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: System & Storage
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildConfigCard(),
                            const SizedBox(height: 24),
                            _buildDirectoryStatusCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Tools & Logs
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _buildMySQLStatusCard(),
                            const SizedBox(height: 24),
                            _buildLogCard(),
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

  // --- Header Card ---
  Widget _buildHeaderCard() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
            child: const Icon(Icons.local_hospital_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settingsProvider.appName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '牙科诊所管理系统 - Windows Desktop Client',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAppInfo,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '刷新信息',
          ),
        ],
      ),
    );
  }

  // --- Configuration Card ---
  Widget _buildConfigCard() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final configPath = AppPaths.configPath;

    return InfoSectionCard(
      title: '环境配置',
      icon: Icons.settings_suggest_rounded,
      color: Colors.orange,
      children: [
        StatusRow(
          label: '配置文件路径',
          value: configPath,
          isFilePath: true,
        ),
        const SizedBox(height: 12),
        StatusRow(
          label: '默认数据库文件位置',
          value: _defaultDbExists ? AppPaths.databasePath : '没有配置 (文件不存在)',
          isFilePath: _defaultDbExists,
        ),
        if (settingsProvider.dataSourceType == 'sqlite' &&
            settingsProvider.customSqliteDbPath.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: StatusRow(
              label: '当前使用：自定义数据库文件',
              value: settingsProvider.customSqliteDbPath,
              isFilePath: true,
            ),
          ),
        ],
      ],
    );
  }

  // --- Directory Status Card ---
  Widget _buildDirectoryStatusCard() {
    return InfoSectionCard(
      title: '目录完整性状态',
      icon: Icons.folder_special_rounded,
      color: Colors.blue,
      action: TextButton.icon(
        onPressed: _openDataDirectory,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('打开文件夹'),
      ),
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _checkDirectoryStatus(),
          builder: (context, snapshot) {
            final directories = snapshot.data;
            if (directories == null) return const SizedBox();

            return Column(
              children: directories
                  .map((dir) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              dir['exists']
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: dir['exists'] ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              dir['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            // Simplified path display for cleaner look
                            if (!dir['exists'])
                              Text('缺失',
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12)),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // --- MySQL Tools Status Card ---
  Widget _buildMySQLStatusCard() {
    final mysqlInfo = AppPaths.mysqlToolsInfo;
    final allToolsAvailable = mysqlInfo['allToolsAvailable'] as bool;

    return InfoSectionCard(
      title: 'MySQL 工具链',
      icon: Icons.storage_rounded,
      color: Colors.purple,
      children: [
        StatusRow(
          label: '状态',
          valueWidget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  allToolsAvailable ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: allToolsAvailable
                      ? Colors.green.shade200
                      : Colors.red.shade200),
            ),
            child: Text(
              allToolsAvailable ? '运行正常' : '组件缺失',
              style: TextStyle(
                color: allToolsAvailable
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ToolStatusChip(
                label: 'MySQL', isAvailable: mysqlInfo['mysqlExists']),
            ToolStatusChip(
                label: 'Dump', isAvailable: mysqlInfo['mysqldumpExists']),
            ToolStatusChip(
                label: 'Lib', isAvailable: mysqlInfo['libmysqlExists']),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _openMySQLToolsDirectory,
                child: const Text('打开位置'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: allToolsAvailable ? _testMySQLTools : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('连通性测试'),
              ),
            ),
          ],
        )
      ],
    );
  }

  // --- Logs Card ---
  Widget _buildLogCard() {
    final logStats = _logStats;
    return InfoSectionCard(
      title: '系统日志',
      icon: Icons.receipt_long_rounded,
      color: Colors.teal,
      children: [
        if (logStats != null) ...[
          Row(
            children: [
              Expanded(
                child: StatBox(
                  label: '文件数',
                  value: '${logStats['fileCount']}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatBox(
                  label: '占用空间',
                  value: logStats['totalSizeFormatted'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportLogs,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('导出'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openLogDirectory,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('打开目录'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cleanupLogs,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('清理'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
          )
        ] else
          const Center(child: Text('暂无日志统计')),
      ],
    );
  }

  // --- Actions & Helpers ---

  Future<List<Map<String, dynamic>>> _checkDirectoryStatus() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    // Determine DB path based on data source
    String dbPath;
    String dbName;

    if (settingsProvider.dataSourceType == 'mysql') {
      final mysqlSettings = settingsProvider.getCompleteMySQLSettings();
      dbPath =
          'MySQL: ${mysqlSettings['host']}:${mysqlSettings['port']}/${mysqlSettings['database']}';
      dbName = 'MySQL数据库';
    } else {
      if (settingsProvider.customSqliteDbPath.isNotEmpty) {
        dbPath = settingsProvider.customSqliteDbPath;
      } else {
        dbPath = AppPaths.databasePath;
      }
      dbName = 'SQLite数据库';
    }

    final directories = [
      {'name': '数据根目录', 'path': AppPaths.dataDirectory, 'exists': false},
      {'name': '应用配置', 'path': AppPaths.configDirectory, 'exists': false},
      {'name': '运行日志', 'path': AppPaths.logDirectory, 'exists': false},
      {
        'name': '自动备份',
        'path': AppPaths.defaultBackupDirectory,
        'exists': false
      },
      {'name': dbName, 'path': dbPath, 'exists': false},
    ];

    for (final dir in directories) {
      final path = dir['path'] as String;
      try {
        if (path.startsWith('MySQL:')) {
          dir['exists'] = settingsProvider.isMySQLSettingsComplete();
        } else if (path.endsWith('.db') || path.endsWith('.json')) {
          dir['exists'] = await File(path).exists();
        } else {
          dir['exists'] = await Directory(path).exists();
        }
      } catch (e) {
        dir['exists'] = false;
      }
    }
    return directories;
  }

  Future<void> _openDataDirectory() async {
    _openDirectory(AppPaths.dataDirectory);
  }

  Future<void> _openMySQLToolsDirectory() async {
    _openDirectory(AppPaths.mysqlToolsDirectory);
  }

  Future<void> _openLogDirectory() async {
    _openDirectory(AppPaths.logDirectory);
  }

  Future<void> _openDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        if (Platform.isWindows) {
          await Process.run('explorer', [dir.path]);
        }
      } else {
        _showMessage('目录不存在: $path');
      }
    } catch (e) {
      _showMessage('无法打开目录: $e');
    }
  }

  Future<void> _exportLogs() async {
    try {
      final exportPath = AppPaths.exportDirectory;
      final exportedFile = await LogManager.exportLogs(exportPath);
      if (exportedFile != null) {
        _showMessage('日志已导出至: $exportedFile');
      } else {
        _showMessage('导出失败');
      }
    } catch (e) {
      _showMessage('导出出错: $e');
    }
  }

  Future<void> _cleanupLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理日志确认'),
        content: const Text('确定要删除30天前的旧日志文件吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LogManager.cleanupOldLogs();
        await _loadAppInfo();
        _showMessage('日志清理完毕');
      } catch (e) {
        _showMessage('清理失败: $e');
      }
    }
  }

  Future<void> _testMySQLTools() async {
    // Reusing logic but simplified UI for interaction
    if (!AppPaths.hasMySQLTools) return;

    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final mysql = await Process.run(AppPaths.mysqlExePath, ['--version'],
          runInShell: true);
      final dump = await Process.run(AppPaths.mysqldumpExePath, ['--version'],
          runInShell: true);

      if (!mounted) return;
      Navigator.pop(context); // close loading

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('测试结果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MySQL Client:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(mysql.stdout.toString().trim(),
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text('MySQL Dump:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(dump.stdout.toString().trim(),
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'))
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('测试失败: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// --- Reusable Private Widgets ---
