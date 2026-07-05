import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/theme/medical_semantic_colors.dart';

import '../../../models/patient.dart';
import '../../../widgets/dental_icons.dart';
import 'hoverable_patient_card.dart';
import 'patient_info_row.dart';
import '../../../utils/log_manager.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEditPermissionDenied;
  final VoidCallback onDeletePermissionDenied;

  const PatientCard({
    Key? key,
    required this.patient,
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
    final colors = context.colors;
    final displayPhone = _getDisplayPhone(patient.phone);

    return HoverablePatientCard(
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DentalAvatar(
                gender: patient.gender,
                name: patient.name,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patient.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.colors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DentalStatusIndicator(
                          status: patient.gender,
                          color: patient.gender == '女'
                              ? MedicalSemanticColors.femaleGender
                              : MedicalSemanticColors.maleGender,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 16,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.age}岁',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            displayPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.tokens.cardBackground.withValues(alpha: 0.5),
                  context.tokens.cardBackground.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: context.tokens.primaryAccent.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                if (patient.medicalRecordNumber != null)
                  PatientInfoRow(
                    icon: Icons.badge_outlined,
                    label: '病历号',
                    value: patient.medicalRecordNumber.toString(),
                    color: context.tokens.info,
                  ),
                if (patient.doctor?.isNotEmpty ?? false)
                  PatientInfoRow(
                    icon: Icons.medical_services_outlined,
                    label: '主治医生',
                    value: patient.doctor ?? '',
                    color: context.tokens.success,
                  ),
                if (patient.address?.isNotEmpty ?? false)
                  PatientInfoRow(
                    icon: Icons.location_on_outlined,
                    label: '地址',
                    value: patient.address ?? '',
                    color: context.tokens.secondaryAccent,
                    maxLines: 2,
                  ),
                PatientInfoRow(
                  icon: Icons.event_outlined,
                  label: '首诊日期',
                  value: DateFormat('yyyy-MM-dd').format(
                    patient.firstVisitDate,
                  ),
                  color: context.tokens.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DentalGradientButton(
                  onPressed: onView,
                  gradient: LinearGradient(
                    colors: [
                      context.tokens.info,
                      context.tokens.info.withValues(alpha: 0.8),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: tokens.cardBackground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '查看详情',
                        style: TextStyle(
                          color: tokens.cardBackground,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: canEdit
                    ? DentalGradientButton(
                        onPressed: onEdit,
                        gradient: LinearGradient(
                          colors: [
                            context.tokens.warning,
                            context.tokens.warning.withValues(alpha: 0.8),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: tokens.cardBackground,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '编辑',
                              style: TextStyle(
                                color: tokens.cardBackground,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : DentalGradientButton(
                        onPressed: onEditPermissionDenied,
                        gradient: LinearGradient(
                          colors: [
                            tokens.disabledBackground,
                            tokens.disabledText,
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 16, color: tokens.cardBackground),
                            const SizedBox(width: 8),
                            Text(
                              '权限不足',
                              style: TextStyle(
                                color: tokens.cardBackground,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              canDelete
                  ? Container(
                      decoration: BoxDecoration(
                        color: context.tokens.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.tokens.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: context.tokens.error,
                          size: 20,
                        ),
                        tooltip: '删除患者',
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: tokens.divider,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: onDeletePermissionDenied,
                        icon: Icon(
                          Icons.lock,
                          color: colors.onSurfaceVariant,
                          size: 20,
                        ),
                        tooltip: '权限不足',
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDisplayPhone(dynamic phone) {
    if (phone == null || phone.toString().isEmpty) {
      return '未设置';
    }

    final phoneStr = phone.toString();

    if (phoneStr.startsWith('[') && phoneStr.endsWith(']')) {
      try {
        final phones = jsonDecode(phoneStr) as List<dynamic>;
        if (phones.isEmpty) {
          return '未设置';
        }
        if (phones.length > 1) {
          return '${phones[0]} (+${phones.length - 1})';
        }
        return phones[0].toString();
      } catch (e) {
        LogManager.e('PatientCard', '解析电话号码JSON失败', error: e);
        final content = phoneStr.substring(1, phoneStr.length - 1);
        final regex = RegExp(r'"([^"]*)"');
        final matches = regex.allMatches(content);
        var parts = <String>[];

        if (matches.isNotEmpty) {
          for (final match in matches) {
            final group = match.group(1);
            if (group != null && group.isNotEmpty) {
              parts.add(group);
            }
          }
        }

        if (parts.isEmpty) {
          parts = content.split(',').map((p) => p.trim()).toList();
          parts = parts.map((p) {
            if ((p.startsWith('"') && p.endsWith('"')) ||
                (p.startsWith("'") && p.endsWith("'"))) {
              return p.substring(1, p.length - 1);
            }
            return p;
          }).toList();
        }

        if (parts.isNotEmpty) {
          if (parts.length > 1) {
            return '${parts[0]} (+${parts.length - 1})';
          }
          return parts[0];
        }

        return phoneStr;
      }
    } else if (phoneStr.contains(',')) {
      final parts = phoneStr.split(',');
      if (parts.isNotEmpty) {
        final cleanParts =
            parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        if (cleanParts.isEmpty) {
          return '未设置';
        }

        if (cleanParts.length > 1) {
          return '${cleanParts[0]} (+${cleanParts.length - 1})';
        }
        return cleanParts[0];
      }
    }

    return phoneStr;
  }
}
