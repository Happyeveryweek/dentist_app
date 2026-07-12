import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/financial_item.dart';
import '../../../models/financial_record.dart';
import '../../../providers/financial_provider.dart';
import 'financial_statistics_dialog.dart';

/// 图表加载过程中的可观察数据快照。
class FinancialStatisticsSnapshot {
  final List<FinancialRecord> records;
  final Map<int, List<FinancialItem>> itemsMap;
  final bool isLoading;
  final int loadedRecordCount;
  final int? totalRecordCount;
  final String? errorMessage;

  const FinancialStatisticsSnapshot({
    required this.records,
    required this.itemsMap,
    required this.isLoading,
    this.loadedRecordCount = 0,
    this.totalRecordCount,
    this.errorMessage,
  });

  const FinancialStatisticsSnapshot.empty()
    : records = const [],
      itemsMap = const {},
      isLoading = true,
      loadedRecordCount = 0,
      totalRecordCount = null,
      errorMessage = null;
}

/// 图表立即打开，随后台统计数据批次刷新。
class ProgressiveStatisticsDialog extends StatelessWidget {
  final FinancialProvider financialProvider;
  final ValueListenable<FinancialStatisticsSnapshot> statisticsListenable;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const ProgressiveStatisticsDialog({
    super.key,
    required this.financialProvider,
    required this.statisticsListenable,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FinancialStatisticsSnapshot>(
      valueListenable: statisticsListenable,
      builder: (context, snapshot, child) {
        return Stack(
          children: [
            FinancialStatisticsDialog(
              key: ValueKey(
                '${snapshot.records.length}-${snapshot.itemsMap.length}',
              ),
              financialRecords: snapshot.records,
              recordItemsMap: snapshot.itemsMap,
              financialProvider: financialProvider,
              initialStartDate: initialStartDate,
              initialEndDate: initialEndDate,
            ),
            if (snapshot.isLoading || snapshot.errorMessage != null)
              Positioned(
                top: 104,
                left: 0,
                right: 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        snapshot.errorMessage != null
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        snapshot.errorMessage != null
                            ? Icons.error_outline
                            : Icons.insights_outlined,
                        size: 16,
                        color:
                            snapshot.errorMessage != null
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          snapshot.errorMessage ??
                              '统计图表正在渐进加载：已完成 ${snapshot.loadedRecordCount}${snapshot.totalRecordCount == null ? '' : ' / ${snapshot.totalRecordCount}'} 条记录。',
                          style: TextStyle(
                            color:
                                snapshot.errorMessage != null
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
