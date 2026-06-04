import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

/// 患者统计栏组件
/// 职责：显示患者统计信息
class PatientStatsBar extends StatelessWidget {
  final int totalCount;
  final int currentCount;
  final int currentPage;
  final bool hasMoreData;
  final String searchQuery;
  final bool isDateRangeFiltering;

  const PatientStatsBar({
    super.key,
    required this.totalCount,
    required this.currentCount,
    required this.currentPage,
    required this.hasMoreData,
    required this.searchQuery,
    required this.isDateRangeFiltering,
  });

  @override
  Widget build(BuildContext context) {
    String pageInfo = '';
    if (searchQuery.isEmpty && hasMoreData && !isDateRangeFiltering) {
      pageInfo = '第$currentPage页 | ';
    }

    String filterInfo = '';
    if (searchQuery.isNotEmpty) {
      filterInfo = '搜索结果 | ';
    } else if (isDateRangeFiltering) {
      filterInfo = '时间筛选 | ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.cardBackground,
      child: Row(
        children: [
          Text(
            '共 $totalCount 位患者',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '$filterInfo$pageInfo当前显示: $currentCount 位',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
