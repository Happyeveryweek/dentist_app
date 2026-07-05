import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../widgets/dental_icons.dart';
import 'teeth_cross_widget.dart';

class AppointmentDetailsTeethSection extends StatelessWidget {
  final List<Map<String, String>> teethData;

  const AppointmentDetailsTeethSection({
    Key? key,
    required this.teethData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tokens.divider.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  DentalIcons.tooth,
                  color: tokens.iconMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '牙齿情况',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            if (teethData.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: teethData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final toothData = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TeethCrossWidget(
                      teethData: {
                        'topLeft': toothData['topLeft'] ?? '',
                        'topRight': toothData['topRight'] ?? '',
                        'bottomLeft': toothData['bottomLeft'] ?? '',
                        'bottomRight': toothData['bottomRight'] ?? '',
                      },
                      index: index,
                    ),
                  );
                }).toList(),
              )
            else
              const Text('暂无牙位信息'),
          ],
        ),
      ),
    );
  }
}
