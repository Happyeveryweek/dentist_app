import 'package:flutter/material.dart';

import '../../../models/purchase_item.dart';
import '../../../models/purchase_record.dart';
import '../../../widgets/single_line_amount_text.dart';
import '../services/purchase_amount_formatter.dart';
import '../services/purchase_statistics_calculator.dart';

/// 采购统计排行 Tab 页面组件
class PurchaseRankingTab extends StatelessWidget {
  final List<PurchaseItem> filteredItems;
  final List<PurchaseRecord> filteredRecords;

  const PurchaseRankingTab({
    super.key,
    required this.filteredItems,
    required this.filteredRecords,
  });

  @override
  Widget build(BuildContext context) {
    final topMaterialsByAmount =
        PurchaseStatisticsCalculator.calculateTopMaterialsByAmount(
          filteredItems,
        );
    final topMaterialsByQuantity =
        PurchaseStatisticsCalculator.calculateTopMaterialsByQuantity(
          filteredItems,
        );
    final topSuppliers = PurchaseStatisticsCalculator.calculateTopSuppliers(
      filteredRecords,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTopMaterialsCard(
            topMaterialsByAmount,
            '材料采购排行 (按金额)',
            '¥',
            Colors.green,
          ),
          const SizedBox(height: 24),
          _buildTopMaterialsCard(
            topMaterialsByQuantity,
            '材料采购排行 (按数量)',
            '',
            Colors.orange,
          ),
          const SizedBox(height: 24),
          _buildTopSuppliersCard(topSuppliers, '供应商排行 (按金额)'),
        ],
      ),
    );
  }

  /// 构建材料排行卡片
  Widget _buildTopMaterialsCard(
    List<MapEntry<String, num>> topMaterials,
    String title,
    String prefix,
    Color color,
  ) {
    final double totalValue = topMaterials.fold(
      0.0,
      (sum, item) => sum + item.value.toDouble(),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.inventory, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (topMaterials.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topMaterials.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final material = topMaterials[index];
                final rank = index + 1;
                final percentage =
                    totalValue == 0
                        ? 0.0
                        : (material.value.toDouble() / totalValue) * 100;

                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    material.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SingleLineAmountText(
                        text:
                            prefix == '¥'
                                ? PurchaseAmountFormatter.formatCurrency(
                                  material.value,
                                )
                                : '${material.value}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                        alignment: Alignment.centerRight,
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 构建供应商排行卡片
  Widget _buildTopSuppliersCard(
    List<MapEntry<String, double>> topSuppliers,
    String title,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),
          if (topSuppliers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topSuppliers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final supplier = topSuppliers[index];
                final rank = index + 1;

                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: PurchaseStatisticsCalculator.getRankColor(
                        rank,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          color: PurchaseStatisticsCalculator.getRankColor(
                            rank,
                          ),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    supplier.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: SingleLineAmountText(
                    text: PurchaseAmountFormatter.formatCurrency(
                      supplier.value,
                    ),
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                    alignment: Alignment.centerRight,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
