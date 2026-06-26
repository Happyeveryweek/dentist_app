import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/appointment.dart';
import '../../../widgets/dental_icons.dart';

class PatientAppointmentsEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const PatientAppointmentsEmptyState({
    Key? key,
    required this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            '暂无预约记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加预约'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String treatmentTypeText;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEditDenied;
  final VoidCallback onDeleteDenied;

  const PatientAppointmentCard({
    Key? key,
    required this.appointment,
    required this.treatmentTypeText,
    required this.canEdit,
    required this.canDelete,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onEditDenied,
    required this.onDeleteDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appointment.status);
    final treatmentType = appointment.treatmentType;
    final notes = appointment.notes;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: onView,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.event,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(appointment.appointmentDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                appointment.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (treatmentType != null &&
                            treatmentType.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      DentalIcons.tooth,
                                      size: 16,
                                      color: Colors.blue.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '牙位信息',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  treatmentTypeText,
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (treatmentType != null &&
                            treatmentType.isNotEmpty)
                          const SizedBox(height: 4),
                        if (notes != null && notes.isNotEmpty)
                          Text(
                            '备注: $notes',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('查看'),
                  onPressed: onView,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                canEdit
                    ? TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('编辑'),
                        onPressed: onEdit,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      )
                    : TextButton.icon(
                        icon: const Icon(Icons.lock, size: 18),
                        label: const Text('权限不足'),
                        onPressed: onEditDenied,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                      ),
                canDelete
                    ? TextButton.icon(
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('删除'),
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      )
                    : TextButton.icon(
                        icon: const Icon(Icons.lock, size: 18),
                        label: const Text('权限不足'),
                        onPressed: onDeleteDenied,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已完成':
        return Colors.green;
      case '已取消':
        return Colors.red;
      case '待确认':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
