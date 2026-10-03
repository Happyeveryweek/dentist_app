import 'dart:convert';

import 'package:dentist_app_windows/features/appointments/services/latest_patient_teeth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('添加预约加载最新牙齿状况', () {
    test('取日期最新的一条，且不带十字下方说明', () {
      final source = jsonEncode({
        'date-0': '2025-11-06',
        'chart1-top-left-0': '5',
        'chart1-top-right-0': '6',
        'chart1-bottom-left-0': '',
        'chart1-bottom-right-0': '',
        'chart1-note-0': '补牙',
        'chart2-note-0': '',
        'chart3-note-0': '',
        'date-1': '2026-01-02',
        'chart1-top-left-1': '12',
        'chart1-top-right-1': '',
        'chart1-bottom-left-1': '4',
        'chart1-bottom-right-1': '',
        'chart1-note-1': '根管治疗',
        'chart2-top-left-1': '21',
        'chart3-bottom-right-1': '48',
        'chart3-note-1': '拔牙',
      });

      final teeth = latestPatientTeethForAppointment(source);

      expect(teeth, [
        {
          'topLeft': '12',
          'topRight': '',
          'bottomLeft': '4',
          'bottomRight': '',
        },
        {
          'topLeft': '21',
          'topRight': '',
          'bottomLeft': '',
          'bottomRight': '',
        },
        {
          'topLeft': '',
          'topRight': '',
          'bottomLeft': '',
          'bottomRight': '48',
        },
      ]);
      expect(teeth.toString(), isNot(contains('根管治疗')));
      expect(teeth.toString(), isNot(contains('补牙')));
      expect(teeth.toString(), isNot(contains('拔牙')));
    });

    test('同一天有多条时取患者详情里排在最前的一条', () {
      final source = jsonEncode({
        'date-0': '2025-11-06',
        'chart1-top-left-0': '5',
        'chart1-top-right-0': '6',
        'chart1-note-0': '补牙',
        'date-1': '2025-11-06',
        'chart1-top-left-1': '12',
        'chart1-note-1': '根管治疗',
      });

      final teeth = latestPatientTeethForAppointment(source);

      expect(teeth?.first['topLeft'], '5');
      expect(teeth?.first['topRight'], '6');
      expect(teeth.toString(), isNot(contains('补牙')));
    });

    test('中间十字为空时仍保留原位置', () {
      final source = jsonEncode({
        'date-0': '2026-03-01 09:00:00',
        'chart1-top-left-0': '11',
        'chart3-bottom-left-0': '36',
        'chart3-note-0': '不带入',
      });

      final teeth = latestPatientTeethForAppointment(source);

      expect(teeth, isNotNull);
      expect(teeth![0]['topLeft'], '11');
      expect(teeth[1].values.every((value) => value.isEmpty), isTrue);
      expect(teeth[2]['bottomLeft'], '36');
    });

    test('没有牙齿状况时不加载', () {
      expect(latestPatientTeethForAppointment(null), isNull);
      expect(latestPatientTeethForAppointment(''), isNull);
      expect(latestPatientTeethForAppointment('not-json'), isNull);
      expect(latestPatientTeethForAppointment('{}'), isNull);
    });

    test('预约时间取最新牙齿状况日期往后一周的早上9点', () {
      final source = jsonEncode({
        'date-0': '2025-11-06',
        'chart1-top-left-0': '5',
        'date-1': '2026-01-28',
        'chart1-top-left-1': '12',
      });

      expect(
        appointmentDateTimeFromLatestDentalRecord(source),
        DateTime(2026, 2, 4, 9),
      );
      expect(latestPatientDentalRecordDate(source), DateTime(2026, 1, 28));
    });

    test('牙齿状况跨年时预约时间仍是一周后早上9点', () {
      expect(
        appointmentDateTimeFromLatestDentalRecord(
          jsonEncode({'date-0': '2026-12-28'}),
        ),
        DateTime(2027, 1, 4, 9),
      );
    });

    test('没有牙齿状况时不改预约时间', () {
      expect(appointmentDateTimeFromLatestDentalRecord(null), isNull);
      expect(appointmentDateTimeFromLatestDentalRecord('{}'), isNull);
    });

    test('添加和查看预约都至少显示三个十字', () {
      expect(blankAppointmentTeethData(), hasLength(3));
      expect(
        normalizeAppointmentTeethData(const []),
        blankAppointmentTeethData(),
      );

      final padded = normalizeAppointmentTeethData(const [
        {
          'topLeft': '5',
          'topRight': '6',
          'bottomLeft': '',
          'bottomRight': '',
        },
      ]);

      expect(padded, hasLength(3));
      expect(padded[0]['topLeft'], '5');
      expect(padded[0]['topRight'], '6');
      expect(padded[1].values.every((value) => value.isEmpty), isTrue);
      expect(padded[2].values.every((value) => value.isEmpty), isTrue);
    });
  });
}
