import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../widgets/success_toast.dart';

/// 材料空状态组件
/// 用于显示患者暂无材料记录的空状态
class MaterialEmptyState extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onAddMaterial;

  const MaterialEmptyState({
    Key? key,
    required this.canEdit,
    required this.onAddMaterial,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: tokens.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无材料记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: tokens.iconMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '该患者还没有添加任何材料记录',
            style: TextStyle(
              fontSize: 14,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          _buildAddButton(context),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return canEdit
        ? ElevatedButton.icon(
            onPressed: onAddMaterial,
            icon: const Icon(Icons.add),
            label: const Text('添加第一个材料'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.primaryAccent,
              foregroundColor: tokens.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          )
        : ElevatedButton.icon(
            onPressed: () => AppToastManager.showError(
              context,
              message: '您只能为自己医生的患者添加材料',
            ),
            icon: const Icon(Icons.lock),
            label: const Text('权限不足'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.divider,
              foregroundColor: colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          );
  }
}
