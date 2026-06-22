import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../helpers/financial_payment_method_helper.dart';
// 财务统计对话框
class FinancialStatisticsDialog extends StatelessWidget {
  final List<FinancialRecord> financialRecords;
  final List<FinancialItem> financialItems;
  final List<Patient> patients;

  const FinancialStatisticsDialog({
    Key? key,
    required this.financialRecords,
    required this.financialItems,
    required this.patients,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 计算统计数据
    final totalRecords = financialRecords.length;
    final totalReceivable = financialItems.fold<double>(0.0, (sum, item) => sum + item.itemPrice);
    final totalReceived = financialItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    final totalDue = totalReceivable - totalReceived;
    final totalProcessingFee = financialItems.fold<double>(0.0, (sum, item) => sum + item.processingFee);
    
    // 按月份统计
    final Map<String, double> monthlyStats = {};
    for (final item in financialItems) {
      final monthKey = DateFormat('yyyy-MM').format(item.chargeDate);
      monthlyStats[monthKey] = (monthlyStats[monthKey] ?? 0.0) + item.totalPrice;
    }
    
    // 按收费项目统计
    final Map<String, double> itemStats = {};
    for (final item in financialItems) {
      itemStats[item.itemName] = (itemStats[item.itemName] ?? 0.0) + item.totalPrice;
    }

    // 按支付方式统计
    final Map<String, double> paymentMethodStats = <String, double>{
      '微信': 0.0,
      '支付宝': 0.0,
      '现金': 0.0,
    };
    for (final item in financialItems) {
      final methodName = FinancialPaymentMethodHelper.displayNameOrDefault(item.paymentMethod);
      paymentMethodStats[methodName] = (paymentMethodStats[methodName] ?? 0.0) + item.totalPrice;
    }
    final paymentMethodOrder = <String>['微信', '支付宝', '现金'];
    
    // 按患者统计
    final Map<String, double> patientStats = {};
    for (final item in financialItems) {
      // 通过财务记录ID找到对应的患者
      final record = financialRecords.firstWhere(
        (record) => record.id == item.financialRecordId,
        orElse: () => FinancialRecord(
          patientId: 0,
          totalQuantity: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
             if (record.patientId > 0) {
         final patient = patients.firstWhere(
           (patient) => patient.id == record.patientId,
           orElse: () => Patient(
             id: 0,
             name: '未知患者',
             age: 0,
             gender: '未知',
             phone: '',
             medical_record_number: 0,
             address: '',
             first_visit_date: DateTime.now(),
           ),
         );
         
         if (patient.id != null && patient.id! > 0) {
           patientStats[patient.name] = (patientStats[patient.name] ?? 0.0) + item.totalPrice;
         }
       }
    }
    
    // 排序数据
    final sortedMonths = monthlyStats.keys.toList()..sort();
    final sortedItems = itemStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedPatients = patientStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.bar_chart, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  '收费图表统计',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 总体统计卡片
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.05),
                            Theme.of(context).primaryColor.withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '总记录数',
                              '$totalRecords',
                              Icons.receipt_long_rounded,
                              Colors.blue[700]!,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总应收费',
                              '¥${totalReceivable.toStringAsFixed(0)}',
                              Icons.account_balance_wallet_rounded,
                              Colors.green[700]!,
                              details: paymentMethodOrder
                                  .map(
                                    (method) => _buildCardDetailLine(
                                      method,
                                      paymentMethodStats[method] ?? 0.0,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总已收费',
                              '¥${totalReceived.toStringAsFixed(0)}',
                              Icons.check_circle_rounded,
                              Colors.blue[600]!,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总欠费',
                              '¥${totalDue.toStringAsFixed(0)}',
                              Icons.pending_rounded,
                              totalDue > 0 ? Colors.red[600]! : Colors.grey[600]!,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '总加工费',
                              '¥${totalProcessingFee.toStringAsFixed(0)}',
                              Icons.build_rounded,
                              Colors.orange[600]!,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 月度趋势图
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
                          Text(
                            '月度收费趋势',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: sortedMonths.isEmpty
                                ? const Center(
                                    child: Text('暂无数据'),
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: sortedMonths.map((month) {
                                      final amount = monthlyStats[month] ?? 0.0;
                                      final maxAmount = monthlyStats.values.isEmpty 
                                          ? 1.0 
                                          : monthlyStats.values.reduce((a, b) => a > b ? a : b);
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
                    
                    const SizedBox(height: 24),
                    
                                         // 收费项目统计
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
                           Text(
                             '收费项目统计 (前10名)',
                             style: Theme.of(context).textTheme.titleLarge?.copyWith(
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           const SizedBox(height: 16),
                           if (sortedItems.isEmpty)
                             const Center(
                               child: Text('暂无数据'),
                             )
                           else
                             ...sortedItems.take(10).map((entry) {
                               final percentage = totalReceivable > 0 ? (entry.value / totalReceivable) * 100 : 0.0;
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: Row(
                                   children: [
                                     Expanded(
                                       flex: 2,
                                       child: Text(
                                         entry.key,
                                         style: Theme.of(context).textTheme.bodyMedium,
                                       ),
                                     ),
                                     Expanded(
                                       flex: 3,
                                       child: LinearProgressIndicator(
                                         value: percentage / 100,
                                         backgroundColor: Colors.grey[300],
                                         valueColor: AlwaysStoppedAnimation<Color>(
                                           Theme.of(context).primaryColor,
                                         ),
                                       ),
                                     ),
                                     const SizedBox(width: 16),
                                     SizedBox(
                                       width: 80,
                                       child: Text(
                                         '¥${entry.value.toStringAsFixed(0)}',
                                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                           fontWeight: FontWeight.bold,
                                         ),
                                         textAlign: TextAlign.right,
                                       ),
                                     ),
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
                         ],
                       ),
                     ),
                     
                     const SizedBox(height: 24),
                     
                     // 患者收费统计排行
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
                           Text(
                             '患者收费统计 (前10名)',
                             style: Theme.of(context).textTheme.titleLarge?.copyWith(
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           const SizedBox(height: 16),
                           if (sortedPatients.isEmpty)
                             const Center(
                               child: Text('暂无数据'),
                             )
                           else
                             ...sortedPatients.take(10).map((entry) {
                               final percentage = totalReceivable > 0 ? (entry.value / totalReceivable) * 100 : 0.0;
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: Row(
                                   children: [
                                     Expanded(
                                       flex: 2,
                                       child: Text(
                                         entry.key,
                                         style: Theme.of(context).textTheme.bodyMedium,
                                       ),
                                     ),
                                     Expanded(
                                       flex: 3,
                                       child: LinearProgressIndicator(
                                         value: percentage / 100,
                                         backgroundColor: Colors.grey[300],
                                         valueColor: AlwaysStoppedAnimation<Color>(
                                           Colors.green[600]!,
                                         ),
                                       ),
                                     ),
                                     const SizedBox(width: 16),
                                     SizedBox(
                                       width: 80,
                                       child: Text(
                                         '¥${entry.value.toStringAsFixed(0)}',
                                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                           fontWeight: FontWeight.bold,
                                         ),
                                         textAlign: TextAlign.right,
                                       ),
                                     ),
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
                         ],
                       ),
                     ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 底部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建统计卡片
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    List<Widget>? details,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (details != null && details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: details,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardDetailLine(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label ¥${value.toStringAsFixed(0)}',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
          height: 1.2,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
