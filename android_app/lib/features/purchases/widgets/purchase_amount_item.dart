import 'package:flutter/material.dart';

/// 单个金额统计项组件
class PurchaseAmountItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const PurchaseAmountItem(
    this.label,
    this.value, {
    super.key,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
