import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:dentist_app/features/appointments/services/latest_patient_teeth.dart';
import 'package:dentist_app/theme/app_theme.dart';

class TreatmentInfoDisplay extends StatelessWidget {
  final String treatmentTypeJson;

  const TreatmentInfoDisplay({super.key, required this.treatmentTypeJson});

  @override
  Widget build(BuildContext context) {
    final treatmentData = _decodeTreatmentData(treatmentTypeJson);
    final treatments = treatmentData?['treatments'];
    final teeth = appointmentTeethForDisplay(treatmentTypeJson);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              CupertinoIcons.bandage,
              size: 18,
              color: AppTheme.secondaryTextColor,
            ),
            SizedBox(width: 8),
            Text(
              '治疗信息:',
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(left: 26),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '牙位情况:',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: '从医生视角看患者：显示的是患者的实际牙位（右上、左上、右下、左下）',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < teeth.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _buildTeethDataRow(teeth[index], index + 1),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (treatments is List && treatments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '治疗项目: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    treatments.join('、'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (treatmentData == null && treatmentTypeJson.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 8),
            child: Text(
              treatmentTypeJson,
              style: const TextStyle(fontSize: 14, color: AppTheme.textColor),
            ),
          ),
      ],
    );
  }

  Map<String, dynamic>? _decodeTreatmentData(String source) {
    if (source.trim().isEmpty) return null;
    try {
      final decoded = json.decode(source);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Widget _buildTeethDataRow(Map<String, dynamic> teethData, int groupNumber) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '牙位 $groupNumber',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        _buildTeethCrossWidget(teethData),
      ],
    );
  }

  Widget _buildTeethCrossWidget(Map<String, dynamic> teethData) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final centerX = width / 2;
          final centerY = height / 2;

          return CustomPaint(
            painter: _TeethCrossPainter(),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.only(right: 2, bottom: 1),
                    child: Text(
                      teethData['topLeft']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.only(left: 2, bottom: 1),
                    child: Text(
                      teethData['topRight']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 2, top: 1),
                    child: Text(
                      teethData['bottomLeft']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.only(left: 2, top: 1),
                    child: Text(
                      teethData['bottomRight']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeethCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.blue.shade600
          ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paint);

    // 与添加预约的十字一致：竖线长度为宽度的一半，不拉满格子高度。
    final verticalLineLength = size.width / 2;
    final verticalStartY = centerY - verticalLineLength / 2;
    final verticalEndY = centerY + verticalLineLength / 2;
    canvas.drawLine(
      Offset(centerX, verticalStartY),
      Offset(centerX, verticalEndY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
