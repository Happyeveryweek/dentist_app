import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/providers/database_provider.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final bool showText;
  final bool showIcon;
  final double? size;
  final Color? color;

  const ConnectionStatusWidget({
    super.key,
    this.showText = true,
    this.showIcon = true,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseProvider>(
      builder: (context, dbProvider, child) {
        final statusText = dbProvider.connectionStatusText;
        final statusIcon = dbProvider.connectionStatusIcon;
        final isConnected = dbProvider.isConnected;

        // 根据状态选择颜色
        Color statusColor = isConnected ? Colors.green : Colors.red;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Text(
                statusIcon,
                style: TextStyle(
                  fontSize: size ?? 16,
                  color: color ?? statusColor,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (showText) ...[
              Text(
                statusText,
                style: TextStyle(
                  fontSize: size ?? 12,
                  color: color ?? statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// 紧凑版连接状态指示器
class CompactConnectionStatus extends StatelessWidget {
  const CompactConnectionStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseProvider>(
      builder: (context, dbProvider, child) {
        final isConnected = dbProvider.isConnected;

        if (dbProvider.dbType != 'mysql') {
          return const SizedBox.shrink(); // 本地数据库不显示
        }

        Color dotColor = isConnected ? Colors.green : Colors.red;

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// 带重连按钮的连接状态指示器
class ConnectionStatusWithRetry extends StatelessWidget {
  const ConnectionStatusWithRetry({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseProvider>(
      builder: (context, dbProvider, child) {
        final statusText = dbProvider.connectionStatusText;
        final statusIcon = dbProvider.connectionStatusIcon;
        final isConnected = dbProvider.isConnected;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              statusIcon,
              style: TextStyle(
                fontSize: 16,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}
