import 'package:flutter/material.dart';

/// 采购项目空状态组件
class PurchaseEmptyState extends StatelessWidget {
  const PurchaseEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('暂无采购项目', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
