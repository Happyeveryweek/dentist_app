import 'package:flutter/material.dart';

import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../providers/purchase_provider.dart';
import '../../../utils/datetime_formatter.dart';
import '../../../widgets/modern_date_range_picker.dart';
import '../services/purchase_date_range_service.dart';
import '../services/purchase_data_filter.dart';
import 'purchase_date_range_selector.dart';
import 'purchase_overview_tab.dart';
import 'purchase_trend_tab.dart';
import 'purchase_ranking_tab.dart';

/// 采购统计图表对话框 - 移动端版本
class PurchaseStatisticsDialog extends StatefulWidget {
  final List<PurchaseRecord> purchaseRecords;
  final Map<int, List<PurchaseItem>> recordItemsMap;
  final PurchaseProvider purchaseProvider;

  const PurchaseStatisticsDialog({
    super.key,
    required this.purchaseRecords,
    required this.recordItemsMap,
    required this.purchaseProvider,
  });

  @override
  State<PurchaseStatisticsDialog> createState() => _PurchaseStatisticsDialogState();
}

class _PurchaseStatisticsDialogState extends State<PurchaseStatisticsDialog>
    with SingleTickerProviderStateMixin {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _earliestDate;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDateRange();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeDateRange() {
    final defaultRange = PurchaseDateRangeService.getDefaultDateRange();
    _startDate = defaultRange['start']!;
    _endDate = defaultRange['end']!;
    _earliestDate = PurchaseDateRangeService.getEarliestPurchaseDate(
      widget.purchaseRecords.map((r) => r.purchaseDate).toList(),
    );
  }

  /// 应用预设时间范围
  void _applyPreset(String preset) {
    final newRange = PurchaseDateRangeService.applyPreset(preset, _earliestDate);
    setState(() {
      _startDate = newRange['start']!;
      _endDate = newRange['end']!;
    });
  }

  /// 显示自定义日期选择器
  Future<void> _showCustomDatePicker() async {
    await showDialog(
      context: context,
      builder: (context) => ModernDateRangePicker(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
        firstDate: DateTime(2020),
        lastDate: DateTimeFormatter.nowLocal().add(const Duration(days: 365)),
        onDateRangeSelected: (startDate, endDate) {
          setState(() {
            _startDate = startDate;
            _endDate = endDate;
          });
        },
      ),
    );
  }

  /// 获取过滤后的记录
  List<PurchaseRecord> _getFilteredRecords() {
    return PurchaseDataFilter.getFilteredRecords(
      widget.purchaseRecords,
      _startDate,
      _endDate,
    );
  }

  /// 获取过滤后的采购项目
  List<PurchaseItem> _getFilteredItems() {
    return PurchaseDataFilter.getFilteredItems(
      _getFilteredRecords(),
      widget.recordItemsMap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('采购统计图表'),
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.green[600],
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(text: '概览'),
                      Tab(text: '趋势'),
                      Tab(text: '排行'),
                    ],
                  ),
                ),
              ),
            ),
            body: Column(
              children: [
                // 时间范围选择器
                PurchaseDateRangeSelector(
                  startDate: _startDate,
                  endDate: _endDate,
                  earliestDate: _earliestDate,
                  onPresetApplied: _applyPreset,
                  onCustomDatePicker: _showCustomDatePicker,
                ),
                
                // 内容区域
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      PurchaseOverviewTab(
                        filteredRecords: _getFilteredRecords(),
                        filteredItems: _getFilteredItems(),
                      ),
                      PurchaseTrendTab(
                        filteredRecords: _getFilteredRecords(),
                        startDate: _startDate,
                        endDate: _endDate,
                      ),
                      PurchaseRankingTab(
                        filteredItems: _getFilteredItems(),
                        filteredRecords: _getFilteredRecords(),
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
}
