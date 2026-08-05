import 'package:flutter/material.dart';

/// 金额等短数值的单行显示组件。
/// 空间不足时缩小内容，避免在移动端卡片和列表中换行。
class SingleLineAmountText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Alignment alignment;

  const SingleLineAmountText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
