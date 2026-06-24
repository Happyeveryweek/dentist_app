import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 信息项组件
class InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool expanded;

  const InfoItem({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return expanded ? Expanded(child: content) : content;
  }
}
