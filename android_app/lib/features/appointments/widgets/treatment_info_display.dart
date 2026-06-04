import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:dentist_app/theme/app_theme.dart';

class TreatmentInfoDisplay extends StatelessWidget {
  final String treatmentTypeJson;

  const TreatmentInfoDisplay({required this.treatmentTypeJson});

  @override
  Widget build(BuildContext context) {
    try {
      final treatmentData = json.decode(treatmentTypeJson);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.bandage,
                size: 18,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              const Text(
                '治疗信息:',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (treatmentData.containsKey('teethData') &&
              treatmentData['teethData'] is List &&
              (treatmentData['teethData'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 26),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '牙位情况:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
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
                    children: [
                      if ((treatmentData['teethData'] as List).isNotEmpty &&
                          _hasTeethData(treatmentData['teethData'][0]))
                        Expanded(
                          child: _buildTeethDataRow(treatmentData['teethData'][0], 1),
                        ),
                      if ((treatmentData['teethData'] as List).length > 1 &&
                          _hasTeethData(treatmentData['teethData'][1])) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTeethDataRow(treatmentData['teethData'][1], 2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (treatmentData.containsKey('treatments') &&
              treatmentData['treatments'] is List &&
              (treatmentData['treatments'] as List).isNotEmpty) ...[
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
                      (treatmentData['treatments'] as List).join('、'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    } catch (e) {
      return Text(treatmentTypeJson);
    }
  }

  bool _hasTeethData(Map<String, dynamic> teethData) {
    return teethData.entries.any(
      (entry) => entry.value != null && entry.value.toString().isNotEmpty,
    );
  }

  Widget _buildTeethDataRow(Map<String, dynamic> teethData, int groupNumber) {
    if (!_hasTeethData(teethData)) {
      return const SizedBox.shrink();
    }

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
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
    final paint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
