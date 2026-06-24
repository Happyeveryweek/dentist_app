import 'package:flutter/material.dart';

/// 采购记录空状态组件
/// 职责：显示采购记录列表为空时的提示
class PurchaseRecordsEmptyState extends StatelessWidget {
  const PurchaseRecordsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无采购记录', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}
