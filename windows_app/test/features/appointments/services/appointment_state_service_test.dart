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
  group('预约管理-分页功能', () {
    late AppointmentProvider provider;
    late AppointmentStateService service;

    setUp(() {
      provider = AppointmentProvider();
      service = AppointmentStateService(appointmentProvider: provider);
    });

    test('空预约列表分页结果为空', () {
      service.setAppointments([]);
      expect(service.paginatedAppointments, isEmpty);
      expect(service.currentPage, 1);
    });

    test('每页10条正确切片并翻页', () {
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

    test('页码越界时自动Clamp到合法范围', () {
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

    test('搜索筛选后自动重置到第一页', () {
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

  group('预约管理-日期筛选', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('按选定日期筛选预约', () {
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

    test('按日期范围筛选预约', () {
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

    test('关闭日期筛选后显示全部预约', () {
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

  group('预约管理-患者搜索', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('按患者姓名搜索预约', () {
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

    test('按患者姓名拼音首字母搜索预约', () {
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

    test('清空搜索关键词后显示全部结果', () {
      service.setAppointments([
        _makeAppointment(id: 1, date: DateTime(2026, 7, 5)),
        _makeAppointment(id: 2, date: DateTime(2026, 7, 5)),
      ]);

      service.setSearchQuery('');
      expect(service.filteredAppointments.length, 2);
    });
  });

  group('预约管理-数据变更', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('更新已存在预约状态', () {
      final appointment = _makeAppointment(id: 1, date: DateTime(2026, 7, 5));
      service.setAppointments([appointment]);

      final updated = appointment.copyWith(status: 'completed');
      service.replaceAppointment(updated);

      expect(service.appointments.first.status, 'completed');
      expect(service.filteredAppointments.first.status, 'completed');
    });

    test('新增预约时补充到列表', () {
      service.setAppointments([
        _makeAppointment(id: 1, date: DateTime(2026, 7, 5)),
      ]);

      service.replaceAppointment(
        _makeAppointment(id: 2, date: DateTime(2026, 7, 6)),
      );

      expect(service.appointments.length, 2);
    });

    test('按ID删除预约', () {
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

  group('预约管理-状态通知', () {
    late AppointmentStateService service;

    setUp(() {
      service = AppointmentStateService(
        appointmentProvider: AppointmentProvider(),
      );
    });

    test('翻页变化时通知监听者', () {
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
