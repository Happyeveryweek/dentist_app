import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/patient.dart';
import '../../../models/financial_record.dart';
import '../../../theme/app_theme.dart';
import 'financial_compact_tag.dart';
import 'financial_compact_action_button.dart';
import 'financial_hoverable_cards.dart';

/// 财务卡片组件
/// 用于显示患者财务信息卡片
class FinancialCard extends StatelessWidget {
  final Patient patient;
  final FinancialRecord record;
  final double totalCost;
  final DateTime? lastFinancialUpdateDate;
  final double? receivedSum;
  final double? processingSum;
  final double fee;
  final double received;
  final double debt;
  final Color avatarBackgroundColor;
  final VoidCallback onTap;
  final Future<bool?> Function() onEdit;
  final VoidCallback onDelete;

  const FinancialCard({
    super.key,
    required this.patient,
    required this.record,
    required this.totalCost,
    this.lastFinancialUpdateDate,
    this.receivedSum,
    this.processingSum,
    required this.fee,
    required this.received,
    required this.debt,
    required this.avatarBackgroundColor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return HoverableFinancialListCard(
      onTap: onTap,
      child: Row(
        children: [
          // 左侧：头像
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarBackgroundColor,
            child: Text(
              patient.name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 中间：患者信息和财务数据
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一行：患者姓名 + 病历号
                Row(
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge,
                            size: 11,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${patient.medical_record_number ?? '未设置'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // 第二行：财务信息标签
                Row(
                  children: [
                    // 首诊日期
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.calendar_today,
                        label: DateFormat('yy-MM-dd').format(patient.first_visit_date),
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 4),
                    
                    // 最近更新
                    if (lastFinancialUpdateDate != null)
                      Flexible(
                        flex: 2,
                        child: FinancialCompactTag(
                          icon: Icons.update,
                          label: DateFormat('yy-MM-dd').format(lastFinancialUpdateDate!),
                          color: Colors.orange,
                        ),
                      ),
                    const SizedBox(width: 4),
                    
                    // 应收费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.account_balance_wallet,
                        label: '¥${(totalCost % 1 == 0 ? totalCost.toInt().toString() : totalCost.toStringAsFixed(0))}',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    
                    // 已收费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.check_circle,
                        label: '¥${(received % 1 == 0 ? received.toInt().toString() : received.toStringAsFixed(0))}',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 4),
                    
                    // 加工费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.build,
                        label: '¥${(fee % 1 == 0 ? fee.toInt().toString() : fee.toStringAsFixed(0))}',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    
                    // 欠费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.pending,
                        label: '¥${(debt % 1 == 0 ? debt.toInt().toString() : debt.toStringAsFixed(0))}',
                        color: debt > 0 ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 右侧：操作按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 查看按钮
              FinancialCompactActionButton(
                icon: Icons.visibility,
                color: Colors.blue,
                tooltip: '查看',
                onPressed: onTap,
              ),
              
              const SizedBox(width: 6),
              
              // 编辑按钮
              FinancialCompactActionButton(
                icon: Icons.edit,
                color: Colors.orange,
                tooltip: '编辑',
                onPressed: onEdit,
              ),
              
              const SizedBox(width: 6),
              
              // 删除按钮
              FinancialCompactActionButton(
                icon: Icons.delete,
                color: Colors.red,
                tooltip: '删除',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
