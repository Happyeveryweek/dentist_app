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

  Future<void> loadAppointments() async {
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
        loaded = await appointmentProvider.getAllAppointments();
      }

      loaded.sort((a, b) {
        final now = DateTime.now();
        final diffA = a.appointment_date.difference(now).inMinutes.abs();
        final diffB = b.appointment_date.difference(now).inMinutes.abs();

        if (a.appointment_date.isAfter(now) && b.appointment_date.isBefore(now)) {
          return -1;
        }
        if (a.appointment_date.isBefore(now) && b.appointment_date.isAfter(now)) {
          return 1;
        }
        return diffA.compareTo(diffB);
      });

      appointments = loaded;
      _filterAppointmentsByDate();
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
    } else if (isDateRangeFiltering && endDate != null) {
      base = appointments.where((appointment) {
        final d = appointment.appointment_date;
        final startDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        final endDateTime = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
        return d.isAfter(startDateTime.subtract(const Duration(seconds: 1))) && d.isBefore(endDateTime.add(const Duration(seconds: 1)));
      }).toList();
    } else {
      base = appointments.where((appointment) {
        final d = appointment.appointment_date;
        return d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      base = base.where((a) {
        return _appointmentMatchesSearch(a, q);
      }).toList();
    }

    filteredAppointments = base;
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
    final date = appointment.appointment_date;
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final slashDateText = dateText.replaceAll('-', '/');
    final monthDayText =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final timeText =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final values = <String?>[
      appointment.id?.toString(),
      appointment.patient_id?.toString(),
      appointment.status,
      appointment.statusDisplay,
      appointment.treatment_type,
      appointment.notes,
      appointment.cost?.toString(),
      appointment.appointment_time,
      dateText,
      slashDateText,
      monthDayText,
      timeText,
      patient?.name,
      patient?.name_pinyin,
      if (patient != null) PinyinUtil.toPinyin(patient.name),
      if (patient != null) PinyinUtil.toPinyin(patient.name).replaceAll(' ', ''),
      patient?.name_initials,
      if (patient != null) PinyinUtil.getInitials(patient.name),
      if (patient != null) PinyinUtil.getFirstLetters(patient.name),
      patient?.mainPhone,
      patient?.backupPhone,
      patient?.medical_record_number?.toString(),
      patient?.doctor,
    ];

    return values
        .any((value) => value != null && value.toLowerCase().contains(query));
  }
}
