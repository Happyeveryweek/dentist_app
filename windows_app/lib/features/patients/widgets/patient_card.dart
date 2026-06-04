import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/patient.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/dental_icons.dart';
import 'hoverable_patient_card.dart';
import 'patient_info_row.dart';

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
    final displayPhone = _getDisplayPhone(patient.phone);
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return HoverablePatientCard(
      isPurpleTheme: isPurpleTheme,
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DentalAvatar(
                gender: patient.gender,
                name: patient.name,
                size: 52,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patient.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: DentalColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DentalStatusIndicator(
                          status: patient.gender,
                          color: patient.gender == '女'
                              ? DentalColors.femalePink
                              : DentalColors.maleBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 16,
                          color: DentalColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.age}岁',
                          style: TextStyle(
                            fontSize: 14,
                            color: DentalColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: DentalColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            displayPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: DentalColors.onSurfaceVariant,
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
                  DentalColors.surface.withOpacity(0.5),
                  DentalColors.surface.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DentalColors.primary.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                if (patient.medical_record_number != null)
                  PatientInfoRow(
                    icon: Icons.badge_outlined,
                    label: '病历号',
                    value: patient.medical_record_number.toString(),
                    color: DentalColors.info,
                  ),
                if (patient.doctor != null && patient.doctor!.isNotEmpty)
                  PatientInfoRow(
                    icon: Icons.medical_services_outlined,
                    label: '主治医生',
                    value: patient.doctor ?? '',
                    color: DentalColors.success,
                  ),
                if (patient.address != null && patient.address!.isNotEmpty)
                  PatientInfoRow(
                    icon: Icons.location_on_outlined,
                    label: '地址',
                    value: patient.address ?? '',
                    color: DentalColors.secondary,
                    maxLines: 2,
                  ),
                PatientInfoRow(
                  icon: Icons.event_outlined,
                  label: '首诊日期',
                  value: DateFormat('yyyy-MM-dd').format(
                    patient.first_visit_date,
                  ),
                  color: DentalColors.warning,
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
                      DentalColors.info,
                      DentalColors.info.withOpacity(0.8),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '查看详情',
                        style: TextStyle(
                          color: Colors.white,
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
                            DentalColors.warning,
                            DentalColors.warning.withOpacity(0.8),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '编辑',
                              style: TextStyle(
                                color: Colors.white,
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
                            Colors.grey.withOpacity(0.7),
                            Colors.grey.withOpacity(0.5),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              '权限不足',
                              style: TextStyle(
                                color: Colors.white,
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
                        color: DentalColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: DentalColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: DentalColors.error,
                          size: 20,
                        ),
                        tooltip: '删除患者',
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: onDeletePermissionDenied,
                        icon: Icon(
                          Icons.lock,
                          color: Colors.grey[600],
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
        print('解析电话号码JSON失败: $e');
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
