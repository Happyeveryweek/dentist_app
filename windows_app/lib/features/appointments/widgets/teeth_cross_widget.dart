import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class CrossPainter extends CustomPainter {
  final Color lineColor;

  const CrossPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5;

    // 绘制水平线 - 明显长于竖线（占据整个宽度）
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // 绘制垂直线 - 高度约为三个字符高度
    double verticalHeight = 40; // 恢复原先高度，避免文字溢出
    double startY = size.height / 2 - verticalHeight / 2;
    double endY = size.height / 2 + verticalHeight / 2;

    canvas.drawLine(
      Offset(size.width / 2, startY),
      Offset(size.width / 2, endY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TeethCrossWidget extends StatelessWidget {
  final Map<String, String> teethData;
  final int index;

  const TeethCrossWidget({
    required this.teethData,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final crossLineColor = tokens.textMuted.withValues(alpha: 0.45);

    return SizedBox(
      height: 120, // 恢复原始尺寸
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('牙位 ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          _buildCross(crossLineColor),
        ],
      ),
    );
  }

  Widget _buildCross(Color crossLineColor) {
    // 使用固定尺寸而非LayoutBuilder，避免潜在的布局计算问题（恢复原值）
    const double width = 170.0;
    const double height = 90.0;
    const double centerX = width / 2;
    const double centerY = height / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 自定义画笔绘制十字
        CustomPaint(
          size: const Size(width, height),
          painter: CrossPainter(lineColor: crossLineColor),
        ),

        // 上左象限
        Positioned(
          top: centerY - 20, // 更加靠近横线
          left: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              teethData['topLeft'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ),

        // 上右象限
        Positioned(
          top: centerY - 20, // 更加靠近横线
          right: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              teethData['topRight'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.left,
            ),
          ),
        ),

        // 下左象限
        Positioned(
          top: centerY + 3, // 更加靠近横线
          left: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              teethData['bottomLeft'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ),

        // 下右象限
        Positioned(
          top: centerY + 3, // 更加靠近横线
          right: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              teethData['bottomRight'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ],
    );
  }
}
