import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/utils/permission_utils.dart';

class AppointmentCalendarView extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final Map<DateTime, List<Appointment>> appointmentsByDay;
  final List<Appointment> selectedDayAppointments;
  final Function(DateTime, DateTime) onDaySelected;
  final Widget Function(Appointment) buildAppointmentCard;
  final Function(DateTime) onAddAppointment;

  const AppointmentCalendarView({
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.appointmentsByDay,
    required this.selectedDayAppointments,
    required this.onDaySelected,
    required this.buildAppointmentCard,
    required this.onAddAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay,
              calendarFormat: calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppTheme.primaryColor,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppTheme.primaryColor,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markersAlignment: Alignment.bottomCenter,
                markerDecoration: const BoxDecoration(
                  color: AppTheme.secondaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              selectedDayPredicate: (day) {
                return isSameDay(selectedDay, day);
              },
              onDaySelected: onDaySelected,
              eventLoader: (day) {
                final dateOnly = DateTime(day.year, day.month, day.day);
                return appointmentsByDay[dateOnly] ?? [];
              },
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${DateFormat('MM月dd日').format(selectedDay)} 预约',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              Text(
                '共 ${selectedDayAppointments.length} 个预约',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: selectedDayAppointments.isEmpty
              ? SingleChildScrollView(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: AppTheme.lightText.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '当天无预约',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        PermissionWrapper(
                          module: 'appointments',
                          action: 'create',
                          hideWhenDenied: true,
                          child: ElevatedButton.icon(
                            onPressed: () => onAddAppointment(selectedDay),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加预约'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.borderRadius,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: selectedDayAppointments.length,
                  itemBuilder: (context, index) {
                    final appointment = selectedDayAppointments[index];
                    return buildAppointmentCard(appointment);
                  },
                ),
        ),
      ],
    );
  }
}
