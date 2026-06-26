import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
                          Icon(
                            greetingIcon,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$greeting${currentUserName.isNotEmpty ? '，$currentUserName' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MM月dd日 EEEE', 'zh_CN').format(now),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child:
                      currentUserAvatar != null && currentUserAvatar.isNotEmpty
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              currentUserAvatar,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: Color(0xFF1A73E8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日预约',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$todayAppointmentsCount 个',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalAppointmentsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${((todayAppointmentsCount / totalAppointmentsCount) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFF1A73E8),
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
    );
  }
}
