import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 牙齿情况区域
///
/// 显示两个牙位图，每个牙位图包含四个输入框（左上、右上、左下、右下）
class TeethConditionSection extends StatelessWidget {
  final List<Map<String, String>> teethData;
  final Function(int, String, String) onTeethDataChanged;

  const TeethConditionSection({
    Key? key,
    required this.teethData,
    required this.onTeethDataChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_services,
                color: colors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '牙齿情况',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: TeethCrossWidget(
                crossIndex: 0,
                teethData: teethData,
                onChanged: onTeethDataChanged,
              )),
              const SizedBox(width: 4),
              Expanded(
                  child: TeethCrossWidget(
                crossIndex: 1,
                teethData: teethData,
                onChanged: onTeethDataChanged,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

/// 牙位图组件
class TeethCrossWidget extends StatelessWidget {
  final int crossIndex;
  final List<Map<String, String>> teethData;
  final Function(int, String, String) onChanged;

  const TeethCrossWidget({
    Key? key,
    required this.crossIndex,
    required this.teethData,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '牙位 ${crossIndex + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: colors.primary,
              ),
            ),
          ),
          Expanded(
            child: TeethCross(
              crossIndex: crossIndex,
              teethData: teethData,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 牙位十字图
class TeethCross extends StatelessWidget {
  final int crossIndex;
  final List<Map<String, String>> teethData;
  final Function(int, String, String) onChanged;

  const TeethCross({
    Key? key,
    required this.crossIndex,
    required this.teethData,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const double width = 120.0;
    const double height = 65.0;
    const double centerX = width / 2;
    const double centerY = height / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(width, height),
          painter: CrossPainter(lineColor: tokens.border),
        ),
        Positioned(
          top: centerY - 20,
          left: 10,
          width: centerX - 12,
          height: 18,
          child: _buildTextField(
            'topLeft',
            TextAlign.right,
            const EdgeInsets.only(right: 4),
          ),
        ),
        Positioned(
          top: centerY - 20,
          right: 10,
          width: centerX - 12,
          height: 18,
          child: _buildTextField(
            'topRight',
            TextAlign.left,
            const EdgeInsets.only(left: 4),
          ),
        ),
        Positioned(
          top: centerY + 3,
          left: 10,
          width: centerX - 12,
          height: 18,
          child: _buildTextField(
            'bottomLeft',
            TextAlign.right,
            const EdgeInsets.only(right: 4),
          ),
        ),
        Positioned(
          top: centerY + 3,
          right: 10,
          width: centerX - 12,
          height: 18,
          child: _buildTextField(
            'bottomRight',
            TextAlign.left,
            const EdgeInsets.only(left: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      String field, TextAlign textAlign, EdgeInsets contentPadding) {
    return TextField(
      textAlign: textAlign,
      textAlignVertical: TextAlignVertical.center,
      cursorHeight: 14,
      cursorWidth: 1.5,
      decoration: InputDecoration(
        isCollapsed: true,
        contentPadding: contentPadding,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: true,
        fillColor: Colors.transparent,
      ),
      style: const TextStyle(fontSize: 12),
      controller: TextEditingController(text: teethData[crossIndex][field]),
      onChanged: (value) {
        onChanged(crossIndex, field, value);
      },
    );
  }
}

/// 牙位十字图绘制器
class CrossPainter extends CustomPainter {
  final Color lineColor;

  const CrossPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 绘制十字线
    canvas.drawLine(
      Offset(centerX, 10),
      Offset(centerX, size.height - 10),
      paint,
    );
    canvas.drawLine(
      Offset(10, centerY),
      Offset(size.width - 10, centerY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
