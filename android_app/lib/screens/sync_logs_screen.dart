import 'package:flutter/material.dart';
import '../utils/sync_logger.dart';
import '../widgets/confirm_dialogs.dart';
import '../theme/app_theme.dart';

class SyncLogsScreen extends StatefulWidget {
  const SyncLogsScreen({Key? key}) : super(key: key);

  @override
  SyncLogsScreenState createState() => SyncLogsScreenState();
}

class SyncLogsScreenState extends State<SyncLogsScreen> {
  List<SyncLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await SyncLogger.getAllLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载日志失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步日志'),
        actions: [
          TextButton.icon(
            onPressed: _logs.isEmpty ? null : _clearLogs,
            icon: const Icon(Icons.delete_sweep_outlined, size: 19),
            label: const Text('清空日志'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 64,
                      color: AppTheme.lightText,
                    ),
                    SizedBox(height: 16),
                    Text('暂无同步日志', style: AppTheme.bodyStyle),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadLogs,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return _buildLogCard(log);
                  },
                ),
              ),
    );
  }

  Widget _buildLogCard(SyncLog log) {
    final statusColor =
        log.success ? AppTheme.successColor : AppTheme.errorColor;
    final duration = log.durationMs;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showLogDetails(log),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              log.success
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: statusColor,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.success ? '同步成功' : '同步失败',
                                  style: AppTheme.subtitleStyle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDateTime(log.timestamp),
                                  style: AppTheme.captionStyle,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.lightText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        log.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyStyle.copyWith(
                          color: AppTheme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSummaryChip(
                            Icons.table_chart_outlined,
                            '${log.tableCounts.length} 张表',
                          ),
                          _buildSummaryChip(
                            Icons.data_array_rounded,
                            '${log.totalRecords} 条',
                          ),
                          if (duration != null)
                            _buildSummaryChip(
                              Icons.timer_outlined,
                              _formatDuration(duration),
                            ),
                        ],
                      ),
                      if (log.error?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Text(
                          log.error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.captionStyle.copyWith(
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.secondaryText),
          const SizedBox(width: 5),
          Text(label, style: AppTheme.captionStyle),
        ],
      ),
    );
  }

  Future<void> _clearLogs() async {
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '清空同步日志',
      message: '确定要清空全部同步日志吗？此操作不可恢复。',
      confirmText: '清空',
      cancelText: '取消',
    );
    if (confirmed != true) return;
    await SyncLogger.clearAllLogs();
    if (!mounted) return;
    await _loadLogs();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int durationMs) {
    if (durationMs < 1000) return '${durationMs}ms';
    return '${(durationMs / 1000).toStringAsFixed(1)}s';
  }

  void _showLogDetails(SyncLog log) {
    final statusColor =
        log.success ? AppTheme.successColor : AppTheme.errorColor;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder:
          (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: AppTheme.lightText.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              log.success
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: statusColor,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.success ? '同步成功' : '同步失败',
                                  style: AppTheme.titleStyle,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatDateTime(log.timestamp),
                                  style: AppTheme.captionStyle,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: AppTheme.lightText.withValues(alpha: 0.22),
                ),

                // 内容区域
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 消息卡片
                        _buildLogOverview(log),

                        if (log.sourceDatabase?.isNotEmpty == true ||
                            log.targetDatabase?.isNotEmpty == true)
                          _buildSyncRouteCard(log),

                        _buildInfoCard(
                          icon: Icons.message,
                          title: '同步消息',
                          content: log.message,
                        ),

                        // 表结构变更卡片
                        if (log.schemaChanges?.isNotEmpty == true)
                          _buildInfoCard(
                            icon: Icons.schema,
                            title: '表结构变更',
                            content: log.schemaChanges ?? '',
                          ),

                        // 同步统计卡片
                        if (log.tableCounts.isNotEmpty)
                          _buildStatsCard(log.tableCounts),

                        // 详细信息卡片
                        if (log.tableDetails.isNotEmpty)
                          _buildDetailsCard(log.tableDetails),

                        // 错误信息卡片
                        if (log.error?.isNotEmpty == true)
                          _buildErrorCard(log.error ?? ''),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildLogOverview(SyncLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildOverviewItem(
              '同步表',
              '${log.tableCounts.length}',
              Icons.table_chart_outlined,
            ),
          ),
          Container(width: 1, height: 42, color: Colors.black12),
          Expanded(
            child: _buildOverviewItem(
              '记录数',
              '${log.totalRecords}',
              Icons.data_array_rounded,
            ),
          ),
          Container(width: 1, height: 42, color: Colors.black12),
          Expanded(
            child: _buildOverviewItem(
              '耗时',
              log.durationMs == null ? '--' : _formatDuration(log.durationMs!),
              Icons.timer_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 19, color: AppTheme.primaryColor),
        const SizedBox(height: 6),
        Text(value, style: AppTheme.subtitleStyle),
        const SizedBox(height: 2),
        Text(label, style: AppTheme.captionStyle),
      ],
    );
  }

  Widget _buildSyncRouteCard(SyncLog log) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('数据流向', style: AppTheme.subtitleStyle),
          const SizedBox(height: 12),
          _buildRouteRow(
            Icons.cloud_outlined,
            'MySQL 来源',
            log.sourceDatabase ?? '历史日志未记录',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(
              width: 2,
              height: 16,
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
            ),
          ),
          _buildRouteRow(
            Icons.storage_outlined,
            'SQLite 目标',
            log.targetDatabase ?? '历史日志未记录',
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.captionStyle),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTheme.bodyStyle.copyWith(color: AppTheme.primaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightText.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.secondaryText, size: 18),
              ),
              const SizedBox(width: 8),
              Text(title, style: AppTheme.subtitleStyle),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Map<String, int> tableCounts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightText.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.secondaryText,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text('同步统计', style: AppTheme.subtitleStyle),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                tableCounts.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.lightText.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.table_chart,
                          size: 14,
                          color: AppTheme.secondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, String> tableDetails) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightText.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.list_alt_rounded,
                  color: AppTheme.secondaryText,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text('详细信息', style: AppTheme.subtitleStyle),
            ],
          ),
          const SizedBox(height: 12),
          ...tableDetails.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '错误信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              error,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade700,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
