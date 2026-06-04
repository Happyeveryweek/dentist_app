import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'appointment_search_filter_bar.dart';
import 'appointment_calendar_view.dart';
import 'appointment_card.dart';

class AppointmentsScreenBody extends StatelessWidget {
  final bool isLoading;
  final TabController tabController;
  final bool showCalendar;
  final CalendarFormat calendarFormat;
  final DateTime selectedDay;
  final DateTime focusedDay;
  final Map<DateTime, List<Appointment>> appointmentsByDay;
  final List<Appointment> selectedDayAppointments;
  final List<Appointment> filteredAppointments;
  final List<Appointment> todayAppointments;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onFilterPressed;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onAddAppointment;
  final Future<void> Function() onRefreshAll;
  final String Function(dynamic) formatTreatmentType;
  final Color Function(String) getPatientAvatarColor;
  final Future<String?> Function(Appointment) getAppointmentPatientDoctor;
  final Function(Appointment) onEditAppointment;
  final Function(Appointment) onDeleteAppointment;

  const AppointmentsScreenBody({
    super.key,
    required this.isLoading,
    required this.tabController,
    required this.showCalendar,
    required this.calendarFormat,
    required this.selectedDay,
    required this.focusedDay,
    required this.appointmentsByDay,
    required this.selectedDayAppointments,
    required this.filteredAppointments,
    required this.todayAppointments,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onFilterPressed,
    required this.onDaySelected,
    required this.onAddAppointment,
    required this.onRefreshAll,
    required this.formatTreatmentType,
    required this.getPatientAvatarColor,
    required this.getAppointmentPatientDoctor,
    required this.onEditAppointment,
    required this.onDeleteAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '加载预约数据中...',
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    AppointmentSearchFilterBar(
                      searchController: searchController,
                      searchQuery: '',
                      onSearchChanged: onSearchChanged,
                      onSearchSubmitted: onSearchSubmitted,
                      onClearSearch: onClearSearch,
                      onFilterPressed: onFilterPressed,
                    ),
                    Expanded(
                      child: showCalendar
                          ? AppointmentCalendarView(
                              focusedDay: focusedDay,
                              selectedDay: selectedDay,
                              calendarFormat: calendarFormat,
                              appointmentsByDay: appointmentsByDay,
                              selectedDayAppointments: selectedDayAppointments,
                              onDaySelected: onDaySelected,
                              buildAppointmentCard: _buildAppointmentCard,
                              onAddAppointment: onAddAppointment,
                            )
                          : TabBarView(
                              controller: tabController,
                              children: [
                                RefreshIndicator(
                                  onRefresh: onRefreshAll,
                                  child: _buildAppointmentList(
                                    context,
                                    filteredAppointments,
                                    emptyIcon: Icons.search_off,
                                    emptyText: '没有找到符合条件的预约',
                                  ),
                                ),
                                RefreshIndicator(
                                  onRefresh: onRefreshAll,
                                  child: _buildAppointmentList(
                                    context,
                                    todayAppointments,
                                    emptyIcon: Icons.today,
                                    emptyText: '今日无预约',
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '预约管理',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: AppTheme.primaryColor.withOpacity(0.1),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.secondaryText,
            tabs: const [Tab(text: '全部预约'), Tab(text: '今日预约')],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentList(
    BuildContext context,
    List<Appointment> appointments, {
    required IconData emptyIcon,
    required String emptyText,
  }) {
    if (appointments.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  emptyIcon,
                  size: 64,
                  color: AppTheme.lightText.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  emptyText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        return _buildAppointmentCard(appointments[index]);
      },
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return AppointmentCard(
      appointment: appointment,
      formatTreatmentType: formatTreatmentType,
      getPatientAvatarColor: getPatientAvatarColor,
      getAppointmentPatientDoctor: getAppointmentPatientDoctor,
      onEdit: onEditAppointment,
      onDelete: onDeleteAppointment,
    );
  }
}
