import 'package:dentist_app/providers/financial_provider.dart';
import 'package:flutter/material.dart';

/// 财务数据清理工具类
/// 用于检查和清理无效的财务记录
class FinancialDataCleaner {
  final FinancialProvider _financialProvider;

  FinancialDataCleaner(this._financialProvider);

  /// 检查并显示无效财务记录信息
  Future<void> showInvalidRecordsDialog(BuildContext context) async {
    try {
      final invalidRecords = await _financialProvider.getInvalidRecordsInfo();
      
      if (invalidRecords.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 没有发现无效的财务记录'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('发现无效财务记录'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('发现 ${invalidRecords.length} 条无效记录'),
                  const SizedBox(height: 16),
                  const Text('无效记录详情：'),
                  ...invalidRecords.take(5).map((record) => Text(
                    'ID: ${record['id']}, 患者ID: ${record['patient_id']}, 创建时间: ${record['created_at']}',
                    style: const TextStyle(fontSize: 12),
                  )),
                  if (invalidRecords.length > 5)
                    Text('... 还有 ${invalidRecords.length - 5} 条记录'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _performCleanup(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('清理这些记录'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 执行数据清理操作
  Future<void> _performCleanup(BuildContext context) async {
    try {
      final result = await _financialProvider.checkAndCleanInvalidRecords();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '清理完成: 删除了 ${result['cleaned']} 条无效记录',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清理失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 自动清理并报告结果
  Future<Map<String, dynamic>> autoCleanAndReport() async {
    try {
      final result = await _financialProvider.checkAndCleanInvalidRecords();
      
      return {
        'success': true,
        'cleaned': result['cleaned'],
        'total': result['total'],
        'invalid': result['invalid'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

/// 在设置页面添加清理按钮的小组件
class FinancialCleanupWidget extends StatelessWidget {
  final FinancialProvider financialProvider;

  const FinancialCleanupWidget({
    super.key,
    required this.financialProvider,
  });

  @override
  Widget build(BuildContext context) {
    final cleaner = FinancialDataCleaner(financialProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '财务数据清理',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '检查和清理无效的财务记录（患者ID为0的记录）',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => cleaner.showInvalidRecordsDialog(context),
                  icon: const Icon(Icons.search),
                  label: const Text('检查无效记录'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await cleaner.autoCleanAndReport();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['success']
                                ? '自动清理完成: 删除了 ${result['cleaned']} 条记录'
                                : '清理失败: ${result['error']}',
                          ),
                          backgroundColor: result['success'] ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('自动清理'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}