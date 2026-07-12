import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'default_avatar_icon.dart';

/// 欢迎区域组件
class WelcomeSection extends StatelessWidget {
  final String currentUserName;
  final Uint8List? currentUserAvatar;
  final int todayAppointmentsCount;
  final int totalAppointmentsCount;
  final Animation<double> fadeAnimation;

  const WelcomeSection({
    super.key,
    required this.currentUserName,
    this.currentUserAvatar,
    required this.todayAppointmentsCount,
    required this.totalAppointmentsCount,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserAvatar = this.currentUserAvatar;
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = '早上好';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour < 18) {
      greeting = '下午好';
      greetingIcon = Icons.wb_sunny_outlined;
    } else {
      greeting = '晚上好';
      greetingIcon = Icons.nightlight_round;
    }

    return FadeTransition(
      opacity: fadeAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.dashboardWelcomeBorder.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.dashboardWelcomeShadow.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/login_clinical_console.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.28),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.86),
                        AppTheme.dashboardWelcomeSurfaceBlue.withValues(
                          alpha: 0.68,
                        ),
                        AppTheme.dashboardWelcomeSurfacePurple.withValues(
                          alpha: 0.72,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: AppTheme.dashboardWelcomeBorder
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Icon(
                                      greetingIcon,
                                      color: AppTheme.dashboardWelcomeAccent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '$greeting${currentUserName.isNotEmpty ? '，$currentUserName' : ''}',
                                      style: const TextStyle(
                                        color:
                                            AppTheme
                                                .dashboardWelcomePrimaryText,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 44),
                                child: Text(
                                  DateFormat(
                                    'MM月dd日 EEEE',
                                    'zh_CN',
                                  ).format(now),
                                  style: const TextStyle(
                                    color:
                                        AppTheme.dashboardWelcomeSecondaryText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.dashboardWelcomeShadow
                                    .withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child:
                              currentUserAvatar != null &&
                                      currentUserAvatar.isNotEmpty
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      currentUserAvatar,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const DefaultAvatarIcon();
                                      },
                                    ),
                                  )
                                  : const DefaultAvatarIcon(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.dashboardWelcomeShadow.withValues(
                              alpha: 0.12,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.infoColor,
                                  AppTheme.dashboardWelcomeAccentPurple,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.event_note_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '今日预约',
                                  style: TextStyle(
                                    color:
                                        AppTheme.dashboardWelcomeSecondaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$todayAppointmentsCount 个',
                                  style: const TextStyle(
                                    color: AppTheme.dashboardWelcomePrimaryText,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (totalAppointmentsCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.dashboardWelcomeSurfaceBlue
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.dashboardWelcomeBorder
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              child: Text(
                                '${((todayAppointmentsCount / totalAppointmentsCount) * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppTheme.dashboardWelcomeAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
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
}
