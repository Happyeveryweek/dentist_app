import 'package:flutter/material.dart';

/// 采购项目错误状态组件
class PurchaseErrorState extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const PurchaseErrorState({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 8),
          Text('加载失败', style: TextStyle(color: Colors.red[300])),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
