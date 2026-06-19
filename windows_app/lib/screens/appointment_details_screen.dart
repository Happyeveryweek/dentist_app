import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../models/patient.dart';
import '../providers/database_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/app_state.dart';
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
  List<String> _treatments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointmentData();
  }

  Future<void> _loadAppointmentData() async {
    setState(() => _isLoading = true);

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);

      // 获取预约详情
      final appointments = await appointmentProvider.getAllAppointments();
      final appointment = appointments.firstWhere(
        (a) => a.id == widget.appointmentId,
        orElse: () => throw Exception('预约不存在'),
      );

      // 获取患者信息
      final patient = appointment.patientId != null
          ? await patientProvider.getPatient(appointment.patientId!)
          : null;

      // 解析treatment_type字段，获取牙齿情况和治疗项目
      if (appointment.treatment_type != null) {
        _parseTreatmentTypeData(appointment.treatment_type!);
      }

      setState(() {
        _appointment = appointment;
        _patient = patient;
        _isLoading = false;
      });
    } catch (e) {
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
      Map<String, dynamic> data = json.decode(treatmentTypeStr);

      // 提取牙齿情况数据
      if (data.containsKey('teethData')) {
        var teethJsonData = data['teethData'];
        _teethData = List<Map<String, String>>.from(
            teethJsonData.map((item) => Map<String, String>.from(item)));
      }

      // 提取治疗项目数据
      if (data.containsKey('treatments')) {
        _treatments = List<String>.from(data['treatments']);
      }
    } catch (e) {
      // 如果解析失败，可能是旧数据格式，直接设为治疗项目
      print('解析treatment_type失败: $e');

      // 如果治疗类型包含多个项目（用顿号分隔），则解析为多选项目
      if (treatmentTypeStr.contains('、')) {
        _treatments = treatmentTypeStr.split('、');
      } else if (treatmentTypeStr.isNotEmpty) {
        _treatments = [treatmentTypeStr];
      }
    }
  }

  void _changeAppointmentStatus(String newStatus) async {
    if (_appointment == null) return;

    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      // 创建更新后的预约对象
      var updatedAppointment = Appointment(
        id: _appointment!.id,
        patient_id: _appointment!.patient_id,
        patient: _appointment!.patient,
        appointment_date: _appointment!.appointment_date,
        status: newStatus,
        treatment_type: _appointment!.treatment_type,
        notes: _appointment!.notes,
        cost: _appointment!.cost,
        created_at: _appointment!.created_at,
        updated_at: DateTime.now(),
      );

      // 添加防重复提交保护
      await appState.showLoading(
        appointmentProvider.updateAppointment(updatedAppointment),
        message: '正在更新状态...',
      );

      // 重新加载数据
      _loadAppointmentData();

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
    if (_appointment == null) return;

    if (!PermissionUtils.canEditDoctor(context, _appointment!.patient?.doctor ?? _patient?.doctor)) {
      AppToastManager.showError(
        context,
        message: '您只能编辑自己医生患者的预约',
      );
      return;
    }

    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: _appointment!.appointment_date,
        appointment: _appointment,
        preselectedPatient: _patient,
      ),
    );

    if (result == null) return;

    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await appState.showLoading(
        appointmentProvider.updateAppointment(result),
        message: '正在更新预约...',
      );

      await _loadAppointmentData();
      if (!mounted) return;
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
                gradient: DentalColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_note_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isLoading
                  ? '预约详情'
                  : '预约: ${DateFormat('MM/dd HH:mm').format(_appointment!.appointmentDate)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
        actions: [
          if (!_isLoading && _appointment != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: DentalColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DentalColors.warning.withOpacity(0.3),
                ),
              ),
              child: IconButton(
                icon: Icon(
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
              color: DentalColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.info.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
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
          : _appointment == null
              ? const Center(child: Text('预约信息不存在'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppointmentDetailsSummaryCard(appointment: _appointment!),
                      const SizedBox(height: 16),
                      AppointmentDetailsTeethSection(teethData: _teethData),
                      const SizedBox(height: 16),
                      AppointmentDetailsTreatmentSection(appointment: _appointment!),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DentalColors.divider.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.update_rounded, size: 16, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(
                                  '更新预约状态',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: DentalColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusButton('已预约', Colors.blue),
                                _buildStatusButton('已完成', Colors.green),
                                _buildStatusButton('已取消', Colors.red),
                                _buildStatusButton('未到诊', Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_appointment!.notes != null && _appointment!.notes!.isNotEmpty)
                        _buildInfoRow('备注', _appointment!.notes!),
                      if (_appointment!.cost != null)
                        _buildInfoRow('费用', '¥${_appointment!.cost!.toStringAsFixed(2)}'),
                      const SizedBox(height: 12),
                      if (_patient != null)
                        AppointmentDetailsPatientCard(
                          patient: _patient!,
                          onViewDetails: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PatientDetailScreen(patient: _patient!),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusButton(String status, Color color) {
    final isCurrentStatus = _appointment!.status == status;

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
              color: color.withOpacity(isCurrentStatus ? 1.0 : 0.6),
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
        color: DentalColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DentalColors.divider.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: DentalColors.primary.withOpacity(0.05),
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
              color: DentalColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: DentalColors.primary,
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
                    color: DentalColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: DentalColors.onSurface,
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
