import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../models/patient.dart';
import 'patient_action_buttons.dart';
import '../../../utils/log_manager.dart';
import '../../../theme/medical_semantic_colors.dart';

class PatientListItem extends StatelessWidget {
  final Patient patient;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEditPermissionDenied;
  final VoidCallback onDeletePermissionDenied;

  const PatientListItem({
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
    final patientName = patient.name;
    final patientGender = patient.gender;
    final avatarBgColor = patientGender == '女'
        ? MedicalSemanticColors.femaleGender.withValues(alpha: 0.2)
        : MedicalSemanticColors.maleGender.withValues(alpha: 0.1);
    final avatarTextColor = patientGender == '女'
        ? MedicalSemanticColors.femaleGender
        : MedicalSemanticColors.maleGender;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        color: tokens.cardBackground,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                tokens.cardBackground.withValues(alpha: 0.0),
                tokens.mutedBackground.withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: onView,
            borderRadius: BorderRadius.circular(12),
            mouseCursor: SystemMouseCursors.click,
            hoverColor: tokens.primaryAccent.withValues(alpha: 0.1),
            splashColor: tokens.primaryAccent.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _PatientAvatar(
                    patientName: patientName,
                    avatarBgColor: avatarBgColor,
                    avatarTextColor: avatarTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PatientNameRow(
                          patientName: patientName,
                          patientGender: patientGender,
                          age: patient.age,
                          avatarBgColor: avatarBgColor,
                          avatarTextColor: avatarTextColor,
                        ),
                        const SizedBox(height: 4),
                        _PatientDetailRow(patient: patient),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PatientActionButtons(
                    canEdit: canEdit,
                    canDelete: canDelete,
                    onView: onView,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onEditPermissionDenied: onEditPermissionDenied,
                    onDeletePermissionDenied: onDeletePermissionDenied,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  final String patientName;
  final Color avatarBgColor;
  final Color avatarTextColor;

  const _PatientAvatar({
    Key? key,
    required this.patientName,
    required this.avatarBgColor,
    required this.avatarTextColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [avatarBgColor, avatarBgColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: avatarTextColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          patientName.isNotEmpty ? patientName[0] : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: avatarTextColor,
          ),
        ),
      ),
    );
  }
}

class _PatientNameRow extends StatelessWidget {
  final String patientName;
  final String patientGender;
  final int age;
  final Color avatarBgColor;
  final Color avatarTextColor;

  const _PatientNameRow({
    Key? key,
    required this.patientName,
    required this.patientGender,
    required this.age,
    required this.avatarBgColor,
    required this.avatarTextColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          patientName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: avatarBgColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: avatarTextColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                patientGender == '女' ? Icons.female : Icons.male,
                size: 11,
                color: avatarTextColor,
              ),
              const SizedBox(width: 3),
              Text(
                '$age岁',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: avatarTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientDetailRow extends StatelessWidget {
  final Patient patient;

  const _PatientDetailRow({Key? key, required this.patient}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final address = patient.address;
    return Row(
      children: [
        if (patient.medicalRecordNumber != null) ...[
          _InfoChip(
            icon: Icons.badge,
            value: '${patient.medicalRecordNumber}',
            color: tokens.primaryAccent,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          flex: 2,
          child: _InfoChip(
            icon: Icons.phone,
            value: _getDisplayPhone(patient.phone),
            color: tokens.success,
            textColor: tokens.success,
            flexibleValue: true,
          ),
        ),
        const SizedBox(width: 6),
        _InfoChip(
          icon: Icons.event,
          value: DateFormat('yyyy-MM-dd').format(patient.firstVisitDate),
          color: tokens.info,
        ),
        if (address != null && address.isNotEmpty) ...[
          const SizedBox(width: 6),
          Flexible(
            flex: 3,
            child: _InfoChip(
              icon: Icons.location_on,
              value: address,
              color: tokens.warning,
              textColor: tokens.warning,
              flexibleValue: true,
            ),
          ),
        ],
      ],
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
        LogManager.e('PatientListItem', '解析电话号码JSON失败', error: e);
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final Color? textColor;
  final bool flexibleValue;

  const _InfoChip({
    Key? key,
    required this.icon,
    required this.value,
    required this.color,
    this.textColor,
    this.flexibleValue = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textColor ?? color,
      ),
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          if (flexibleValue) Flexible(child: valueText) else valueText,
        ],
      ),
    );
  }
}
