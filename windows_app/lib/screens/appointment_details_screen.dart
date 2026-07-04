import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../models/appointment.dart';
import '../models/patient.dart';
import '../providers/appointment_provider.dart';
import '../providers/patient_provider.dart';
import '../features/dashboard/helpers/dashboard_status_helper.dart';
import '../widgets/dental_icons.dart';
import '../features/appointments/widgets/appointment_details_summary_card.dart';
import '../features/appointments/widgets/appointment_details_treatment_section.dart';
import '../features/appointments/widgets/appointment_details_teeth_section.dart';
import '../features/appointments/widgets/appointment_details_patient_card.dart';
import '../features/appointments/widgets/appointment_form_dialog.dart';
import '../utils/permission_utils.dart';
import '../widgets/success_toast.dart';
import './patient_detail_screen.dart';
import '../utils/log_manager.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../theme/app_theme.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
};

// 十字画笔

// 只读十字图显示组件

class AppointmentDetailsScreen extends StatefulWidget {
  final int appointmentId;

  const AppointmentDetailsScreen({
    Key? key,
    required this.appointmentId,
  }) : super(key: key);

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  Appointment? _appointment;
  Patient? _patient;
  bool _isLoading = true;

  // 预约详情数据
  List<Map<String, String>> _teethData = [];

  @override
  void initState() {
    super.initState();
    _loadAppointmentData();
  }

  Future<void> _loadAppointmentData() async {
    setState(() => _isLoading = true);

    try {
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final appointmentProvider =
          Provider.of<AppointmentProvider>(context, listen: false);

      // 获取预约详情
      final appointments = await appointmentProvider.getAllAppointments();
      final appointment = appointments.firstWhere(
        (a) => a.id == widget.appointmentId,
        orElse: () => throw Exception('预约不存在'),
      );

      // 获取患者信息
      final patientId = appointment.patientId;
      final patient = patientId != null
          ? await patientProvider.getPatient(patientId)
          : null;

      // 解析treatment_type字段，获取牙齿情况和治疗项目
      final treatmentType = appointment.treatmentType;
      if (treatmentType != null) {
        _parseTreatmentTypeData(treatmentType);
      }

      setState(() {
        _appointment = appointment;
        _patient = patient;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载预约数据失败: $e'), backgroundColor: Colors.red),
      );
      Navigator.of(context).pop();
    }
  }

  // 解析treatment_type字段中的数据
  void _parseTreatmentTypeData(String treatmentTypeStr) {
    try {
      // 尝试解析为JSON
      final decoded = json.decode(treatmentTypeStr);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final data = decoded;

      // 提取牙齿情况数据
      if (data.containsKey('teethData')) {
        var teethJsonData = data['teethData'];
        _teethData = List<Map<String, String>>.from(
            teethJsonData.map((item) => Map<String, String>.from(item)));
      }

      // 提取治疗项目数据
      if (data.containsKey('treatments') || data.containsKey('treatmentTypes')) {
        // 治疗项目数据已包含在 treatment_type 中，但当前界面未使用
      }
    } catch (e) {
      // 如果解析失败，可能是旧数据格式，直接设为治疗项目
      LogManager.e('AppointmentDetailsScreen', '解析treatment_type失败', error: e);

      // 如果治疗类型包含多个项目（用顿号分隔），则解析为多选项目
      if (treatmentTypeStr.contains('、')) {
        // 治疗项目数据未在界面中使用
      } else if (treatmentTypeStr.isNotEmpty) {
        // 治疗项目数据未在界面中使用
      }
    }
  }

  void _applyAppointmentLocally(Appointment appointment) {
    _appointment = appointment;
    _patient = appointment.patient ?? _patient;
    _teethData = [];

    final treatmentType = appointment.treatmentType;
    if (treatmentType != null) {
      _parseTreatmentTypeData(treatmentType);
    }
  }

  void _changeAppointmentStatus(String newStatus) async {
    final appointment = _appointment;
    if (appointment == null) return;

    final appointmentProvider =
        Provider.of<AppointmentProvider>(context, listen: false);

    try {
      final updatedAppointment = appointment.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await appointmentProvider.updateAppointment(updatedAppointment);

      if (!mounted) return;
      setState(() {
        _applyAppointmentLocally(updatedAppointment);
      });

      final statusColor = DashboardStatusHelper.getStatusColor(newStatus);
      AppToastManager.showSuccess(
        context,
        message: '预约状态已更新为: $newStatus',
        backgroundColor: statusColor,
      );
    } catch (e) {
      AppToastManager.showError(
        context,
        message: '更新预约状态失败: $e',
      );
    }
  }

  Future<void> _showEditAppointmentDialog() async {
    final appointment = _appointment;
    if (appointment == null) return;

    if (!PermissionUtils.canEditDoctor(
        context, appointment.patient?.doctor ?? _patient?.doctor)) {
      AppToastManager.showError(
        context,
        message: '您只能编辑自己医生患者的预约',
      );
      return;
    }

    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: appointment.appointmentDate,
        appointment: appointment,
        preselectedPatient: _patient,
      ),
    );

    if (result == null) return;

    if (!mounted) return;
    final appointmentProvider =
        Provider.of<AppointmentProvider>(context, listen: false);

    try {
      await appointmentProvider.updateAppointment(result);

      if (!mounted) return;
      setState(() {
        _applyAppointmentLocally(result);
      });

      AppToastManager.showSuccess(context, message: '预约已更新');
    } catch (e) {
      if (!mounted) return;
      AppToastManager.showError(context, message: '更新预约失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.event_note_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Builder(builder: (context) {
              final appointment = _appointment;
              return Text(
                _isLoading || appointment == null
                    ? '预约详情'
                    : '预约: ${DateFormat('MM/dd HH:mm').format(appointment.appointmentDate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              );
            }),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          if (!_isLoading && _appointment != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: DentalColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DentalColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.edit_rounded,
                  color: DentalColors.warning,
                ),
                tooltip: '编辑预约',
                onPressed: _showEditAppointmentDialog,
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: DentalColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.info.withValues(alpha: 0.3),
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: DentalColors.info,
              ),
              tooltip: '刷新',
              onPressed: _loadAppointmentData,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final appointment = _appointment;
    if (appointment == null) {
      return const Center(child: Text('预约信息不存在'));
    }

    final patient = _patient;
    final notes = appointment.notes;
    final cost = appointment.cost;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppointmentDetailsSummaryCard(appointment: appointment),
          const SizedBox(height: 16),
          AppointmentDetailsTeethSection(teethData: _teethData),
          const SizedBox(height: 16),
          AppointmentDetailsTreatmentSection(appointment: appointment),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      context.tokens.divider.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.update_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      '更新预约状态',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusButton(appointment, '已预约', Colors.blue),
                    _buildStatusButton(appointment, '已完成', Colors.green),
                    _buildStatusButton(appointment, '已取消', Colors.red),
                    _buildStatusButton(appointment, '未到诊', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (notes != null && notes.isNotEmpty)
            _buildInfoRow('备注', notes),
          if (cost != null)
            _buildInfoRow(
                '费用', '¥${cost.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          if (patient != null)
            AppointmentDetailsPatientCard(
              patient: patient,
              onViewDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PatientDetailScreen(patient: patient),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(Appointment appointment, String status, Color color) {
    final isCurrentStatus = appointment.status == status;

    // 获取状态对应的转换后状态文本
    String statusText;
    switch (status) {
      case '已预约':
        statusText = '已预约';
        break;
      case '已完成':
        statusText = '已完成';
        break;
      case '已取消':
        statusText = '已取消';
        break;
      case '未到诊':
        statusText = '未到诊';
        break;
      default:
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      child: InkWell(
        onTap: isCurrentStatus ? null : () => _changeAppointmentStatus(status),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrentStatus ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isCurrentStatus ? 1.0 : 0.6),
              width: 1,
            ),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: isCurrentStatus ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.divider.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.tokens.primaryAccent.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.tokens.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: context.tokens.primaryAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.tokens.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
