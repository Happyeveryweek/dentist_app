import 'package:flutter/material.dart';
import 'financial_header_cell.dart';

/// 财务表头组件
/// 用于显示财务记录表格的表头
class FinancialTableHeader extends StatelessWidget {
  const FinancialTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.indigo[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
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
              color: Colors.orange[600]!,
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
              color: Colors.blue[700]!,
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
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[200]!, width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.calendar_today,
                label: '收费日期',
                color: Colors.teal[600]!,
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
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo[200]!, width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.update,
                label: '最近更新',
                color: Colors.indigo[600]!,
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
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!, width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.medical_services,
                label: '收费项目',
                color: Colors.green[700]!,
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
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!, width: 1),
              ),
              child: FinancialHeaderCell(
                icon: Icons.payments,
                label: '收费方式',
                color: Colors.purple[700]!,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: FinancialHeaderCell(
                  icon: Icons.request_quote,
                  label: '应收费',
                  color: Colors.blue[700]!,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!, width: 1),
                ),
                child: FinancialHeaderCell(
                  icon: Icons.payments,
                  label: '已收费',
                  color: Colors.green[700]!,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!, width: 1),
                ),
                child: FinancialHeaderCell(
                  icon: Icons.build,
                  label: '加工费',
                  color: Colors.orange[700]!,
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
              color: Colors.grey[700]!,
              alignment: MainAxisAlignment.center,
            ),
          ),
        ],
      ),
    );
  }
}
