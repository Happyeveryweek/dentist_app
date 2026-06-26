import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/utils/permission_utils.dart';

/// 患者列表卡片组件
/// 职责：显示患者列表中的单个患者卡片
class PatientListCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PatientListCard({
    super.key,
    required this.patient,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 获取显示的电话号码（如果是JSON格式，显示第一个）
    final displayPhone = _getDisplayPhone(patient.phone);
    final doctor = patient.doctor;
    final address = patient.address;

    // 为每个患者生成一个稳定的随机颜色，基于姓名
    final int colorSeed = patient.name.hashCode;
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      AppTheme.infoColor,
      AppTheme.successColor,
      AppTheme.warningColor,
    ];
    final patientColor = colors[colorSeed % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          onTap: onTap,
          child: Column(
            children: [
              // 顶部区域
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 头像
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: patientColor.withValues(alpha: 0.15),
                      child: Text(
                        patient.name.isNotEmpty
                            ? patient.name.characters.first
                            : "?",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: patientColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 姓名和基本信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                patient.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      patient.gender == '男'
                                          ? AppTheme.infoColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.accentColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  patient.gender,
                                  style: TextStyle(
                                    color:
                                        patient.gender == '男'
                                            ? AppTheme.infoColor
                                            : AppTheme.accentColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${patient.age}岁',
                                style: const TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: AppTheme.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayPhone,
                                style: const TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 操作按钮
                    Column(
                      children: [
                        PermissionWrapper(
                          module: 'patients',
                          action: 'edit',
                          recordDoctor: patient.doctor,
                          onPermissionDenied: () {
                            PermissionUtils.showPermissionDeniedMessage(
                              context,
                              customMessage: '您只能编辑自己负责的患者',
                            );
                          },
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: onEdit,
                            color: AppTheme.primaryColor,
                            tooltip: '编辑患者',
                          ),
                        ),
                        PermissionWrapper(
                          module: 'patients',
                          action: 'delete',
                          recordDoctor: patient.doctor,
                          onPermissionDenied: () {
                            PermissionUtils.showPermissionDeniedMessage(
                              context,
                              customMessage: '您只能删除自己负责的患者',
                            );
                          },
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: onDelete,
                            color: AppTheme.errorColor,
                            tooltip: '删除患者',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 底部区域
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行信息
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.badge_outlined,
                            text:
                                '病历号: ${patient.medicalRecordNumber ?? "未分配"}',
                            color: AppTheme.infoColor,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.calendar_today_outlined,
                            text:
                                '初诊: ${DateFormat('yyyy-MM-dd').format(patient.firstVisitDate)}',
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 第二行信息
                    Row(
                      children: [
                        Expanded(
                          child:
                              (doctor != null && doctor.isNotEmpty)
                                  ? _buildInfoItem(
                                    icon: Icons.medical_services_outlined,
                                    text: '医生: $doctor',
                                    color: AppTheme.secondaryColor,
                                  )
                                  : _buildInfoItem(
                                    icon: Icons.medical_services_outlined,
                                    text: '医生: 未分配',
                                    color: AppTheme.secondaryColor,
                                  ),
                        ),
                        Expanded(
                          child:
                              (address != null && address.isNotEmpty)
                                  ? _buildInfoItem(
                                    icon: Icons.location_on_outlined,
                                    text: address,
                                    color: AppTheme.accentColor,
                                  )
                                  : _buildInfoItem(
                                    icon: Icons.location_on_outlined,
                                    text: '未填写',
                                    color: AppTheme.lightText,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 查看详情按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('查看详情'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13),
        ),
      ],
    );
  }

  // 获取显示的电话号码
  String _getDisplayPhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return '未设置';
    }

    try {
      // 尝试解析JSON格式
      if (phone.startsWith('[') && phone.endsWith(']')) {
        final parsed = jsonDecode(phone);
        if (parsed is List && parsed.isNotEmpty) {
          return parsed[0].toString();
        }
      }
      return phone;
    } catch (e) {
      return phone;
    }
  }
}
