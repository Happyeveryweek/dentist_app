import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

/// 备份恢复区域组件
/// 负责显示数据库备份、恢复、Excel导出等功能
class BackupRestoreSection extends StatelessWidget {
  final bool isLoading;
  final String loadingText;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onExportExcel;

  const BackupRestoreSection({
    super.key,
    required this.isLoading,
    required this.loadingText,
    required this.onBackup,
    required this.onRestore,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 数据库备份卡片 - 美化版
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.backup,
                            color: AppTheme.primaryColor,
                            size: 26,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '数据库备份',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          '定期备份数据库可以保护您的重要数据，防止意外丢失。',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: onBackup,
                          icon: const Icon(Icons.backup, size: 20),
                          label: const Text(
                            '备份数据库',
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
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 数据库恢复卡片 - 美化版
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_backup_restore,
                            color: Colors.amber.shade700,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '数据库恢复',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber.shade800,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '警告：恢复操作将覆盖当前所有数据！请确保选择正确的备份文件。',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Color(0xFF7A5800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: onRestore,
                          icon: const Icon(Icons.restore, size: 20),
                          label: const Text(
                            '从备份恢复',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Excel导出卡片 - 美化版
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.table_chart,
                            color: Colors.green.shade600,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Excel导出',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '将患者信息导出为Excel表格文件，方便进行数据分析和统计报表生成。',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: onExportExcel,
                          icon: const Icon(Icons.file_download, size: 20),
                          label: const Text(
                            '导出为Excel',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 加载指示器
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        loadingText.isNotEmpty ? loadingText : '请稍候...',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
