import 'package:flutter/material.dart';
import 'financial_stat_item.dart';

/// 财务统计区域组件
/// 用于显示财务统计信息和分页信息
class FinancialStatsSection extends StatelessWidget {
  final int totalRecords;
  final int totalPatients;
  final int currentPage;
  final int totalPages;
  final int recordsPerPage;

  const FinancialStatsSection({
    super.key,
    required this.totalRecords,
    required this.totalPatients,
    required this.currentPage,
    required this.totalPages,
    required this.recordsPerPage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: FinancialStatItem(
                  icon: Icons.receipt_long,
                  label: '总记录数',
                  value: totalRecords.toString(),
                  color: Colors.blue.shade700,
                ),
              ),
              Expanded(
                child: FinancialStatItem(
                  icon: Icons.people,
                  label: '涉及患者',
                  value: totalPatients.toString(),
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),

        // 分页信息显示
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pages_rounded,
                  color: Colors.blue[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '第 $currentPage 页，共 $totalPages 页',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '每页显示 $recordsPerPage 条记录',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
