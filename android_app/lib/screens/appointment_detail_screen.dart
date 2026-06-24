import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/features/appointments/widgets/appointment_form_sheet.dart';
import 'package:dentist_app/features/appointments/widgets/appointment_info_card.dart';
import 'package:dentist_app/features/appointments/widgets/patient_info_card.dart';
import 'package:dentist_app/features/appointments/widgets/appointment_action_buttons.dart';
import 'package:dentist_app/utils/toast_util.dart';
import 'package:dentist_app/utils/permission_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_logger.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
};

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Appointment _appointment;
  Patient? _patient;
  bool _isLoading = true;
  bool _dataUpdated = false; // 标记数据是否已更新

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patient = await Provider.of<PatientProvider>(
        context,
        listen: false,
      ).getPatientById(_appointment.patientId);

      setState(() {
        _patient = patient;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.info('加载患者数据错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 只有在数据更新时才返回true，否则返回null
          Navigator.of(context).pop(_dataUpdated ? true : null);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('预约详情'),
          centerTitle: true,
          backgroundColor: AppTheme.cardBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // 只有在数据更新时才返回true，否则返回null
              Navigator.of(context).pop(_dataUpdated ? true : null);
            },
          ),
          elevation: 0,
          actions: [
            // 编辑按钮
            FutureBuilder<String?>(
              future: _getAppointmentPatientDoctor(),
              builder: (context, snapshot) {
                final patientDoctor = snapshot.data;
                return PermissionWrapper(
                  module: 'appointments',
                  action: 'edit',
                  recordDoctor: patientDoctor,
                  onPermissionDenied: () {
                    PermissionUtils.showPermissionDeniedMessage(
                      context,
                      customMessage: '您只能编辑自己负责患者的预约',
                    );
                  },
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: _showEditAppointment,
                    tooltip: '编辑预约',
                  ),
                );
              },
            ),
            // 删除按钮
            FutureBuilder<String?>(
              future: _getAppointmentPatientDoctor(),
              builder: (context, snapshot) {
                final patientDoctor = snapshot.data;
                return PermissionWrapper(
                  module: 'appointments',
                  action: 'delete',
                  recordDoctor: patientDoctor,
                  onPermissionDenied: () {
                    PermissionUtils.showPermissionDeniedMessage(
                      context,
                      customMessage: '您只能删除自己负责患者的预约',
                    );
                  },
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorColor,
                    ),
                    onPressed: _showDeleteConfirmation,
                    tooltip: '删除预约',
                  ),
                );
              },
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppointmentInfoCard(appointment: _appointment),
                      const SizedBox(height: 16),
                      PatientInfoCard(
                        patient: _patient,
                        onPhoneCall: _callPhoneNumber,
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<String?>(
                        future: _getAppointmentPatientDoctor(),
                        builder: (context, snapshot) {
                          final patientDoctor = snapshot.data;
                          return AppointmentActionButtons(
                            status: _appointment.status,
                            patientDoctor: patientDoctor,
                            onChangeStatus: (newStatus) {
                              _changeAppointmentStatus(newStatus);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final trimmed = phoneNumber.trim();
    if (trimmed.isEmpty || trimmed == '未设置') {
      if (mounted) {
        ToastUtil.showInfo(context, '无效的电话号码');
      }
      return;
    }

    final launchUri = Uri(scheme: 'tel', path: trimmed);

    try {
      final launched = await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ToastUtil.showInfo(context, '无法打开拨号界面: $trimmed');
      }
    } catch (e) {
      AppLogger.info('拨打电话错误: $e');
      if (mounted) {
        ToastUtil.showInfo(context, '当前环境无法拨号，号码: $trimmed');
      }
    }
  }

  Future<void> _showEditAppointment() async {
    // 导航到编辑预约页面
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              resizeToAvoidBottomInset: true,
              body: SafeArea(
                child: AppointmentFormSheet(
                  appointment: _appointment,
                  onSaved: (isSuccess, message) {
                    if (isSuccess) {
                      // 刷新页面数据
                      _loadPatientData();
                      ToastUtil.showSuccess(context, message);
                      // 标记数据已更新
                      setState(() {
                        _dataUpdated = true;
                      });
                      Navigator.of(context).pop(true);
                    } else {
                      ToastUtil.showError(context, message);
                      Navigator.of(context).pop(false);
                    }
                  },
                ),
              ),
            ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除此预约吗？此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.secondaryText,
                ),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 先关闭对话框
                  _deleteAppointment(); // 再执行删除操作
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('确认删除'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAppointment() async {
    if (widget.appointment.id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法删除：预约ID无效')));
      return;
    }

    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(
        context,
        listen: false,
      );
      await appointmentsProvider.deleteAppointment(_appointment.id!);

      // 返回上一页并通知更新
      if (!mounted) return;
      Navigator.of(context).pop(true); // 返回true表示数据已修改，需要刷新
      ToastUtil.showSuccess(context, '预约已成功删除');
    } catch (e) {
      AppLogger.info('删除预约错误: $e');
      if (!mounted) return;
      ToastUtil.showError(context, '删除预约失败: $e');
    }
  }

  /// 获取预约关联患者的医生字段，用于权限检查
  Future<String?> _getAppointmentPatientDoctor() async {
    try {
      if (_patient != null) {
        return _patient!.doctor;
      }

      // 如果患者数据还没加载，尝试获取
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      final patient = await patientProvider.getPatientById(
        _appointment.patientId,
      );
      return patient?.doctor;
    } catch (e) {
      AppLogger.info('获取预约患者医生信息失败: $e');
      return null;
    }
  }

  // 修改预约状态
  Future<void> _changeAppointmentStatus(String newStatus) async {
    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(
        context,
        listen: false,
      );

      // 创建更新后的预约对象
      final updatedAppointment = _appointment.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      // 更新预约状态
      await appointmentsProvider.updateAppointment(updatedAppointment);

      setState(() {
        _appointment = updatedAppointment;
        _dataUpdated = true;
      });

      // 显示成功提示
      if (!mounted) return;
      ToastUtil.showSuccess(context, '预约状态已更新');
    } catch (e) {
      AppLogger.info('更新预约状态错误: $e');
      if (!mounted) return;
      ToastUtil.showError(context, '更新预约状态失败: $e');
    }
  }
}
