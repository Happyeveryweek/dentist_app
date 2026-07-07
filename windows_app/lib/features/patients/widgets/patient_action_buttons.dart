import 'package:flutter/material.dart';

import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'patient_action_button.dart';

class PatientActionButtons extends StatelessWidget {
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEditPermissionDenied;
  final VoidCallback onDeletePermissionDenied;

  const PatientActionButtons({
    Key? key,
    required this.canEdit,
    required this.canDelete,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onEditPermissionDenied,
    required this.onDeletePermissionDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PatientActionButton(
          icon: Icons.visibility_outlined,
          color: tokens.primaryAccent,
          tooltip: '查看',
          onPressed: onView,
        ),
        const SizedBox(width: 4),
        canEdit
            ? PatientActionButton(
                icon: Icons.edit_outlined,
                color: tokens.secondaryAccent,
                tooltip: '编辑',
                onPressed: onEdit,
              )
            : PatientActionButton(
                icon: Icons.lock,
                color: tokens.iconMuted,
                tooltip: '权限不足',
                onPressed: onEditPermissionDenied,
              ),
        const SizedBox(width: 4),
        canDelete
            ? PatientActionButton(
                icon: Icons.delete_outlined,
                color: tokens.error,
                tooltip: '删除',
                onPressed: onDelete,
              )
            : PatientActionButton(
                icon: Icons.lock,
                color: tokens.iconMuted,
                tooltip: '权限不足',
                onPressed: onDeletePermissionDenied,
              ),
      ],
    );
  }
}
