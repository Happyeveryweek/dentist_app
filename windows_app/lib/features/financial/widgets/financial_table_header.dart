import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'financial_header_cell.dart';

/// 财务表头组件
/// 用于显示财务记录表格的表头
class FinancialTableHeader extends StatelessWidget {
  const FinancialTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final chartColors = tokens.chartPalette;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.primaryAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tokens.primaryAccent.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 病历号列
          SizedBox(
            width: 90,
            child: FinancialHeaderCell(
              icon: Icons.badge,
              label: '病历号',
              color: tokens.warning,
              alignment: MainAxisAlignment.center,
            ),
          ),
          const SizedBox(width: 12),
          // 患者姓名列
          Expanded(
            flex: 2,
            child: FinancialHeaderCell(
              icon: Icons.person,
              label: '患者姓名',
              color: tokens.primaryAccent,
              alignment: MainAxisAlignment.center,
            ),
          ),
          const SizedBox(width: 12),
          // 收费日期列
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: chartColors[2 % chartColors.length].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: chartColors[2 % chartColors.length].withValues(alpha: 0.3), width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.calendar_today,
                label: '收费日期',
                color: chartColors[2 % chartColors.length],
                alignment: MainAxisAlignment.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 最近更新列
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.primaryAccent.withValues(alpha: 0.3), width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.update,
                label: '最近更新',
                color: tokens.primaryAccent,
                alignment: MainAxisAlignment.center,
              ),
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
                border: Border.all(color: tokens.success.withValues(alpha: 0.3), width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.medical_services,
                label: '收费项目',
                color: tokens.success,
                alignment: MainAxisAlignment.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 收费方式列
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: chartColors[4 % chartColors.length].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: chartColors[4 % chartColors.length].withValues(alpha: 0.3), width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.payments,
                label: '收费方式',
                color: chartColors[4 % chartColors.length],
                alignment: MainAxisAlignment.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 应收费列
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.primaryAccent.withValues(alpha: 0.3), width: 1),
                ),
                child: FinancialHeaderCell(
                  icon: Icons.request_quote,
                  label: '应收费',
                  color: tokens.primaryAccent,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 已收费列
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.successContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.success.withValues(alpha: 0.3), width: 1),
                ),
                child: FinancialHeaderCell(
                  icon: Icons.payments,
                  label: '已收费',
                  color: tokens.success,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 加工费列
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.warningContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.warning.withValues(alpha: 0.3), width: 1),
                ),
                child: FinancialHeaderCell(
                  icon: Icons.build,
                  label: '加工费',
                  color: tokens.warning,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 操作列
          SizedBox(
            width: 100,
            child: FinancialHeaderCell(
              icon: Icons.settings,
              label: '操作',
              color: context.colors.onSurface,
              alignment: MainAxisAlignment.center,
            ),
          ),
        ],
      ),
    );
  }
}
