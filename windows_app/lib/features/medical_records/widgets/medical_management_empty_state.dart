import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 病历管理空状态组件
/// 显示病历模板数据未初始化的空状态
class MedicalManagementEmptyState extends StatelessWidget {
  final String category;
  final String title;
  final VoidCallback onInitialize;
  final VoidCallback onAdd;

  const MedicalManagementEmptyState({
    Key? key,
    required this.category,
    required this.title,
    required this.onInitialize,
    required this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Icon(
                Icons.settings_backup_restore_rounded,
                size: 64,
                color: Colors.orange.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '病历模板数据未初始化',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '请点击右上角的初始化按钮来导入预设的疾病类型数据',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '包括牙科疾病、全身疾病和过敏类型等模板数据',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onInitialize,
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: const Text('初始化模板数据'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: context.tokens.cardBackground,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('手动添加'),
                  style: OutlinedButton.styleFrom(
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
