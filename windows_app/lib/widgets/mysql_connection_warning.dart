import 'package:flutter/material.dart';

/// MySQL 连接失败警告提示框
/// 用于在 MySQL 依赖的模块中显示统一的连接失败提示
class MySQLConnectionWarning extends StatelessWidget {
  /// 模块名称（中文）
  final String moduleName;

  const MySQLConnectionWarning({
    Key? key,
    required this.moduleName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MySQL连接失败已降级为SQLite数据源显示',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '如需永久使用SQLite，请在系统设置中更改为SQLite数据源并重启应用。',
            style: TextStyle(
              color: Colors.orange.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

