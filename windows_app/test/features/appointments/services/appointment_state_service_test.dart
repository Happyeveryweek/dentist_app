import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app_windows/features/appointments/services/appointment_state_service.dart';
import 'package:dentist_app_windows/models/appointment.dart';
import 'package:dentist_app_windows/models/patient.dart';
import 'package:dentist_app_windows/providers/appointment_provider.dart';

Appointment _makeAppointment({
  required int id,
  required DateTime date,
  String status = 'scheduled',
  Patient? patient,
}) {
  return Appointment(
    id: id,
    patientId: id,
    appointmentDate: date,
    status: status,
    patient: patient,
  );
}

Patient _makePatient({
  required int id,
  required String name,
  String? phone,
}) {
  return Patient(
    id: id,
    name: name,
    age: 30,
    gender: '男',
    phone: phone,
    firstVisitDate: DateTime(2026, 1, 1),
  );
}

void main() {
  group('AppointmentStateService pagination', () {
    late AppointmentProvider provider;
    late AppointmentStateService service;

    setUp(() {
      provider = AppointmentProvider();
      service = AppointmentStateService(appointmentProvider: provider);
    });

    test('empty list returns empty paginated appointments', () {
      service.setAppointments([]);
      expect(service.paginatedAppointments, isEmpty);
      expect(service.currentPage, 1);
    });

    test('slices list into pages of 10', () {
      final appointments = List.generate(
        25,
        (i) => _makeAppointment(
          id: i + 1,
          date: DateTime(2026, 7, 5, 9, 0).add(Duration(hours: i)),
        ),
      );
      service.isFiltering = false;
      service.setAppointments(appointments);

      expect(service.filteredAppointments.length, 25);
      expect(service.paginatedAppointments.length, 10);
      final firstPageIds = service.paginatedAppointments.map((a) => a.id).toSet();

      service.setPage(2);
      expect(service.paginatedAppointments.length, 10);
      final secondPageIds = service.paginatedAppointments.map((a) => a.id).toSet();
      expect(secondPageIds.intersection(firstPageIds), isEmpty);

      service.setPage(3);
      expect(service.paginatedAppointments.length, 5);
      final thirdPageIds = service.paginatedAppointments.map((a) => a.id).toSet();
      expect(thirdPageIds.intersection(firstPageIds), isEmpty);
      expect(thirdPageIds.intersection(secondPageIds), isEmpty);
    });

    test('setPage clamps to valid range', () {
      final appointments = List.generate(
        15,
        (i) => _makeAppointment(
          id: i + 1,
          date: DateTime(2026, 7, 5, 9, 0).add(Duration(hours: i)),
        ),
      );
      service.isFiltering = false;
      service.setAppointments(appointments);

      service.setPage(0);
      expect(service.currentPage, 1);

      service.setPage(100);
      expect(service.currentPage, 2);
    });

    test('filters reduce total pages and reset current page', () {
      final appointments = List.generate(
        25,
        (i) => _makeAppointment(
          id: i + 1,
          date: DateTime(2026, 7, 5, 9, 0).add(Duration(minutes: i * 10)),
        ),
      );
      service.selectedDate = DateTime(2026, 7, 5);
      service.setAppointments(appointments);
      service.setPage(3);
      expect(service.currentPage, 3);

      service.setSearchQuery('1');
      expect(service.currentPage, 1);
    });
  });

  group('AppointmentStateService date filtering', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('filters by selected date', () {
      final today = DateTime(2026, 7, 5);
      final tomorrow = DateTime(2026, 7, 6);
      service.setAppointments([
        _makeAppointment(id: 1, date: today),
        _makeAppointment(id: 2, date: today),
        _makeAppointment(id: 3, date: tomorrow),
      ]);

      service.selectDate(today);
      expect(service.filteredAppointments.length, 2);
      expect(service.filteredAppointments.map((a) => a.id), containsAll([1, 2]));
    });

    test('filters by date range', () {
      final d1 = DateTime(2026, 7, 5);
      final d2 = DateTime(2026, 7, 6);
      final d3 = DateTime(2026, 7, 7);
      service.setAppointments([
        _makeAppointment(id: 1, date: d1),
        _makeAppointment(id: 2, date: d2),
        _makeAppointment(id: 3, date: d3),
      ]);

      service.selectDateRange(d1, d2);
      expect(service.filteredAppointments.length, 2);
      expect(service.filteredAppointments.map((a) => a.id), containsAll([1, 2]));
    });

    test('toggle filtering disables date filter', () {
      final today = DateTime(2026, 7, 5);
      final tomorrow = DateTime(2026, 7, 6);
      service.setAppointments([
        _makeAppointment(id: 1, date: today),
        _makeAppointment(id: 2, date: tomorrow),
      ]);

      service.selectDate(today);
      expect(service.filteredAppointments.length, 1);

      service.toggleFiltering();
      expect(service.isFiltering, false);
      expect(service.filteredAppointments.length, 2);
    });
  });

  group('AppointmentStateService search', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('searches by patient name', () {
      service.setAppointments([
        _makeAppointment(
          id: 1,
          date: DateTime(2026, 7, 5),
          patient: _makePatient(id: 1, name: '张三'),
        ),
        _makeAppointment(
          id: 2,
          date: DateTime(2026, 7, 5),
          patient: _makePatient(id: 2, name: '李四'),
        ),
      ]);

      service.setSearchQuery('张');
      expect(service.filteredAppointments.length, 1);
      expect(service.filteredAppointments.first.id, 1);
    });

    test('searches by pinyin initials', () {
      service.setAppointments([
        _makeAppointment(
          id: 1,
          date: DateTime(2026, 7, 5),
          patient: _makePatient(id: 1, name: '张三'),
        ),
        _makeAppointment(
          id: 2,
          date: DateTime(2026, 7, 5),
          patient: _makePatient(id: 2, name: '李四'),
        ),
      ]);

      service.setSearchQuery('zs');
      expect(service.filteredAppointments.length, 1);
      expect(service.filteredAppointments.first.patient?.name, '张三');
    });

    test('empty search query shows all filtered appointments', () {
      service.setAppointments([
        _makeAppointment(id: 1, date: DateTime(2026, 7, 5)),
        _makeAppointment(id: 2, date: DateTime(2026, 7, 5)),
      ]);

      service.setSearchQuery('');
      expect(service.filteredAppointments.length, 2);
    });
  });

  group('AppointmentStateService mutations', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('replaceAppointment updates existing appointment', () {
      final appointment = _makeAppointment(id: 1, date: DateTime(2026, 7, 5));
      service.setAppointments([appointment]);

      final updated = appointment.copyWith(status: 'completed');
      service.replaceAppointment(updated);

      expect(service.appointments.first.status, 'completed');
      expect(service.filteredAppointments.first.status, 'completed');
    });

    test('replaceAppointment adds new appointment when id not found', () {
      service.setAppointments([
        _makeAppointment(id: 1, date: DateTime(2026, 7, 5)),
      ]);

      service.replaceAppointment(
        _makeAppointment(id: 2, date: DateTime(2026, 7, 6)),
      );

      expect(service.appointments.length, 2);
    });

    test('removeAppointmentById deletes appointment', () {
      service.setAppointments([
        _makeAppointment(id: 1, date: DateTime(2026, 7, 5)),
        _makeAppointment(id: 2, date: DateTime(2026, 7, 5)),
      ]);

      service.removeAppointmentById(1);
      expect(service.appointments.length, 1);
      expect(service.appointments.first.id, 2);
      expect(service.filteredAppointments.length, 1);
    });
  });

  group('AppointmentStateService notifications', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('setPage notifies when page changes', () {
      service.isFiltering = false;
      service.setAppointments(
        List.generate(
          20,
          (i) => _makeAppointment(
            id: i + 1,
            date: DateTime(2026, 7, 5, 9, 0).add(Duration(hours: i)),
          ),
        ),
      );

      var count = 0;
      service.addListener(() => count++);

      service.setPage(2);
      expect(count, 1);

      service.setPage(2);
      expect(count, 1);
    });
  });
}
