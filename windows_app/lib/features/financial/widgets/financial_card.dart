import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/patient.dart';
import '../../../models/financial_record.dart';
import '../../../widgets/dental_icons.dart';
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
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final updateDate = lastFinancialUpdateDate;
    return HoverableFinancialListCard(
      onTap: onTap,
      child: Row(
        children: [
          // 左侧：头像
          DentalAvatar(
            gender: patient.gender,
            name: patient.name,
            size: 40,
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
                        color: tokens.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge,
                            size: 11,
                            color: tokens.primaryAccent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${patient.medicalRecordNumber ?? '未设置'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: tokens.primaryAccent,
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
                        label: DateFormat('yy-MM-dd')
                            .format(patient.firstVisitDate),
                        color: tokens.secondaryAccent,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 最近更新
                    if (updateDate != null)
                      Flexible(
                        flex: 2,
                        child: FinancialCompactTag(
                          icon: Icons.update,
                          label: DateFormat('yy-MM-dd')
                              .format(updateDate),
                          color: tokens.warning,
                        ),
                      ),
                    const SizedBox(width: 4),

                    // 应收费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.account_balance_wallet,
                        label:
                            '¥${(totalCost % 1 == 0 ? totalCost.toInt().toString() : totalCost.toStringAsFixed(0))}',
                        color: tokens.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 已收费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.check_circle,
                        label:
                            '¥${(received % 1 == 0 ? received.toInt().toString() : received.toStringAsFixed(0))}',
                        color: tokens.success,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 加工费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.build,
                        label:
                            '¥${(fee % 1 == 0 ? fee.toInt().toString() : fee.toStringAsFixed(0))}',
                        color: tokens.warning,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 欠费
                    Flexible(
                      flex: 2,
                      child: FinancialCompactTag(
                        icon: Icons.pending,
                        label:
                            '¥${(debt % 1 == 0 ? debt.toInt().toString() : debt.toStringAsFixed(0))}',
                        color: debt > 0 ? tokens.error : tokens.textMuted,
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
                color: tokens.primaryAccent,
                tooltip: '查看',
                onPressed: onTap,
              ),

              const SizedBox(width: 6),

              // 编辑按钮
              FinancialCompactActionButton(
                icon: Icons.edit,
                color: tokens.warning,
                tooltip: '编辑',
                onPressed: onEdit,
              ),

              const SizedBox(width: 6),

              // 删除按钮
              FinancialCompactActionButton(
                icon: Icons.delete,
                color: tokens.error,
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
