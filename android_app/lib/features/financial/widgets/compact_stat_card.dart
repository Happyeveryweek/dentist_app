import 'package:flutter/material.dart';

import '../../../widgets/single_line_amount_text.dart';

/// 紧凑型统计卡片组件
/// 职责：显示紧凑型统计卡片（标题、数值、图标）
class CompactStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String prefix;

  const CompactStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, // 固定高度确保一致性
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 图标和标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // 数值显示 - 统一布局
          Flexible(
            child:
                prefix == '¥'
                    ? SingleLineAmountText(
                      text: '$prefix$value',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                      alignment: Alignment.center,
                    )
                    : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: RichText(
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: value,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            TextSpan(
                              text: prefix,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
