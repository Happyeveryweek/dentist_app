import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_record.dart';
import '../../../providers/purchase_provider.dart';
import 'purchase_stat_card.dart';

/// 采购统计图表组件
/// 包含总体统计、月度采购金额趋势、采购材料统计排行
class PurchaseStatisticsChart extends StatelessWidget {
  final List<PurchaseRecord> records;

  const PurchaseStatisticsChart({
    super.key,
    required this.records,
  });

  Future<List<Map<String, dynamic>>> _buildMaterialRankingChart(BuildContext context) async {
    final Map<String, double> materialAmountData = {};
    final Map<String, int> materialQuantityData = {};
    
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 遍历每个采购记录，获取其采购项目
      for (final record in records) {
        final purchaseItems = await purchaseProvider.getPurchaseItemsByRecordId(record.id!);
        
        for (final item in purchaseItems) {
          // 使用 PurchaseItem 对象的属性访问
          final materialName = item.materialName;
          
          // 累计金额
          final amount = item.totalPrice;
          materialAmountData[materialName] = (materialAmountData[materialName] ?? 0) + amount;
          
          // 累计数量
          final quantity = item.quantity;
          materialQuantityData[materialName] = (materialQuantityData[materialName] ?? 0) + quantity;
        }
      }
    } catch (e) {
      print('获取采购项目数据失败: $e');
    }
    
    // 按金额排序
    final sortedMaterials = materialAmountData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedMaterials.map((entry) => {
      'name': entry.key,
      'amount': entry.value,
      'quantity': materialQuantityData[entry.key] ?? 0,
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 按月份统计采购金额和数量
    final Map<String, double> monthlyData = {};
    final Map<String, int> monthlyCount = {};
    final Map<String, int> monthlyQuantity = {};
    
    // 材料统计
    final Map<String, double> materialData = {};
    final Map<String, int> materialCount = {};
    
    double totalAmount = 0;
    int totalQuantity = 0;
    int totalRecords = records.length;
    
    for (final record in records) {
      final date = record.purchaseDate;
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      
      // 月度统计
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + record.totalAmount;
      monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
      monthlyQuantity[monthKey] = (monthlyQuantity[monthKey] ?? 0) + record.totalQuantity;
      
      // 材料统计（通过采购项目统计）
      // 这里我们使用供应商名称作为材料分类，实际项目中可能需要从采购项目表获取
      if (record.supplier != null) {
        materialData[record.supplier!] = (materialData[record.supplier!] ?? 0) + record.totalAmount;
        materialCount[record.supplier!] = (materialCount[record.supplier!] ?? 0) + 1;
      }
      
      // 累计统计
      totalAmount += record.totalAmount;
      totalQuantity += record.totalQuantity;
    }
    
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // 总体统计卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: PurchaseStatCard(
                    icon: Icons.attach_money,
                    label: '总采购金额',
                    value: '¥${totalAmount.toStringAsFixed(2)}',
                    color: Colors.blue[700]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PurchaseStatCard(
                    icon: Icons.inventory,
                    label: '总采购数量',
                    value: totalQuantity.toString(),
                    color: Colors.green[700]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PurchaseStatCard(
                    icon: Icons.shopping_cart,
                    label: '采购记录数',
                    value: totalRecords.toString(),
                    color: Colors.orange[700]!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FutureBuilder<List<Map<String, dynamic>>>(
                        key: const ValueKey('materialCount'),
                        future: _buildMaterialRankingChart(context),
                        builder: (context, snapshot) {
                          String value = '计算中...';
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            value = snapshot.data!.length.toString();
                          }
                          
                          return PurchaseStatCard(
                            icon: Icons.inventory,
                            label: '材料种类数',
                            value: value,
                            color: Colors.purple[700]!,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const SizedBox(height: 24),
          
          // 月度采购金额统计
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '月度采购金额趋势',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: sortedMonths.map((month) {
                      final amount = monthlyData[month] ?? 0;
                      final maxAmount = monthlyData.values.isEmpty ? 1.0 : monthlyData.values.reduce((a, b) => a > b ? a : b);
                      final height = maxAmount > 0 ? (amount / maxAmount) * 150 : 0.0;
                      
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 30,
                              height: height,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              month,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '¥${amount.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const SizedBox(height: 24),
          
          // 采购材料统计排行
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.purple[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '采购材料统计排行 (前10名)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(按金额排序)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _buildMaterialRankingChart(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('暂无材料数据', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    
                    final materialData = snapshot.data!;
                    final maxAmount = materialData.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b);
                    
                    return Column(
                      children: [
                        // 表头
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  '材料名称',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  '占比',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '金额',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '数量',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '占比',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 数据行
                        Column(
                          children: materialData.take(10).map((item) {
                            final amount = item['amount'] as double;
                            final quantity = item['quantity'] as int;
                            final percentage = maxAmount > 0 ? (amount / maxAmount) * 100 : 0.0;
                        
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  // 材料名称
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      item['name'] as String,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 水平条形图
                                  Expanded(
                                    child: Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: maxAmount > 0 ? (amount / maxAmount) : 0.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.purple[600],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 金额
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '¥${amount.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple[700],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 数量
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${quantity}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.blue[700],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // 百分比
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
