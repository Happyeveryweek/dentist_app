import 'package:dentist_app_windows/features/patients/services/patient_sync_log_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fields = <String, String>{
    'name': '姓名',
    'age': '年龄',
    'notes': '备注',
  };

  group('PatientSyncLogHelper', () {
    test('规范化 null、空文本、数字、日期与二进制值', () {
      expect(PatientSyncLogHelper.normalizeValue(null), '');
      expect(PatientSyncLogHelper.normalizeValue('  '), '');
      expect(PatientSyncLogHelper.normalizeValue(12), '12');
      expect(PatientSyncLogHelper.normalizeValue(12.5), '12.5');
      expect(
        PatientSyncLogHelper.normalizeValue(DateTime(2026, 7, 13, 9, 8, 7)),
        '2026-07-13 09:08:07',
      );
      expect(PatientSyncLogHelper.normalizeValue(<int>[1, 2, 3]), '3 bytes');
      expect(PatientSyncLogHelper.normalizeValue(<String>['a', 'b']), '[a, b]');
    });

    test('创建字段变化忽略空值并保持字段声明顺序', () {
      final changes = PatientSyncLogHelper.buildCreateChanges(
        <String, dynamic>{'name': ' 张三 ', 'age': 30, 'notes': ''},
        fields,
      );

      expect(changes.map((change) => change.field), <String>['name', 'age']);
      expect(changes[0].label, '姓名');
      expect(changes[0].oldValue, isNull);
      expect(changes[0].newValue, '张三');
      expect(changes[1].newValue, '30');
    });

    test('字段变化忽略规范化后相同值，并为清空值保留 null 展示', () {
      final changes = PatientSyncLogHelper.buildFieldChanges(
        oldValues: <String, dynamic>{'name': '张三', 'age': 20, 'notes': '旧备注'},
        newValues: <String, dynamic>{'name': ' 张三 ', 'age': 21, 'notes': null},
        fields: fields,
      );

      expect(changes.map((change) => change.field), <String>['age', 'notes']);
      expect(changes[0].oldValue, '20');
      expect(changes[0].newValue, '21');
      expect(changes[1].oldValue, '旧备注');
      expect(changes[1].newValue, isNull);
    });

    test('展示值与摘要值提取正确处理空值和缺失键', () {
      expect(PatientSyncLogHelper.displayValue('  '), isNull);
      expect(PatientSyncLogHelper.displayValue(' 张三 '), '张三');
      expect(
        PatientSyncLogHelper.extractSummaryValue('name=张三, mrn=MRN-001', 'mrn'),
        'MRN-001',
      );
      expect(
          PatientSyncLogHelper.extractSummaryValue('name=张三', 'mrn'), isNull);
      expect(PatientSyncLogHelper.extractSummaryValue(null, 'name'), isNull);
    });
  });
}
