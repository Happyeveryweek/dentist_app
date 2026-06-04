import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../providers/appointment_provider.dart';

class AppointmentStateService extends ChangeNotifier {
  final AppointmentProvider appointmentProvider;

  AppointmentStateService({required this.appointmentProvider});

  DateTime selectedDate = DateTime.now();
  DateTime? endDate;
  List<Appointment> appointments = [];
  List<Appointment> filteredAppointments = [];
  bool isLoading = false;
  bool showAllAppointments = true;
  bool isFiltering = false;
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
      final q = searchQuery.toLowerCase();
      base = base.where((a) {
        final name = (a.patient?.name ?? '').toLowerCase();
        final notes = (a.notes ?? '').toLowerCase();
        return name.contains(q) || notes.contains(q);
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
}
