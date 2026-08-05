import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/patient_sync_log.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../widgets/success_toast.dart';

class PatientSyncLogDialog extends StatefulWidget {
  static Future<void> show(BuildContext context) async {
    final logs = await PatientSyncLog.getLogs();

    if (!context.mounted) return;

    if (logs.isEmpty) {
      AppToastManager.showInfo(
        context,
        message: '暂无患者同步日志记录',
      );
      return;
    }

    logs.sort((a, b) => b.syncTime.compareTo(a.syncTime));

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => PatientSyncLogDialog(logs: logs),
    );
  }

  final List<PatientSyncLog> logs;

  const PatientSyncLogDialog({super.key, required this.logs});

  @override
  State<PatientSyncLogDialog> createState() => _PatientSyncLogDialogState();
}

class _PatientSyncLogDialogState extends State<PatientSyncLogDialog> {
  final Set<int> _expandedIndexes = <int>{};
  String _statusFilter = 'all';

  String _actionLabel(String action) {
    switch (action) {
      case 'create':
        return '同步新建';
      case 'update':
        return '同步更新';
      case 'delete':
        return '同步删除';
      case 'upsert':
        return '同步写入';
      default:
        return action;
    }
  }

  String _recordLabel(PatientSyncLog log) {
    if (log.entityType == 'patient') {
      return '患者ID: ${log.patientId ?? log.recordId ?? '-'}';
    }
    return '患者ID: ${log.patientId ?? '-'}    记录ID: ${log.recordId ?? '-'}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'success':
        return '成功';
      case 'failed':
        return '失败';
      case 'skipped':
        return '跳过';
      default:
        return status;
    }
  }

  Color _headlineColor(PatientSyncLog log, dynamic tokens) {
    if (log.status == 'failed') return tokens.error;
    if (log.status == 'skipped') return tokens.warning;
    switch (log.action) {
      case 'create':
        return tokens.success;
      case 'update':
        return tokens.primaryAccent;
      case 'delete':
        return tokens.error;
      default:
        return tokens.textPrimary;
    }
  }

  bool _isExpanded(int index) => _expandedIndexes.contains(index);

  List<PatientSyncLog> get _filteredLogs {
    switch (_statusFilter) {
      case 'success':
        return widget.logs.where((log) => log.status == 'success').toList();
      case 'failed':
        return widget.logs
            .where((log) => log.status == 'failed' || log.status == 'skipped')
            .toList();
      default:
        return widget.logs;
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedIndexes.contains(index)) {
        _expandedIndexes.remove(index);
      } else {
        _expandedIndexes.add(index);
      }
    });
  }

  void _changeFilter(String filter) {
    setState(() {
      _statusFilter = filter;
      _expandedIndexes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('SQLite 患者同步 MySQL 日志')),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '关闭',
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 480,
        child: Column(
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: _statusFilter == 'all',
                  onSelected: (_) => _changeFilter('all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('成功'),
                  selected: _statusFilter == 'success',
                  onSelected: (_) => _changeFilter('success'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('失败'),
                  selected: _statusFilter == 'failed',
                  onSelected: (_) => _changeFilter('failed'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        _statusFilter == 'success'
                            ? '暂无同步成功日志'
                            : _statusFilter == 'failed'
                                ? '暂无同步失败日志'
                                : '暂无患者同步日志记录',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredLogs.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final log = _filteredLogs[index];
                        final expanded = _isExpanded(index);
                        final color = log.success
                            ? tokens.success
                            : log.status == 'skipped'
                                ? tokens.warning
                                : tokens.error;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                log.success
                                    ? Icons.check_circle
                                    : log.status == 'skipped'
                                        ? Icons.info
                                        : Icons.error,
                                color: color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                DateFormat(
                                                        'yyyy-MM-dd HH:mm:ss')
                                                    .format(log.syncTime),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${log.entityName} ${_actionLabel(log.action)}${_statusLabel(log.status)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _headlineColor(
                                                    log,
                                                    tokens,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _toggleExpanded(index),
                                          icon: Icon(
                                            expanded
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            color: tokens.primaryAccent,
                                          ),
                                          tooltip: expanded ? '收起详情' : '展开详情',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_recordLabel(log)}    姓名: ${log.patientName ?? '-'}    病历号: ${log.medicalRecordNumber ?? '-'}',
                                    ),
                                    if (expanded) ...[
                                      const SizedBox(height: 6),
                                      if (log.fieldChanges.isNotEmpty) ...[
                                        ...log.fieldChanges.take(8).map(
                                              (change) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 2,
                                                ),
                                                child: Text(
                                                  '${change.label}: ${change.oldValue ?? '-'} → ${change.newValue ?? '-'}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        if (log.fieldChanges.length > 8)
                                          Text(
                                            '还有 ${log.fieldChanges.length - 8} 个字段变更',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                      ] else
                                        const Text(
                                          '该条日志没有字段明细。',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      if (log.errorMessage != null &&
                                          log.errorMessage!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '原因: ${log.errorMessage}',
                                          style: TextStyle(
                                            color: tokens.error,
                                          ),
                                        ),
                                      ],
                                    ] else if (log.errorMessage != null &&
                                        log.errorMessage!.isNotEmpty)
                                      Text(
                                        '原因: ${log.errorMessage}',
                                        style: TextStyle(color: tokens.error),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: tokens.error),
          onPressed: () async {
            final confirmed = await DeleteConfirmDialogManager.show(
              context,
              title: '确认清空',
              message: '确定要清空所有患者同步日志记录吗？此操作不可恢复。',
              confirmText: '清空',
            );

            if (confirmed == true && context.mounted) {
              final success = await PatientSyncLog.clearAllLogs();
              if (success && context.mounted) {
                Navigator.pop(context);
                AppToastManager.showSuccess(context, message: '患者同步日志已清空');
              }
            }
          },
          child: const Text('清空日志'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: const Text('返回'),
        ),
      ],
    );
  }
}
