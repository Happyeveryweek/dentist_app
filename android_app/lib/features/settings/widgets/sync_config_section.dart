import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/sync_config.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/utils/message_toast_helper.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import 'package:dentist_app/screens/sync_logs_screen.dart';

/// 同步配置区域组件
/// 负责显示数据同步配置、同步间隔设置、手动同步等功能
class SyncConfigSection extends StatefulWidget {
  const SyncConfigSection({super.key});

  @override
  State<SyncConfigSection> createState() => _SyncConfigSectionState();
}

class _SyncConfigSectionState extends State<SyncConfigSection> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SyncConfig>(
      future: SyncConfig.loadSyncConfig(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data ?? SyncConfig();

        return Consumer<DatabaseProvider>(
          builder: (context, provider, child) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '数据同步配置',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 同步开关
                  SwitchListTile(
                    title: const Text('启动时自动检查同步'),
                    subtitle: const Text('应用启动时按间隔检查是否从MySQL同步到本地'),
                    value: config.syncEnabled,
                    onChanged: (value) async {
                      config.syncEnabled = value;
                      await SyncConfig.saveSyncConfig(config);
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 16),

                  // 同步间隔设置
                  ListTile(
                    title: const Text('启动检查间隔'),
                    subtitle: const Text('设置应用启动时检查是否同步的时间间隔'),
                    trailing: DropdownButton<int>(
                      value: config.syncIntervalDays,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1天')),
                        DropdownMenuItem(value: 3, child: Text('3天')),
                        DropdownMenuItem(value: 7, child: Text('7天')),
                        DropdownMenuItem(value: 14, child: Text('14天')),
                        DropdownMenuItem(value: 30, child: Text('30天')),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          config.syncIntervalDays = value;
                          await SyncConfig.saveSyncConfig(config);
                          setState(() {});
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 上次同步时间
                  ListTile(
                    title: const Text('上次同步时间'),
                    subtitle: Text(
                      config.lastSyncTime.isEmpty
                          ? '从未同步'
                          : _formatLastSyncTime(config.lastSyncTime),
                    ),
                    leading: const Icon(Icons.access_time),
                  ),

                  const SizedBox(height: 20),

                  // 手动同步按钮
                  ElevatedButton.icon(
                    onPressed:
                        provider.isConnected && provider.dbType == 'mysql'
                            ? () async {
                              try {
                                MessageToastHelper.showInfo(context, '数据同步已启动');

                                final success = await provider.forceDataSync();

                                if (context.mounted) {
                                  if (success) {
                                    MessageToastHelper.showSuccess(
                                      context,
                                      '数据同步完成',
                                    );
                                  } else {
                                    MessageToastHelper.showError(
                                      context,
                                      '数据同步失败',
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  MessageToastHelper.showError(
                                    context,
                                    '同步失败: $e',
                                  );
                                }
                              }
                            }
                            : null,
                    icon: const Icon(Icons.sync),
                    label: const Text('立即同步'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 查看日志按钮
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SyncLogsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('查看同步日志'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatLastSyncTime(String lastSyncTime) {
    try {
      final dateTime = DateTimeFormatter.fromDbString(lastSyncTime);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '时间格式错误';
    }
  }
}
