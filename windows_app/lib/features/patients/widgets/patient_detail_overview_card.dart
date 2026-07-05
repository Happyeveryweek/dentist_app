import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../models/patient.dart';

class PatientDetailOverviewCard extends StatelessWidget {
  final Patient patient;

  const PatientDetailOverviewCard({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final identificationNumber = patient.identificationNumber;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.cardBackground,
            tokens.pageBackground.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tokens.primaryAccent.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: tokens.primaryAccent.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            _PatientAvatar(patient: patient),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        patient.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _GenderBadge(gender: patient.gender),
                      const SizedBox(width: 12),
                      _AgeBadge(age: patient.age),
                      const Spacer(),
                      _FirstVisitBadge(date: patient.firstVisitDate),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _OverviewTextRow(
                    icon: Icons.phone_rounded,
                    iconColor: tokens.primaryAccent,
                    backgroundColor:
                        tokens.primaryAccent.withValues(alpha: 0.1),
                    text: patient.displayPhone(),
                    textColor: colors.onSurface,
                  ),
                  const SizedBox(height: 6),
                  if (identificationNumber != null)
                    _OverviewTextRow(
                      icon: Icons.credit_card_rounded,
                      iconColor: tokens.secondaryAccent,
                      backgroundColor:
                          tokens.secondaryAccent.withValues(alpha: 0.1),
                      text: identificationNumber,
                      textColor: colors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  final Patient patient;

  const _PatientAvatar({
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isFemale = patient.gender == '女';
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: isFemale
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.dangerAccent.withValues(alpha: 0.1),
                  tokens.dangerAccent.withValues(alpha: 0.2),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.primaryAccent.withValues(alpha: 0.1),
                  tokens.primaryAccent.withValues(alpha: 0.2),
                ],
              ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isFemale
                ? tokens.dangerAccent.withValues(alpha: 0.3)
                : tokens.primaryAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          patient.name.isNotEmpty ? patient.name[0] : '?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isFemale
                ? tokens.dangerAccent
                : tokens.primaryAccent,
          ),
        ),
      ),
    );
  }
}

class _GenderBadge extends StatelessWidget {
  final String gender;

  const _GenderBadge({
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isFemale = gender == '女';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isFemale
              ? [
                  tokens.dangerAccent.withValues(alpha: 0.1),
                  tokens.dangerAccent.withValues(alpha: 0.2),
                ]
              : [
                  tokens.primaryAccent.withValues(alpha: 0.1),
                  tokens.primaryAccent.withValues(alpha: 0.2),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFemale
              ? tokens.dangerAccent.withValues(alpha: 0.3)
              : tokens.primaryAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFemale
                ? tokens.dangerAccent.withValues(alpha: 0.2)
                : tokens.primaryAccent.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFemale ? Icons.female_rounded : Icons.male_rounded,
            size: 18,
            color: isFemale ? tokens.dangerAccent : tokens.primaryAccent,
          ),
          const SizedBox(width: 6),
          Text(
            gender,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isFemale ? tokens.dangerAccent : tokens.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeBadge extends StatelessWidget {
  final int age;

  const _AgeBadge({
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.successContainer,
              tokens.success.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tokens.success.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.success.withValues(alpha: 0.15),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 16,
              color: tokens.success,
            ),
            const SizedBox(width: 6),
            Text(
              '$age岁',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.success,
              ),
            ),
        ],
      ),
    );
  }
}

class _FirstVisitBadge extends StatelessWidget {
  final DateTime date;

  const _FirstVisitBadge({
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.infoContainer,
            tokens.info.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.info.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.info.withValues(alpha: 0.15),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: tokens.info,
          ),
          const SizedBox(width: 6),
          Text(
            '首诊: ${DateFormat('yyyy-MM-dd').format(date)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.info,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTextRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String text;
  final Color textColor;

  const _OverviewTextRow({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
