import 'package:flutter/material.dart';
import 'dart:convert';

import '../../../theme/app_theme.dart';
import '../../../models/appointment.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/success_toast.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AppointmentCard({
    Key? key,
    required this.appointment,
    this.onView,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  String _formatAppointmentTime(DateTime dateTime) {
    // Keep simple formatting to avoid importing intl here
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatAppointmentDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  // 格式化显示治疗类型和牙位信息
  String _formatTreatmentTypeForDisplay(String? treatmentTypeStr) {
    if (treatmentTypeStr == null || treatmentTypeStr.isEmpty) {
      return '常规复诊';
    }

    try {
      // 尝试解析JSON数据
      Map<String, dynamic> data = json.decode(treatmentTypeStr);
      List<String> displayParts = [];

      // 处理牙位信息
      if (data.containsKey('teethData') &&
          data['teethData'] is List &&
          (data['teethData'] as List).isNotEmpty) {
        List teethData = data['teethData'];

        for (int i = 0; i < teethData.length; i++) {
          List<String> positions = [];
          Map<String, dynamic> tooth = Map<String, dynamic>.from(teethData[i]);

          // 检查所有可能的字段名称
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

      // 处理治疗项目
      if (data.containsKey('treatments') && data['treatments'] is List) {
        List<String> treatments = List<String>.from(data['treatments']);
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
      // 如果不是JSON格式，直接返回原始字符串
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
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

  @override
  Widget build(BuildContext context) {
    final appointmentDate = appointment.appointment_date;
    final appointmentDateStr = _formatAppointmentDate(appointmentDate);
    final appointmentTimeStr = _formatAppointmentTime(appointmentDate);

    Color statusColor = Color(
      int.parse(appointment.statusColor.replaceAll('#', '0xff')),
    );

    final gender = appointment.patient?.gender ?? '';

    String treatmentDisplay = _formatTreatmentTypeForDisplay(appointment.treatment_type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: DentalCard(
        color: Colors.white,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(12),
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                DentalAvatar(
                  gender: gender,
                  name: appointment.patient?.name ?? "未知",
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            appointment.patient?.name ?? "未知患者",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: DentalColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              appointment.statusDisplay,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
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
                                  size: 11,
                                  color: DentalColors.info,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$appointmentDateStr $appointmentTimeStr',
                                  style: TextStyle(
                                    color: DentalColors.info,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  DentalIcons.tooth,
                                  size: 12,
                                  color: DentalColors.primary.withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    treatmentDisplay,
                                    style: TextStyle(
                                      fontSize: 12,
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
                          if (appointment.cost != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
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
                                    size: 11,
                                    color: DentalColors.success,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '¥${appointment.cost!.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
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
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactActionButton(
                      icon: Icons.visibility_rounded,
                      color: DentalColors.info,
                      tooltip: '查看',
                      onPressed: onView ?? () {},
                    ),
                    const SizedBox(width: 6),
                    onEdit != null
                        ? _buildCompactActionButton(
                            icon: Icons.edit_rounded,
                            color: DentalColors.warning,
                            tooltip: '编辑',
                            onPressed: onEdit!,
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
                    onDelete != null
                        ? _buildCompactActionButton(
                            icon: Icons.delete_rounded,
                            color: DentalColors.error,
                            tooltip: '删除',
                            onPressed: onDelete!,
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
