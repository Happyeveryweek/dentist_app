import 'package:dentist_app_windows/features/patients/models/patient_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('患者表单安排预约默认时间', () {
    test('默认为一周后当天早上9点', () {
      expect(
        defaultPatientAppointmentDateTime(DateTime(2026, 10, 3, 17, 19, 40)),
        DateTime(2026, 10, 10, 9),
      );
    });

    test('跨月仍是一周后早上9点', () {
      expect(
        defaultPatientAppointmentDateTime(DateTime(2026, 10, 28, 23, 59)),
        DateTime(2026, 11, 4, 9),
      );
    });

    test('跨年仍是一周后早上9点', () {
      expect(
        defaultPatientAppointmentDateTime(DateTime(2026, 12, 28, 8, 15)),
        DateTime(2027, 1, 4, 9),
      );
    });

    test('新建预约草稿使用该默认时间', () {
      final before = DateTime.now();
      final draft = DentalAppointmentDraft();
      addTearDown(draft.dispose);
      final after = DateTime.now();

      final value = draft.appointmentDateTime;
      expect(value.hour, 9);
      expect(value.minute, 0);
      expect(value.second, 0);

      final earliest = DateTime(before.year, before.month, before.day).add(
        const Duration(days: 7),
      );
      final latest = DateTime(after.year, after.month, after.day).add(
        const Duration(days: 7),
      );
      final date = DateTime(value.year, value.month, value.day);
      expect(
          date.isBefore(DateTime(earliest.year, earliest.month, earliest.day)),
          isFalse);
      expect(date.isAfter(DateTime(latest.year, latest.month, latest.day)),
          isFalse);
    });
  });
}
