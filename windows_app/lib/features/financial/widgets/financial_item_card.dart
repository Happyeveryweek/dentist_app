import 'package:flutter/material.dart';
import '../../../models/patient.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../helpers/financial_payment_method_helper.dart';
import 'financial_data_cell.dart';
import 'financial_date_cell.dart';
import 'financial_amount_cell.dart';
import 'financial_action_button.dart';

/// 财务项目卡片组件
/// 用于显示单个财务项目的详细信息
class FinancialItemCard extends StatelessWidget {
  final Patient patient;
  final FinancialRecord record;
  final FinancialItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FinancialItemCard({
    super.key,
    required this.patient,
    required this.record,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 病历号列
                SizedBox(
                  width: 90,
                  child: FinancialDataCell(
                    value: '${patient.medical_record_number ?? '未设置'}',
                    color: Colors.orange[700]!,
                    isBold: true,
                    fontSize: 13,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),

                // 患者姓名列
                Expanded(
                  flex: 2,
                  child: FinancialDataCell(
                    value: patient.name,
                    color: Colors.black87,
                    isBold: true,
                    fontSize: 14,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),

                // 收费日期列
                Expanded(
                  flex: 2,
                  child: FinancialDateCell(
                    date: item.chargeDate,
                    icon: Icons.event,
                    color: Colors.teal[600]!,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 最近更新列
                Expanded(
                  flex: 2,
                  child: FinancialDateCell(
                    date: record.updatedAt,
                    icon: Icons.update,
                    color: Colors.indigo[600]!,
                  ),
                ),
                const SizedBox(width: 12),

                // 收费项目列
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_services, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.itemName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[900],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 收费方式列
                SizedBox(
                  width: 110,
                  child: _buildPaymentMethodCell(),
                ),
                const SizedBox(width: 12),

                // 应收费列
                Expanded(
                  flex: 2,
                  child: FinancialAmountCell(
                    amount: item.itemPrice * (item.quantity ?? 1),
                    icon: Icons.request_quote,
                    color: Colors.blue[700]!,
                    bgColor: Colors.blue[50]!,
                  ),
                ),
                const SizedBox(width: 12),

                // 已收费列
                Expanded(
                  flex: 2,
                  child: FinancialAmountCell(
                    amount: item.totalPrice,
                    icon: Icons.check_circle,
                    color: Colors.green[700]!,
                    bgColor: Colors.green[50]!,
                  ),
                ),
                const SizedBox(width: 12),

                // 加工费列
                Expanded(
                  flex: 2,
                  child: FinancialAmountCell(
                    amount: item.processingFee,
                    icon: Icons.build,
                    color: Colors.orange[700]!,
                    bgColor: Colors.orange[50]!,
                  ),
                ),
                const SizedBox(width: 12),

                // 操作列
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 编辑按钮
                      FinancialActionButton(
                        icon: Icons.edit_rounded,
                        color: Colors.blue[600]!,
                        tooltip: '编辑',
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 8),
                      // 删除按钮
                      FinancialActionButton(
                        icon: Icons.delete_rounded,
                        color: Colors.red[600]!,
                        tooltip: '删除',
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCell() {
    final iconPath =
        FinancialPaymentMethodHelper.iconAssetPathOrNull(item.paymentMethod);

    if (iconPath == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: FinancialPaymentMethodHelper.displayNameOrDefault(
              item.paymentMethod,
            ),
            child: SizedBox(
              width: 14,
              height: 14,
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
