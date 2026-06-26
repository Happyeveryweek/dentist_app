import 'package:flutter/material.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../providers/financial_provider.dart';
import 'financial_statistics_dialog.dart';

/// 渐进式统计图表对话框包装器
/// 先用初步数据显示图表，后台继续加载全量数据并刷新
class ProgressiveStatisticsDialog extends StatefulWidget {
  final FinancialProvider financialProvider;
  final List<FinancialRecord> initialRecords;
  final Map<int, List<FinancialItem>> initialItemsMap;

  const ProgressiveStatisticsDialog({
    super.key,
    required this.financialProvider,
    required this.initialRecords,
    required this.initialItemsMap,
  });

  @override
  State<ProgressiveStatisticsDialog> createState() =>
      ProgressiveStatisticsDialogState();
}

class ProgressiveStatisticsDialogState
    extends State<ProgressiveStatisticsDialog> {
  List<FinancialRecord> _records = [];
  Map<int, List<FinancialItem>> _itemsMap = {};

  @override
  void initState() {
    super.initState();
    _records = List.from(widget.initialRecords);
    _itemsMap = Map.from(widget.initialItemsMap);
    // 监听 provider，后台任务完成时自动更新图表
    widget.financialProvider.addListener(_onProviderUpdated);
    // 如果已有完整缓存，立即用
    _applyFullCacheIfAvailable();
  }

  @override
  void dispose() {
    widget.financialProvider.removeListener(_onProviderUpdated);
    super.dispose();
  }

  void _applyFullCacheIfAvailable() {
    final cachedFullItemsMap = widget.financialProvider.cachedFullItemsMap;
    if (widget.financialProvider.hasFullItemsCache && cachedFullItemsMap != null) {
      final allRecords = widget.financialProvider.cachedRecords;
      if (mounted) {
        setState(() {
          _records = allRecords;
          _itemsMap = cachedFullItemsMap;
        });
      }
    }
  }

  void _onProviderUpdated() {
    if (!mounted) return;
    // provider 后台任务每批完成都会 notifyListeners，这里更新图表
    final cachedFullItemsMap = widget.financialProvider.cachedFullItemsMap;
    if (cachedFullItemsMap != null) {
      final allRecords = widget.financialProvider.cachedRecords;
      setState(() {
        _records = allRecords;
        _itemsMap = cachedFullItemsMap;
      });
    }
  }

  bool get _isLoadingMore => widget.financialProvider.isBackgroundLoadingFull;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FinancialStatisticsDialog(
          key: ValueKey(_records.length), // 记录数变化时重建图表
          financialRecords: _records,
          recordItemsMap: _itemsMap,
          financialProvider: widget.financialProvider,
        ),
        if (_isLoadingMore)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '加载中...',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
