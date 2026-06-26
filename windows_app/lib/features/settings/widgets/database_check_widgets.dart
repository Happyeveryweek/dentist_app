import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/database_structure_log.dart';

/// 数据库结构检测相关的 UI 组件集合
class DatabaseCheckWidgets {
  /// 构建统计卡片
  static Widget buildStatCard(
      String label, String value, IconData icon, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建表检测汇总
  static Widget buildTableSummary(Map<String, dynamic> result) {
    final details = (result['details'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final systemTables = details['systemTables'] as List? ?? [];
    final detectedTables = details['detectedTables'] as List? ?? [];
    final missingTables = details['missingTableNames'] as List? ?? [];
    final createdTables = details['tablesCreated'] as List? ?? [];
    final updatedTables = details['tablesUpdated'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_view, size: 24, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(
                '表检测汇总',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 系统表状态
          buildSummaryItem(
            '系统必需表',
            '${systemTables.length} 个',
            Icons.table_chart,
            Colors.blue,
            systemTables.join(', '),
          ),

          const SizedBox(height: 12),

          // 检测到的表
          if (detectedTables.isNotEmpty)
            buildSummaryItem(
              '检测到的表',
              '${detectedTables.length} 个',
              Icons.check_circle,
              Colors.green,
              detectedTables.join(', '),
            ),

          const SizedBox(height: 12),

          // 缺失的表
          if (missingTables.isNotEmpty)
            buildSummaryItem(
              '缺失的表',
              '${missingTables.length} 个',
              Icons.error,
              Colors.red,
              missingTables.join(', '),
            ),

          const SizedBox(height: 12),

          // 新创建的表
          if (createdTables.isNotEmpty)
            buildSummaryItem(
              '新创建的表',
              '${createdTables.length} 个',
              Icons.add_circle,
              Colors.green,
              createdTables.join(', '),
            ),

          const SizedBox(height: 12),

          // 更新的表
          if (updatedTables.isNotEmpty)
            buildSummaryItem(
              '结构更新的表',
              '${updatedTables.length} 个',
              Icons.update,
              Colors.orange,
              updatedTables.join(', '),
            ),
        ],
      ),
    );
  }

  /// 构建汇总项
  static Widget buildSummaryItem(
      String title, String count, IconData icon, Color color, String details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建详细变化信息
  static Widget buildDetailedChanges(Map<String, dynamic> result) {
    final details = (result['details'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final errors =
        (result['errors'] as List?)?.cast<String>() ?? const <String>[];
    final columnsAdded = (details['columnsAdded'] as List?) ?? const [];
    final columnsModified = (details['columnsModified'] as List?) ?? const [];
    final structureLogs = _filterActionableStructureLogs(
        (details['structureChanges'] as List?) ?? const []);
    final hasAnyDetails = columnsAdded.isNotEmpty ||
        columnsModified.isNotEmpty ||
        structureLogs.isNotEmpty ||
        errors.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 24, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(
                '详细变化记录',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 新增字段
          if (columnsAdded.isNotEmpty) ...[
            buildChangeSection(
              '新增字段',
              Icons.add_box,
              Colors.green,
              columnsAdded
                  .map((column) =>
                      '${column['table']}.${column['column']} (${column['type']})')
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // 修改字段
          if (columnsModified.isNotEmpty) ...[
            buildChangeSection(
              '修改字段',
              Icons.edit,
              Colors.orange,
              columnsModified
                  .map((column) =>
                      '${column['table']}.${column['column']} (${column['oldType']} → ${column['newType']})')
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // 操作日志
          if (structureLogs.isNotEmpty) ...[
            buildChangeSection(
              '操作日志',
              Icons.history,
              Colors.blue,
              structureLogs.cast<String>(),
            ),
            const SizedBox(height: 16),
          ],

          // 错误信息
          if (errors.isNotEmpty) ...[
            buildChangeSection(
              '错误信息',
              Icons.error_outline,
              Colors.red,
              errors,
            ),
          ] else if (!hasAnyDetails) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '本次检测未发现需要变更的表结构，所有系统表均保持现状。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建变化部分
  static Widget buildChangeSection(
      String title, IconData icon, Color color, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// 构建日志项
  static Widget buildLogItem(
      BuildContext context, DatabaseStructureLog log, VoidCallback onTap) {
    final actionableChangeCount =
        _getActionableStructureChangeCountFromLog(log);
    final state = _evaluateLogStateWithCount(log, actionableChangeCount);
    final displaySummary = _getDisplaySummary(log, actionableChangeCount);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: state.color.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部信息
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: state.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(state.icon, color: state.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displaySummary,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: state.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                state.statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: state.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                log.dataSourceType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),

              const SizedBox(height: 12),

              // 统计信息
              Row(
                children: [
                  buildLogStatChip('必需表', log.requiredTables, Icons.table_chart,
                      Colors.blue),
                  const SizedBox(width: 8),
                  buildLogStatChip('缺失表', log.missingTables,
                      Icons.table_rows_outlined, Colors.orange),
                  const SizedBox(width: 8),
                  buildLogStatChip(
                      '变更', actionableChangeCount, Icons.update, Colors.green),
                ],
              ),

              const SizedBox(height: 8),

              // 时间信息
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(log.detectionTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '点击查看详情',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建日志统计芯片
  static Widget buildLogStatChip(
      String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示日志详情对话框
  static void showLogDetails(
      BuildContext context, DatabaseStructureLog log, VoidCallback onRefresh) {
    final actionableChangeCount =
        _getActionableStructureChangeCountFromLog(log);
    final state = _evaluateLogStateWithCount(log, actionableChangeCount);
    final displaySummary = _getDisplaySummary(log, actionableChangeCount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(state.icon, color: state.color),
            const SizedBox(width: 8),
            const Text('检测日志详情'),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 状态卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: state.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: state.color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(state.icon, size: 40, color: state.color),
                      const SizedBox(height: 8),
                      Text(
                        displaySummary,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: state.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${log.dataSourceType.toUpperCase()} - ${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.detectionTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 统计信息
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '检测统计',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: buildDetailStatItem(
                                  '必需表',
                                  log.requiredTables,
                                  Icons.table_chart,
                                  Colors.blue)),
                          Expanded(
                              child: buildDetailStatItem(
                                  '缺失表',
                                  log.missingTables,
                                  Icons.table_rows_outlined,
                                  Colors.orange)),
                          Expanded(
                              child: buildDetailStatItem(
                                  '结构变更',
                                  actionableChangeCount,
                                  Icons.update,
                                  Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 详细信息
                if (log.details.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '详细信息',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 检测到的表
                        if (log.details['detectedTables'] != null &&
                            (log.details['detectedTables'] as List)
                                .isNotEmpty) ...[
                          buildDetailInfoItem(
                            '检测到的表',
                            (log.details['detectedTables'] as List).join(', '),
                            Icons.check_circle,
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 缺失的表
                        if (log.details['missingTableNames'] != null &&
                            (log.details['missingTableNames'] as List)
                                .isNotEmpty) ...[
                          buildDetailInfoItem(
                            '缺失的表',
                            (log.details['missingTableNames'] as List)
                                .join(', '),
                            Icons.error,
                            Colors.red,
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 新创建的表
                        if (log.details['tablesCreated'] != null &&
                            (log.details['tablesCreated'] as List)
                                .isNotEmpty) ...[
                          buildDetailInfoItem(
                            '新创建的表',
                            (log.details['tablesCreated'] as List).join(', '),
                            Icons.add_circle,
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 更新的表
                        if (log.details['tablesUpdated'] != null &&
                            (log.details['tablesUpdated'] as List)
                                .isNotEmpty) ...[
                          buildDetailInfoItem(
                            '结构更新的表',
                            (log.details['tablesUpdated'] as List).join(', '),
                            Icons.update,
                            Colors.orange,
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 新增的字段
                        if (log.details['columnsAdded'] != null &&
                            (log.details['columnsAdded'] as List)
                                .isNotEmpty) ...[
                          buildDetailInfoItem(
                            '新增字段',
                            (log.details['columnsAdded'] as List)
                                .map((column) =>
                                    '${column['table']}.${column['column']} (${column['type']})')
                                .join(', '),
                            Icons.add_box,
                            Colors.green,
                          ),
                        ],

                        // 只显示真正需要关注的结构日志
                        if (_filterActionableStructureLogs(
                          (log.details['structureChanges'] as List?) ??
                              const [],
                        ).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          buildDetailInfoItem(
                            '需要关注',
                            _filterActionableStructureLogs(
                              (log.details['structureChanges'] as List?) ??
                                  const [],
                            ).join('\n'),
                            Icons.report,
                            Colors.orange,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 错误信息
                if (log.errors.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '错误信息',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...log.errors.map((error) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ',
                                      style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      error,
                                      style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建详细统计项
  static Widget buildDetailStatItem(
      String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// 构建详细信息项
  static Widget buildDetailInfoItem(
      String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static _LogDisplayState _evaluateLogStateWithCount(
      DatabaseStructureLog log, int actionableChangeCount) {
    final hasStructuralIssues =
        log.missingTables > 0 || actionableChangeCount > 0;
    final hasWarnings = !hasStructuralIssues && log.errors.isNotEmpty;

    if (!hasStructuralIssues && !hasWarnings) {
      return const _LogDisplayState(
        color: Colors.green,
        icon: Icons.check_circle,
        statusText: '结构完整',
      );
    }

    if (hasWarnings) {
      return const _LogDisplayState(
        color: Colors.orange,
        icon: Icons.info,
        statusText: '存在警告',
      );
    }

    return _LogDisplayState(
      color: log.errors.isNotEmpty ? Colors.red : Colors.orange,
      icon: log.errors.isNotEmpty ? Icons.error : Icons.info,
      statusText: log.errors.isNotEmpty ? '发现问题' : '结构变更',
    );
  }

  static List<String> _filterActionableStructureLogs(List<dynamic> rawLogs) {
    return rawLogs
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .where((item) => _isActionableStructureLog(item))
        .toList();
  }

  static int getActionableStructureChangeCount(Map<String, dynamic> result) {
    final details = (result['details'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final tablesCreated = (details['tablesCreated'] as List?)?.length ?? 0;
    final columnsAdded = (details['columnsAdded'] as List?)?.length ?? 0;
    return tablesCreated + columnsAdded;
  }

  static bool hasActionableStructureIssues(Map<String, dynamic> result) {
    final actionableCount = getActionableStructureChangeCount(result);
    final missingTables = (result['missingTables'] as int?) ?? 0;
    final errors =
        (result['errors'] as List?)?.cast<String>() ?? const <String>[];
    return missingTables > 0 || actionableCount > 0 || errors.isNotEmpty;
  }

  static bool _isActionableStructureLog(String log) {
    final lower = log.toLowerCase();
    if (log.contains('已保留') ||
        log.contains('结构完整') ||
        log.contains('忽略') ||
        log.contains('表结构检查完成') ||
        log.contains('无需特殊修复') ||
        log.contains('所有系统表都已存在') ||
        log.contains('更新表 0 个') ||
        log.contains('添加字段 0 个') ||
        log.contains('修改字段 0 个')) {
      return false;
    }

    const actionableKeywords = [
      '缺失表',
      '缺失字段',
      '创建系统表',
      '添加字段',
      '添加字段失败',
      '创建失败',
      '修复失败',
      '检测失败',
      '表结构检查失败',
      '检测过程中发生错误',
      '发现问题',
      '需要关注',
    ];

    return actionableKeywords
        .any((keyword) => lower.contains(keyword.toLowerCase()));
  }

  static int _getActionableStructureChangeCountFromLog(
      DatabaseStructureLog log) {
    final logs = _filterActionableStructureLogs(
        (log.details['structureChanges'] as List?) ?? const []);
    final tablesCreated = (log.details['tablesCreated'] as List?)?.length ?? 0;
    final tablesUpdated = (log.details['tablesUpdated'] as List?)?.length ?? 0;
    final columnsAdded = (log.details['columnsAdded'] as List?)?.length ?? 0;
    return logs.length + tablesCreated + tablesUpdated + columnsAdded;
  }

  static String _getDisplaySummary(
      DatabaseStructureLog log, int actionableChangeCount) {
    if (log.errors.isNotEmpty) {
      return log.summary.isNotEmpty ? log.summary : '检测发现问题';
    }

    if (log.missingTables > 0 || actionableChangeCount > 0) {
      return log.summary.isNotEmpty ? log.summary : '检测到结构变更';
    }

    return '数据库结构正常，无需更新';
  }
}

class _LogDisplayState {
  final MaterialColor color;
  final IconData icon;
  final String statusText;

  const _LogDisplayState({
    required this.color,
    required this.icon,
    required this.statusText,
  });
}
