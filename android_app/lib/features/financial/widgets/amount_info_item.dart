import 'package:flutter/material.dart';

/// 金额信息项组件
/// 职责：显示金额信息项（标题和值）
class AmountInfoItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const AmountInfoItem({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
