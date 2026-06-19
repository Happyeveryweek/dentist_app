import 'package:flutter/material.dart';
import 'dart:convert';

import '../../../models/appointment.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/success_toast.dart';

class AppointmentCard extends StatefulWidget {
  final Appointment appointment;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onStatusChanged;

  const AppointmentCard({
    Key? key,
    required this.appointment,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onStatusChanged,
  }) : super(key: key);

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  static const List<String> _statusOptions = ['已预约', '已完成', '已取消', '未到诊'];
  bool _isHovered = false;

  String _formatAppointmentTime(DateTime dateTime) {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatAppointmentDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatTreatmentTypeForDisplay(String? treatmentTypeStr) {
    if (treatmentTypeStr == null || treatmentTypeStr.isEmpty) {
      return '常规复诊';
    }

    try {
      final Map<String, dynamic> data = json.decode(treatmentTypeStr);
      final List<String> displayParts = [];

      if (data.containsKey('teethData') &&
          data['teethData'] is List &&
          (data['teethData'] as List).isNotEmpty) {
        final List teethData = data['teethData'];

        for (int i = 0; i < teethData.length; i++) {
          final List<String> positions = [];
          final Map<String, dynamic> tooth = Map<String, dynamic>.from(teethData[i]);

          final fieldMapping = {
            'topLeft': '右上',
            'topRight': '左上',
            'bottomLeft': '右下',
            'bottomRight': '左下',
            'upperLeft': '右上',
            'upperRight': '左上',
            'lowerLeft': '右下',
            'lowerRight': '左下',
          };

          fieldMapping.forEach((field, label) {
            if (tooth.containsKey(field) &&
                tooth[field] != null &&
                tooth[field].toString().isNotEmpty) {
              positions.add('$label ${tooth[field]}');
            }
          });

          if (positions.isNotEmpty) {
            displayParts.add('牙位${i + 1}: ${positions.join('，')}');
          }
        }
      }

      if (data.containsKey('treatments') && data['treatments'] is List) {
        final List<String> treatments = List<String>.from(data['treatments']);
        if (treatments.isNotEmpty) {
          if (displayParts.isNotEmpty) {
            displayParts.add('- ${treatments.join("、")}');
          } else {
            displayParts.add(treatments.join("、"));
          }
        }
      }

      return displayParts.isNotEmpty ? displayParts.join(' ') : '常规复诊';
    } catch (e) {
      return treatmentTypeStr;
    }
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildStatusSelector(Color statusColor) {
    final currentStatus = _statusOptions.contains(widget.appointment.statusDisplay)
        ? widget.appointment.statusDisplay
        : _statusOptions.first;

    return Container(
      height: 15,
      padding: const EdgeInsets.only(left: 5, right: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.28),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: statusColor.withOpacity(0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          isDense: true,
          itemHeight: 48,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Colors.white.withOpacity(0.72),
          focusColor: Colors.transparent,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 12,
            color: statusColor,
          ),
          style: TextStyle(
            color: statusColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
          menuMaxHeight: 220,
          items: _statusOptions
              .map(
                (status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor.withOpacity(0.92),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: widget.onStatusChanged == null
              ? null
              : (status) {
                  if (status != null && status != widget.appointment.statusDisplay) {
                    widget.onStatusChanged!(status);
                  }
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentDate = widget.appointment.appointment_date;
    final appointmentDateStr = _formatAppointmentDate(appointmentDate);
    final appointmentTimeStr = _formatAppointmentTime(appointmentDate);

    final statusColor = Color(
      int.parse(widget.appointment.statusColor.replaceAll('#', '0xff')),
    );

    final gender = widget.appointment.patient?.gender ?? '';
    final treatmentDisplay = _formatTreatmentTypeForDisplay(widget.appointment.treatment_type);

    return DentalCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      color: _isHovered ? const Color(0xFFEAF4FF) : Colors.white,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (mounted) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          if (mounted) {
            setState(() => _isHovered = false);
          }
        },
        child: InkWell(
          onTap: widget.onView,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                DentalAvatar(
                  gender: gender,
                  name: widget.appointment.patient?.name ?? "未知",
                  size: 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.appointment.patient?.name ?? "未知患者",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: DentalColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildStatusSelector(statusColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: DentalColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 10,
                                  color: DentalColors.info,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$appointmentDateStr $appointmentTimeStr',
                                  style: TextStyle(
                                    color: DentalColors.info,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  DentalIcons.tooth,
                                  size: 11,
                                  color: DentalColors.primary.withOpacity(0.7),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    treatmentDisplay,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: DentalColors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.appointment.cost != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: DentalColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    size: 10,
                                    color: DentalColors.success,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '¥${widget.appointment.cost!.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: DentalColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactActionButton(
                      icon: Icons.visibility_rounded,
                      color: DentalColors.info,
                      tooltip: '查看',
                      onPressed: widget.onView ?? () {},
                    ),
                    const SizedBox(width: 6),
                    widget.onEdit != null
                        ? _buildCompactActionButton(
                            icon: Icons.edit_rounded,
                            color: DentalColors.warning,
                            tooltip: '编辑',
                            onPressed: widget.onEdit!,
                          )
                        : _buildCompactActionButton(
                            icon: Icons.lock,
                            color: Colors.grey,
                            tooltip: '权限不足',
                            onPressed: () => AppToastManager.showError(
                              context,
                              message: '您只能编辑自己医生患者的预约',
                            ),
                          ),
                    const SizedBox(width: 6),
                    widget.onDelete != null
                        ? _buildCompactActionButton(
                            icon: Icons.delete_rounded,
                            color: DentalColors.error,
                            tooltip: '删除',
                            onPressed: widget.onDelete!,
                          )
                        : _buildCompactActionButton(
                            icon: Icons.lock,
                            color: Colors.grey,
                            tooltip: '权限不足',
                            onPressed: () => AppToastManager.showError(
                              context,
                              message: '您只能删除自己医生患者的预约',
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
