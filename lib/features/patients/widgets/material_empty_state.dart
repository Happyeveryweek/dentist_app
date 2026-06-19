import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无材料记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '该患者还没有添加任何材料记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          _buildAddButton(context),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return canEdit
        ? ElevatedButton.icon(
            onPressed: onAddMaterial,
            icon: const Icon(Icons.add),
            label: const Text('添加第一个材料'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
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
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          );
  }
}
