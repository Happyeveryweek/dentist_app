import 'package:flutter/material.dart';

/// 财务表头单元格组件
/// 用于显示表头的图标和标签
class FinancialHeaderCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final MainAxisAlignment alignment;

  const FinancialHeaderCell({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
