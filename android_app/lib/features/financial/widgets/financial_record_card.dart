import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/single_line_amount_text.dart';

/// 财务记录卡片组件
/// 职责：显示单个财务记录的卡片
class FinancialRecordCard extends StatelessWidget {
  final FinancialRecord record;
  final List<FinancialItem> items;
  final double totalReceivable;
  final double totalCollected;
  final double totalOutstanding;
  final Function() onTap;
  final Function() onViewDetails;
  final Function() onDelete;

  const FinancialRecordCard({
    super.key,
    required this.record,
    required this.items,
    required this.totalReceivable,
    required this.totalCollected,
    required this.totalOutstanding,
    required this.onTap,
    required this.onViewDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final patientName =
        record.patientName?.trim().isNotEmpty == true
            ? record.patientName ?? ''
            : '未知患者';
    final isSettled = totalOutstanding <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: '病历号: ${record.patientId}',
                        child: Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSettled ? Colors.green[100] : Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSettled ? '已结清' : '未结清',
                        style: TextStyle(
                          color:
                              isSettled
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SingleLineAmountText(
                              text:
                                  '应收费: ¥${NumberFormat('#,##0').format(totalReceivable)}',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SingleLineAmountText(
                              text:
                                  '已收费: ¥${NumberFormat('#,##0').format(totalCollected)}',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.pending,
                            size: 16,
                            color: Colors.orange[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SingleLineAmountText(
                              text:
                                  '欠费: ¥${NumberFormat('#,##0').format(totalOutstanding)}',
                              style: TextStyle(
                                color:
                                    totalOutstanding > 0
                                        ? Colors.red[600]
                                        : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.list, size: 16, color: Colors.purple[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SingleLineAmountText(
                              text: '项目数: ${items.length}',
                              style: TextStyle(
                                color: Colors.purple[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (record.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '备注: ${record.notes}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '创建时间: ${DateFormat('yyyy-MM-dd').format(record.createdAt)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.visibility,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          onPressed: onViewDetails,
                          tooltip: '查看详情',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: onDelete,
                          tooltip: '删除记录',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
