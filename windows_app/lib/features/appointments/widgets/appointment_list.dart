import 'package:flutter/material.dart';
import '../../../models/appointment.dart';
import '../../../theme/theme_context_extensions.dart';
import 'appointment_card.dart';

class AppointmentList extends StatelessWidget {
  final List<Appointment> appointments;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Function(Appointment) onView;
  final Function(Appointment) onEdit;
  final Function(Appointment) onDelete;
  final Function(Appointment, String) onStatusChanged;

  const AppointmentList({
    Key? key,
    required this.appointments,
    required this.isLoading,
    required this.onRefresh,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appointments.isEmpty) {
      return Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note, size: 64, color: context.tokens.iconMuted),
          const SizedBox(height: 12),
          const Text('暂无预约记录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: appointments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ap = appointments[index];
          return AppointmentCard(
            appointment: ap,
            onView: () => onView(ap),
            onEdit: () => onEdit(ap),
            onDelete: () => onDelete(ap),
            onStatusChanged: (status) => onStatusChanged(ap, status),
          );
        },
      ),
    );
  }
}
