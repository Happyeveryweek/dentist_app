import 'package:dentist_app/utils/sync_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('历史同步日志缺少新增字段时仍可读取', () {
    final log = SyncLog.fromJson({
      'id': '1',
      'timestamp': '2026-07-20 08:40:29',
      'success': true,
      'message': '同步成功',
      'table_counts': {'patients': 2},
      'table_details': {'patients': '同步了 2 条记录'},
    });

    expect(log.sourceDatabase, isNull);
    expect(log.targetDatabase, isNull);
    expect(log.durationMs, isNull);
    expect(log.totalRecords, 2);
  });

  test('同步日志保存数据流向、耗时并正确汇总记录数', () {
    final original = SyncLog(
      id: '2',
      timestamp: DateTime(2026, 7, 20, 8, 40, 29),
      success: true,
      message: '同步成功',
      tableCounts: const {'patients': 2, 'appointments': 3},
      tableDetails: const {},
      sourceDatabase: 'MySQL（dental_clinic）',
      targetDatabase: '自定义 SQLite（custom.db）',
      durationMs: 1250,
    );

    final restored = SyncLog.fromJson(original.toJson());

    expect(restored.totalRecords, 5);
    expect(restored.sourceDatabase, original.sourceDatabase);
    expect(restored.targetDatabase, original.targetDatabase);
    expect(restored.durationMs, 1250);
  });
}
