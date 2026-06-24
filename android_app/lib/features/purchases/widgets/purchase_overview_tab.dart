import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import 'purchase_stat_card.dart';

/// 采购统计概览 Tab 页面组件
class PurchaseOverviewTab extends StatelessWidget {
  final List<PurchaseRecord> filteredRecords;
  final List<PurchaseItem> filteredItems;

  const PurchaseOverviewTab({
    super.key,
    required this.filteredRecords,
    required this.filteredItems,
  });

  @override
  Widget build(BuildContext context) {
    final totalRecords = filteredRecords.length;
    final totalAmount = filteredRecords.fold<double>(
      0.0,
      (sum, record) => sum + record.totalAmount,
    );
    final totalQuantity = filteredRecords.fold<int>(
      0,
      (sum, record) => sum + record.totalQuantity,
    );
    final uniqueMaterials =
        filteredItems.map((item) => item.materialName).toSet().length;
    final uniqueSuppliers =
        filteredRecords
            .map((record) => record.supplier)
            .where((s) => s != null && s.isNotEmpty)
            .toSet()
            .length;
    final averageAmount = totalRecords > 0 ? totalAmount / totalRecords : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计卡片网格
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              PurchaseStatCard(
                title: '记录数',
                value: totalRecords.toString(),
                icon: Icons.receipt_long,
                color: Colors.blue,
              ),
              PurchaseStatCard(
                title: '材料种类',
                value: uniqueMaterials.toString(),
                icon: Icons.category,
                color: Colors.purple,
              ),
              PurchaseStatCard(
                title: '供应商数',
                value: uniqueSuppliers.toString(),
                icon: Icons.business,
                color: Colors.green,
              ),
              PurchaseStatCard(
                title: '总采购量',
                value: NumberFormat('#,##0').format(totalQuantity),
                icon: Icons.inventory_2,
                color: Colors.orange,
              ),
              PurchaseStatCard(
                title: '总采购额',
                value: '¥${NumberFormat('#,##0').format(totalAmount)}',
                icon: Icons.monetization_on,
                color: Colors.teal,
              ),
              PurchaseStatCard(
                title: '平均金额',
                value: '¥${NumberFormat('#,##0').format(averageAmount)}',
                icon: Icons.trending_up,
                color: Colors.indigo,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 采购分布图表
          _buildPurchaseDistributionChart(
            totalAmount,
            totalQuantity,
            uniqueMaterials,
          ),
        ],
      ),
    );
  }

  /// 构建采购分布图表
  Widget _buildPurchaseDistributionChart(
    double totalAmount,
    int totalQuantity,
    int uniqueMaterials,
  ) {
    if (totalAmount <= 0) {
      return Container(
        height: 200,
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
        child: const Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text(
            '采购概况分析',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // 平均单价分析
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                '平均单价分析',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '总采购金额',
                      style: TextStyle(fontSize: 14, color: Colors.green[700]),
                    ),
                    Text(
                      '¥${NumberFormat('#,##0').format(totalAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '总采购数量',
                      style: TextStyle(fontSize: 14, color: Colors.green[700]),
                    ),
                    Text(
                      NumberFormat('#,##0').format(totalQuantity),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '平均单价',
                      style: TextStyle(fontSize: 14, color: Colors.green[700]),
                    ),
                    Text(
                      '¥${totalQuantity > 0 ? (totalAmount / totalQuantity).toStringAsFixed(2) : '0.00'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 材料多样性分析
          Row(
            children: [
              Icon(Icons.diversity_3, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                '材料多样性',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '材料种类数量',
                  style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                ),
                Text(
                  '$uniqueMaterials 种',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
