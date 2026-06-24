import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/utils/permission_utils.dart';

class AppointmentActionButtons extends StatelessWidget {
  final String status;
  final String? patientDoctor;
  final Function(String) onChangeStatus;

  const AppointmentActionButtons({super.key, 
    required this.status,
    required this.patientDoctor,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '操作',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != '已预约' && status != 'scheduled')
                  PermissionWrapper(
                    module: 'appointments',
                    action: 'edit',
                    recordDoctor: patientDoctor,
                    onPermissionDenied: () {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您只能修改自己负责患者的预约',
                      );
                    },
                    child: _buildActionButton(
                      '已预约',
                      AppTheme.infoColor,
                      Icons.schedule,
                      () => onChangeStatus('scheduled'),
                    ),
                  ),
                if (status != '已完成' && status != 'completed')
                  PermissionWrapper(
                    module: 'appointments',
                    action: 'edit',
                    recordDoctor: patientDoctor,
                    onPermissionDenied: () {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您只能修改自己负责患者的预约',
                      );
                    },
                    child: _buildActionButton(
                      '已完成',
                      AppTheme.successColor,
                      Icons.check_circle_outline,
                      () => onChangeStatus('completed'),
                    ),
                  ),
                if (status != '已取消' && status != 'cancelled')
                  PermissionWrapper(
                    module: 'appointments',
                    action: 'edit',
                    recordDoctor: patientDoctor,
                    onPermissionDenied: () {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您只能修改自己负责患者的预约',
                      );
                    },
                    child: _buildActionButton(
                      '已取消',
                      AppTheme.errorColor,
                      Icons.cancel_outlined,
                      () => onChangeStatus('cancelled'),
                    ),
                  ),
                if (status != '未到诊' &&
                    status != 'missed' &&
                    status != 'no_show')
                  PermissionWrapper(
                    module: 'appointments',
                    action: 'edit',
                    recordDoctor: patientDoctor,
                    onPermissionDenied: () {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您只能修改自己负责患者的预约',
                      );
                    },
                    child: _buildActionButton(
                      '未到诊',
                      Colors.orange,
                      Icons.unpublished_outlined,
                      () => onChangeStatus('no_show'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color),
        ),
      ),
    );
  }
}
