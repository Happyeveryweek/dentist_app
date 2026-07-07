import 'package:flutter/material.dart';

import '../../../theme/theme_context_extensions.dart';

class PatientFormHeader extends StatelessWidget {
  final bool isEditingExistingPatient;
  final bool isNewPatient;
  final String? editingPatientName;
  final VoidCallback onClose;

  const PatientFormHeader({
    Key? key,
    required this.isEditingExistingPatient,
    required this.isNewPatient,
    required this.editingPatientName,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        gradient: tokens.primaryHeaderGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEditingExistingPatient
                      ? Icons.edit
                      : (isNewPatient ? Icons.person_add : Icons.edit),
                  color: colors.onPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isEditingExistingPatient
                    ? '编辑患者 ($editingPatientName)'
                    : (isNewPatient ? '添加患者' : '编辑患者'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimary,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: colors.shadow.withValues(alpha: 0.26),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.close, color: colors.onPrimary, size: 18),
              onPressed: onClose,
              splashRadius: 16,
              tooltip: '关闭',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientFormPermissionNotice extends StatelessWidget {
  const PatientFormPermissionNotice({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tokens.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: tokens.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '您正在编辑其他医生的患者，只能修改牙齿状况部分，其他信息为只读状态',
              style: TextStyle(
                color: tokens.warning,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientFormActions extends StatelessWidget {
  final bool isLoading;
  final bool isEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const PatientFormActions({
    Key? key,
    required this.isLoading,
    required this.isEditMode,
    required this.onCancel,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: tokens.subtleHeaderGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(
            color: tokens.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tokens.divider.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                foregroundColor: colors.onSurfaceVariant,
              ),
              child: const Text(
                '取消',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              gradient: tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: tokens.primaryAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: colors.onPrimary,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditMode ? '更新中...' : '保存中...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimary,
                      ),
                    ),
                  ] else ...[
                    Text(
                      isEditMode ? '更新' : '保存',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
