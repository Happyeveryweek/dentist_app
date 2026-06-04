import 'package:flutter/material.dart';

/// 财务数据单元格组件
/// 用于显示表格中的数据单元格
class FinancialDataCell extends StatelessWidget {
  final String value;
  final Color color;
  final bool isBold;
  final double fontSize;
  final TextAlign textAlign;

  const FinancialDataCell({
    super.key,
    required this.value,
    required this.color,
    this.isBold = false,
    this.fontSize = 13,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
