import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/single_line_amount_text.dart';

/// 收费状态图表组件
/// 职责：显示收费状态分布图表
class PaymentStatusChart extends StatelessWidget {
  final double totalCollected;
  final double totalOutstanding;

  const PaymentStatusChart({
    super.key,
    required this.totalCollected,
    required this.totalOutstanding,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = totalCollected + totalOutstanding;

    if (totalAmount <= 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final collectedRate = (totalCollected / totalAmount);
    final outstandingRate = (totalOutstanding / totalAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '收费状态分布',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // 已收费进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '已收费',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[700],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleLineAmountText(
                        text:
                            '¥${NumberFormat('#,##0').format(totalCollected)} (${(collectedRate * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: collectedRate,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade600,
                ),
                minHeight: 8,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 欠费进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '欠费',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.red[700],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleLineAmountText(
                        text:
                            '¥${NumberFormat('#,##0').format(totalOutstanding)} (${(outstandingRate * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: outstandingRate,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                minHeight: 8,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 总计信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '总金额',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleLineAmountText(
                      text: '¥${NumberFormat('#,##0').format(totalAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
