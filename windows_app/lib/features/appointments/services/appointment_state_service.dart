import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../providers/appointment_provider.dart';
import '../../../utils/pinyin_util.dart';

class AppointmentStateService extends ChangeNotifier {
  final AppointmentProvider appointmentProvider;

  AppointmentStateService({required this.appointmentProvider});

  DateTime selectedDate = DateTime.now();
  DateTime? endDate;
  List<Appointment> appointments = [];
  List<Appointment> filteredAppointments = [];
  bool isLoading = false;
  bool showAllAppointments = true;
  bool isFiltering = true;
  bool isDateRangeFiltering = false;
  String searchQuery = '';
  int currentPage = 1;
  final int pageSize = 10;

  List<Appointment> get paginatedAppointments {
    final totalPages =
        (filteredAppointments.length / pageSize).ceil();
    final effectivePage = currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final startIndex = (effectivePage - 1) * pageSize;
    final endIndex = startIndex + pageSize;
    if (startIndex >= filteredAppointments.length) return [];
    return filteredAppointments.sublist(
      startIndex,
      endIndex > filteredAppointments.length
          ? filteredAppointments.length
          : endIndex,
    );
  }

  void setPage(int page) {
    final totalPages =
        (filteredAppointments.length / pageSize).ceil();
    final effectiveTotalPages = totalPages > 0 ? totalPages : 1;
    final target = page.clamp(1, effectiveTotalPages);
    if (target != currentPage) {
      currentPage = target;
      notifyListeners();
    }
  }

  void _resetPage() {
    if (currentPage != 1) {
      currentPage = 1;
    }
  }

  void _sortAppointmentsInPlace() {
    appointments.sort((a, b) {
      final now = DateTime.now();
      final diffA = a.appointmentDate.difference(now).inMinutes.abs();
      final diffB = b.appointmentDate.difference(now).inMinutes.abs();

      if (a.appointmentDate.isAfter(now) && b.appointmentDate.isBefore(now)) {
        return -1;
      }
      if (a.appointmentDate.isBefore(now) && b.appointmentDate.isAfter(now)) {
        return 1;
      }
      return diffA.compareTo(diffB);
    });
  }

  void _syncFilteredAppointments() {
    _filterAppointmentsByDate();
  }

  void setAppointments(List<Appointment> loadedAppointments) {
    appointments = List.from(loadedAppointments);
    _sortAppointmentsInPlace();
    _syncFilteredAppointments();
    _resetPage();
  }

  void replaceAppointment(Appointment updatedAppointment) {
    final index = appointments
        .indexWhere((appointment) => appointment.id == updatedAppointment.id);
    if (index >= 0) {
      appointments[index] = updatedAppointment;
    } else {
      appointments.add(updatedAppointment);
    }
    _sortAppointmentsInPlace();
    _syncFilteredAppointments();
  }

  void removeAppointmentById(int appointmentId) {
    appointments.removeWhere((appointment) => appointment.id == appointmentId);
    _syncFilteredAppointments();
  }

  Future<void> loadAppointments({bool forceRefresh = false}) async {
    isLoading = true;
    notifyListeners();

    try {
      final currentUser = await appointmentProvider.getCurrentUser();
      final isAdmin = currentUser?.role == 'admin';
      final doctorName = currentUser?.doctor;
      List<Appointment> loaded = [];

      if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
        loaded = await appointmentProvider.getAppointmentsByDoctor(doctorName);
      } else {
        loaded = await appointmentProvider.getAllAppointments(
            forceRefresh: forceRefresh);
      }

      setAppointments(loaded);
    } catch (e) {
      appointments = [];
      filteredAppointments = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _filterAppointmentsByDate() {
    List<Appointment> base;
    if (!isFiltering) {
      base = List.from(appointments);
    } else if (isDateRangeFiltering) {
      final rangeEnd = endDate;
      if (rangeEnd == null) {
        base = List.from(appointments);
      } else {
        base = appointments.where((appointment) {
          final d = appointment.appointmentDate;
          final startDateTime =
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          final endDateTime =
              DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day, 23, 59, 59);
          return d.isAfter(startDateTime.subtract(const Duration(seconds: 1))) &&
              d.isBefore(endDateTime.add(const Duration(seconds: 1)));
        }).toList();
      }
    } else {
      base = appointments.where((appointment) {
        final d = appointment.appointmentDate;
        return d.year == selectedDate.year &&
            d.month == selectedDate.month &&
            d.day == selectedDate.day;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      base = base.where((a) {
        return _appointmentMatchesSearch(a, q);
      }).toList();
    }

    filteredAppointments = base;
    _resetPage();
    notifyListeners();
  }

  void selectDate(DateTime date) {
    selectedDate = date;
    endDate = null;
    isFiltering = true;
    isDateRangeFiltering = false;
    _filterAppointmentsByDate();
  }

  void selectDateRange(DateTime start, DateTime end) {
    selectedDate = start;
    endDate = end;
    isFiltering = true;
    isDateRangeFiltering = true;
    _filterAppointmentsByDate();
  }

  void toggleFiltering() {
    isFiltering = !isFiltering;
    if (!isFiltering) {
      isDateRangeFiltering = false;
      endDate = null;
    }
    _filterAppointmentsByDate();
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    _filterAppointmentsByDate();
  }

  bool _appointmentMatchesSearch(Appointment appointment, String query) {
    if (query.isEmpty) return true;

    final patient = appointment.patient;
    final date = appointment.appointmentDate;
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final slashDateText = dateText.replaceAll('-', '/');
    final monthDayText =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final timeText =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final values = <String?>[
      appointment.id?.toString(),
      appointment.patientId?.toString(),
      appointment.status,
      appointment.statusDisplay,
      appointment.treatmentType,
      appointment.notes,
      appointment.cost?.toString(),
      appointment.appointmentTime,
      dateText,
      slashDateText,
      monthDayText,
      timeText,
      patient?.name,
      patient?.namePinyin,
      if (patient != null) PinyinUtil.toPinyin(patient.name),
      if (patient != null)
        PinyinUtil.toPinyin(patient.name).replaceAll(' ', ''),
      patient?.nameInitials,
      if (patient != null) PinyinUtil.getInitials(patient.name),
      if (patient != null) PinyinUtil.getFirstLetters(patient.name),
      patient?.mainPhone,
      patient?.backupPhone,
      patient?.medicalRecordNumber?.toString(),
      patient?.doctor,
    ];

    return values
        .any((value) => value != null && value.toLowerCase().contains(query));
  }
}
