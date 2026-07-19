import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'dart:typed_data';
import '../../../providers/user_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/appointment_provider.dart';
import '../../../providers/purchase_provider.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/medical_record_provider.dart';
import '../../../providers/material_provider.dart';
import '../../../widgets/success_toast.dart';

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;
  final String? requiredRole;
  final String? moduleId; // 模块标识符，用于权限检查

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
    this.requiredRole,
    this.moduleId,
  });
}

class UserInfoSection extends StatelessWidget {
  const UserInfoSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 只监听UserProvider的变化，不监听AppState
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tokens.panelBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.tokens.border),
        ),
        child: Row(
          children: [
            // 用户头像
            currentUser != null
                ? Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.tokens.primaryAccent, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: () {
                        final imageData = currentUser.imageData;
                        return imageData != null && imageData.isNotEmpty
                          ? Image.memory(
                              Uint8List.fromList(imageData),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: context.tokens.border,
                                  child: Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: context.tokens.textMuted,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: context.tokens.inputBackground,
                              child: currentUser.role == 'doctor' ||
                                      currentUser.role == 'admin'
                                  ? Image.asset(
                                      'assets/icons/doctor.png',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    )
                                  : Image.asset(
                                      'assets/icons/nurse.png',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    ),
                            );
                        }(),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: context.tokens.primaryAccent,
                      size: 24,
                    ),
                  ),
            const SizedBox(width: 12),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser?.username ?? 'admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: context.colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.roleDisplay ?? '管理员',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // 退出登录按钮
            IconButton(
              icon: Icon(
                Icons.logout_rounded,
                color: context.tokens.textMuted,
                size: 20,
              ),
              onPressed: () async {
                // 使用公共退出登录确认框组件
                final confirmed = await LogoutConfirmDialogManager.show(
                  context,
                  username: currentUser?.username ?? 'admin',
                );

                if (confirmed) {
                  if (!context.mounted) return;
                  await _clearSession(context);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              tooltip: '退出登录',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearSession(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final databaseProvider = context.read<DatabaseProvider>();
    final patientProvider = context.read<PatientProvider>();
    final appointmentProvider = context.read<AppointmentProvider>();
    final purchaseProvider = context.read<PurchaseProvider>();
    final financialProvider = context.read<FinancialProvider>();
    final medicalRecordProvider = context.read<MedicalRecordProvider>();
    final materialProvider = context.read<MaterialProvider>();

    await userProvider.clearSession();
    await databaseProvider.clearSession();
    patientProvider.clearCache();
    appointmentProvider.clearCache();
    purchaseProvider.clearCache();
    financialProvider.clearCache();
    medicalRecordProvider.clearAllCache();
    materialProvider.clearCache();
  }
}
