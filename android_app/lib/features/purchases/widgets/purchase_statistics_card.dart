import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 采购统计信息卡片组件
/// 职责：显示采购记录的统计信息（总记录、总金额、总采购量、材料种类）
class PurchaseStatisticsCard extends StatelessWidget {
  final Map<String, dynamic> statistics;
  final VoidCallback? onTap;

  const PurchaseStatisticsCard({
    super.key,
    required this.statistics,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总记录',
                    '${statistics['totalRecords'] ?? 0}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总金额',
                    '¥${NumberFormat('#,##0.00').format(statistics['totalAmount'] ?? 0.0)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总采购量',
                    '${statistics['totalQuantity'] ?? 0}',
                    Icons.inventory,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '材料种类',
                    '${statistics['materialCount'] ?? 0}',
                    Icons.category,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建统计项目
  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
