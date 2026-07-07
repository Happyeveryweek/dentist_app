import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/medical_template.dart';

/// 医疗模板空状态组件
/// 显示空状态，包含图标、提示文本、初始化按钮、添加按钮
class MedicalTemplateEmptyState extends StatelessWidget {
  final String templateType;
  final String title;
  final VoidCallback onInitialize;
  final VoidCallback onAdd;

  const MedicalTemplateEmptyState({
    Key? key,
    required this.templateType,
    required this.title,
    required this.onInitialize,
    required this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
            color: tokens.warningContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.warning),
          ),
            child: Icon(
              templateType == MedicalTemplateType.treatment
                  ? Icons.healing_rounded
                  : Icons.note_add_rounded,
              size: 64,
              color: tokens.warning,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无${1}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '您可以添加自定义模板或初始化默认模板',
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurfaceVariant,
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
                label: const Text('初始化默认模板'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.warning,
                  foregroundColor: tokens.cardBackground,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('添加模板'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
