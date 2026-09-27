import 'package:dentist_app_windows/features/medical_records/services/medical_record_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fields = {
    'record_number': '病历编号',
    'chief_complaint': '主诉',
    'treatment': '治疗过程',
  };
  final local = {
    'id': 7,
    'record_number': 'MR-7',
    'chief_complaint': '牙痛',
  };

  test('病历内容和数量一致时判定为已同步', () {
    expect(
      MedicalRecordSyncSnapshot.matches(
        localRecords: [local],
        remoteRecords: [
          {
            'id': 7,
            'record_number': 'MR-7',
            'chief_complaint': '牙痛',
            'treatment': '旧治疗',
          },
        ],
        fields: fields,
      ),
      isTrue,
    );
  });

  test('MySQL 缺少病历、内容不同或多出病历时判定为未同步', () {
    expect(
      MedicalRecordSyncSnapshot.matches(
        localRecords: [local],
        remoteRecords: const [],
        fields: fields,
      ),
      isFalse,
    );
    expect(
      MedicalRecordSyncSnapshot.matches(
        localRecords: [local],
        remoteRecords: const [
          {'id': 7, 'record_number': 'MR-7', 'chief_complaint': '复诊'},
        ],
        fields: fields,
      ),
      isFalse,
    );
    expect(
      MedicalRecordSyncSnapshot.matches(
        localRecords: [local],
        remoteRecords: const [
          {'id': 7, 'record_number': 'MR-7', 'chief_complaint': '牙痛'},
          {'id': 8, 'record_number': 'MR-8', 'chief_complaint': '多余'},
        ],
        fields: fields,
      ),
      isFalse,
    );
  });
}
