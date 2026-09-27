import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/patient.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../widgets/hoverable_list_card.dart';
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
    final tokens = context.tokens;
    final colors = context.colors;
    return HoverableListCard(
      onTap: onEdit,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 12,
      child: Row(
        children: [
          // 病历号列
          SizedBox(
            width: 90,
            child: FinancialDataCell(
              value: '${patient.medicalRecordNumber ?? '未设置'}',
              color: tokens.warning,
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
              color: colors.onSurface,
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
              color: tokens.secondaryAccent,
            ),
          ),
          const SizedBox(width: 12),

          // 最近就诊列
          Expanded(
            flex: 2,
            child: FinancialDateCell(
              date: record.updatedAt,
              icon: Icons.update,
              color: tokens.primaryAccent,
            ),
          ),
          const SizedBox(width: 12),

          // 收费项目列
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.successContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: tokens.success.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services, size: 14, color: tokens.success),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.success,
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
            child: _buildPaymentMethodCell(tokens),
          ),
          const SizedBox(width: 12),

          // 应收费列
          Expanded(
            flex: 2,
            child: FinancialAmountCell(
              amount: item.itemPrice * item.quantity,
              icon: Icons.request_quote,
              color: tokens.primaryAccent,
              bgColor: tokens.primaryAccent.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 12),

          // 已收费列
          Expanded(
            flex: 2,
            child: FinancialAmountCell(
              amount: item.totalPrice,
              icon: Icons.check_circle,
              color: tokens.success,
              bgColor: tokens.successContainer,
            ),
          ),
          const SizedBox(width: 12),

          // 加工费列
          Expanded(
            flex: 2,
            child: FinancialAmountCell(
              amount: item.processingFee,
              icon: Icons.build,
              color: tokens.warning,
              bgColor: tokens.warningContainer,
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
                  color: tokens.primaryAccent,
                  tooltip: '编辑',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
                // 删除按钮
                FinancialActionButton(
                  icon: Icons.delete_rounded,
                  color: tokens.error,
                  tooltip: '删除',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCell(AppThemeTokens tokens) {
    final iconPath =
        FinancialPaymentMethodHelper.iconAssetPathOrNull(item.paymentMethod);

    if (iconPath == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border, width: 1),
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
