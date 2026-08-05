import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/single_line_amount_text.dart';

/// 财务统计信息卡片组件
/// 职责：显示财务统计信息卡片（患者数、记录数、已收费、总欠费、加工费）
class FinancialStatisticsCard extends StatelessWidget {
  final Map<String, dynamic> globalStats;
  final bool isStatsLoading;
  final Function() onTap;

  const FinancialStatisticsCard({
    super.key,
    required this.globalStats,
    required this.isStatsLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final patientCount = globalStats['patientCount'] ?? 0;
    final itemCount = globalStats['itemCount'] ?? 0;
    final totalCollected = (globalStats['totalCollected'] ?? 0.0) as double;
    final totalOutstanding = (globalStats['totalOutstanding'] ?? 0.0) as double;
    final totalProcessingFee =
        (globalStats['totalProcessingFee'] ?? 0.0) as double;
    final statsError = globalStats['_error'] as String?;
    final isPartial = globalStats['_isPartial'] == true;
    final loadedRecordCount = globalStats['_loadedRecordCount'] as int?;
    final isFirstLoad = globalStats.isEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child:
                statsError != null
                    ? SizedBox(
                      height: 56,
                      child: Center(
                        child: Text(
                          statsError,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    )
                    : isFirstLoad
                    ? const SizedBox(
                      height: 56,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                    : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                '患者数',
                                '$patientCount',
                                Icons.people,
                                Colors.purple,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                '记录数',
                                '$itemCount',
                                Icons.receipt_long,
                                Colors.green,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                '已收费',
                                '¥${NumberFormat('#,##0').format(totalCollected)}',
                                Icons.payment,
                                Colors.orange,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                '总欠费',
                                '¥${NumberFormat('#,##0').format(totalOutstanding)}',
                                Icons.money_off,
                                Colors.red.shade700,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                '加工费',
                                '¥${NumberFormat('#,##0').format(totalProcessingFee)}',
                                Icons.build,
                                Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        if (isStatsLoading) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPartial && loadedRecordCount != null
                                    ? '已基于前 $loadedRecordCount 条记录计算，正在加载完整统计...'
                                    : '统计数据加载中...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: SingleLineAmountText(
            text: value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            alignment: Alignment.center,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
