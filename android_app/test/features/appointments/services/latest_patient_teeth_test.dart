import 'dart:convert';

import 'package:dentist_app/features/appointments/services/latest_patient_teeth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('安卓添加预约加载最新牙齿状况', () {
    test('取最新一条十字牙位，不带下方说明', () {
      final source = jsonEncode({
        'date-0': '2025-11-06',
        'chart1-top-left-0': '5',
        'chart1-top-right-0': '6',
        'chart1-note-0': '补牙',
        'date-1': '2026-01-28',
        'chart1-top-left-1': '12',
        'chart3-bottom-right-1': '48',
        'chart1-note-1': '根管治疗',
      });

      final teeth = latestPatientTeethForAppointment(source);

      expect(teeth, hasLength(3));
      expect(teeth?.first['topLeft'], '12');
      expect(teeth?[2]['bottomRight'], '48');
      expect(teeth.toString(), isNot(contains('根管治疗')));
      expect(teeth.toString(), isNot(contains('补牙')));
    });

    test('预约时间取最新牙齿状况日期往后一周的早上9点', () {
      expect(
        appointmentDateTimeFromLatestDentalRecord(
          jsonEncode({'date-0': '2026-01-28'}),
        ),
        DateTime(2026, 2, 4, 9),
      );
    });

    test('跨年仍是一周后早上9点', () {
      expect(
        appointmentDateTimeFromLatestDentalRecord(
          jsonEncode({'date-0': '2026-12-28'}),
        ),
        DateTime(2027, 1, 4, 9),
      );
    });

    test('查看预约不足三个十字时补齐空位', () {
      final teeth = appointmentTeethForDisplay(
        jsonEncode({
          'teethData': [
            {
              'topLeft': '6',
              'topRight': '',
              'bottomLeft': '',
              'bottomRight': '',
            },
          ],
          'treatments': ['补牙'],
        }),
      );

      expect(teeth, hasLength(3));
      expect(teeth.first['topLeft'], '6');
      expect(teeth[1].values.every((value) => value.isEmpty), isTrue);
      expect(teeth[2].values.every((value) => value.isEmpty), isTrue);
      expect(appointmentTeethForDisplay(null), hasLength(3));
      expect(appointmentTeethForDisplay('洗牙'), hasLength(3));
    });

    test('没有牙齿状况时不加载、不改预约时间', () {
      expect(latestPatientTeethForAppointment(null), isNull);
      expect(appointmentDateTimeFromLatestDentalRecord('{}'), isNull);
      expect(blankAppointmentTeethData(), hasLength(3));
    });
  });
}
