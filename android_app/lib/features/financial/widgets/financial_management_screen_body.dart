import 'package:flutter/material.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../features/financial/services/financial_calculator.dart';
import 'financial_search_bar.dart';
import 'financial_statistics_card.dart';
import 'financial_record_card.dart';

class FinancialManagementScreenBody extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final Map<String, dynamic> globalStats;
  final bool isStatsLoading;
  final TextEditingController searchController;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<String> onSearchChanged;
  final List<FinancialRecord> financialRecords;
  final List<FinancialRecord> filteredRecords;
  final Map<int, List<FinancialItem>> recordItemsMap;
  final int totalRecordsInDatabase;
  final int currentPage;
  final bool hasMoreData;
  final bool isLoadingMore;
  final bool isSearchMode;
  final ScrollController scrollController;
  final VoidCallback onShowStatistics;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onSortPressed;
  final VoidCallback onDateFilterPressed;
  final ValueChanged<String> onPresetDateFilter;
  final VoidCallback onClearDateFilter;
  final Future<void> Function() onRefresh;
  final VoidCallback? onReconnect;
  final void Function(FinancialRecord) onShowRecordDetails;
  final void Function(FinancialRecord) onDeleteRecord;

  const FinancialManagementScreenBody({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.globalStats,
    required this.isStatsLoading,
    required this.searchController,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onSearchChanged,
    required this.financialRecords,
    required this.filteredRecords,
    required this.recordItemsMap,
    required this.totalRecordsInDatabase,
    required this.currentPage,
    required this.hasMoreData,
    required this.isLoadingMore,
    required this.isSearchMode,
    required this.scrollController,
    required this.onShowStatistics,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSortPressed,
    required this.onDateFilterPressed,
    required this.onPresetDateFilter,
    required this.onClearDateFilter,
    required this.onRefresh,
    this.onReconnect,
    required this.onShowRecordDetails,
    required this.onDeleteRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FinancialStatisticsCard(
          globalStats: globalStats,
          isStatsLoading: isStatsLoading,
          onTap: onShowStatistics,
        ),
        FinancialSearchBar(
          searchController: searchController,
          searchQuery: searchQuery,
          startDate: startDate,
          endDate: endDate,
          onSearchChanged: onSearchChanged,
          onSearchSubmitted: onSearchSubmitted,
          onClearSearch: onClearSearch,
          onSortPressed: onSortPressed,
          onDateFilterPressed: onDateFilterPressed,
          onPresetDateFilter: onPresetDateFilter,
          onClearDateFilter: onClearDateFilter,
        ),
        Expanded(
          child:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hasError
                  ? _buildErrorWidget()
                  : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: _buildFinancialRecordsList(context),
                  ),
        ),
      ],
    );
  }

  Widget _buildFinancialRecordsList(BuildContext context) {
    if (filteredRecords.isEmpty) {
      if (financialRecords.isEmpty) {
        return const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 420,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无财务记录',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 420,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '没有找到匹配的患者',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  '请尝试其他搜索关键词',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.grey[50],
          child: Row(
            children: [
              Text(
                isSearchMode
                    ? '搜索结果: ${filteredRecords.length} 条'
                    : '共 $totalRecordsInDatabase 条记录',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Spacer(),
              if (!isSearchMode)
                Text(
                  '第$currentPage页 | 已显示 ${filteredRecords.length} 条',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
            ],
          ),
        ),
        if (isLoadingMore)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '正在加载更多数据...',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount:
                filteredRecords.length +
                (hasMoreData && !isSearchMode && !isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filteredRecords.length) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '已显示 ${filteredRecords.length} / $totalRecordsInDatabase 条，向下滚动加载更多',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              final record = filteredRecords[index];
              final recordId = record.id;
              final List<FinancialItem> items =
                  recordId == null ? [] : recordItemsMap[recordId] ?? [];
              final totalReceivable =
                  FinancialCalculator.calculatePatientLatestReceivableAmount(
                    record.patientId,
                    financialRecords,
                    recordItemsMap,
                  );
              final totalCollected =
                  FinancialCalculator.calculatePatientLatestCollectedAmount(
                    record.patientId,
                    financialRecords,
                    recordItemsMap,
                  );
              final totalOutstanding = totalReceivable - totalCollected;

              return FinancialRecordCard(
                record: record,
                items: items,
                totalReceivable: totalReceivable,
                totalCollected: totalCollected,
                totalOutstanding: totalOutstanding,
                onTap: () => onShowRecordDetails(record),
                onViewDetails: () => onShowRecordDetails(record),
                onDelete: () => onDeleteRecord(record),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(fontSize: 18, color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: onRefresh, child: const Text('重试')),
                if (onReconnect != null &&
                    (errorMessage.contains('数据库连接') ||
                        errorMessage.contains('Socket') ||
                        errorMessage.contains('Cannot write to socket'))) ...[
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: onReconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重新连接'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
