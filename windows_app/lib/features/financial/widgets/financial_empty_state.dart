import 'package:flutter/material.dart';

/// 财务管理空状态组件
class FinancialEmptyState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onAddRecord;

  const FinancialEmptyState({
    Key? key,
    required this.searchQuery,
    required this.onAddRecord,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searchQuery.isEmpty
                  ? Icons.account_balance_wallet_outlined
                  : Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isEmpty ? '暂无财务记录' : '未找到匹配的记录',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                searchQuery.isEmpty ? '点击右上角按钮添加第一条财务记录' : '请尝试其他搜索关键词',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAddRecord,
                child: const Text('添加收费记录'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
