import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  Patient? _patient;
  bool _isLoading = true;
  bool _dataUpdated = false; // 标记数据是否已更新

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patient = await Provider.of<PatientProvider>(context, listen: false).getPatientById(
        widget.appointment.patientId,
      );

      setState(() {
        _patient = patient;
        _isLoading = false;
      });
    } catch (e) {
      print('加载患者数据错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 只有在数据更新时才返回true，否则返回null
        Navigator.of(context).pop(_dataUpdated ? true : null);
        return false;
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
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
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
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
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
                    AppointmentInfoCard(appointment: widget.appointment),
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
                          status: widget.appointment.status ?? '',
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
      print('拨打电话错误: $e');
      if (mounted) {
        ToastUtil.showInfo(context, '当前环境无法拨号，号码: $trimmed');
      }
    }
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool alignTop = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textColor,
              fontSize: 14,
              fontWeight:
                  valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditAppointment() async {
    // 导航到编辑预约页面
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: AppointmentFormSheet(
              appointment: widget.appointment,
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
                child: const Text('取消'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.secondaryText,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 先关闭对话框
                  _deleteAppointment(); // 再执行删除操作
                },
                child: const Text('确认删除'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
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
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
      await appointmentsProvider.deleteAppointment(widget.appointment.id!);

      // 返回上一页并通知更新
      if (!mounted) return;
      Navigator.of(context).pop(true); // 返回true表示数据已修改，需要刷新
      ToastUtil.showSuccess(context, '预约已成功删除');
    } catch (e) {
      print('删除预约错误: $e');
      if (!mounted) return;
      ToastUtil.showError(context, '删除预约失败: $e');
    }
  }

  // 获取状态信息
  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return AppTheme.infoColor;
      case 'completed':
      case '已完成':
        return AppTheme.successColor;
      case 'cancelled':
      case '已取消':
        return AppTheme.errorColor;
      case 'missed':
      case 'no_show':
      case '未到诊':
        return Colors.orange;
      default:
        return AppTheme.secondaryText;
    }
  }

  // 获取状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return '已预约';
      case 'completed':
      case '已完成':
        return '已完成';
      case 'cancelled':
      case '已取消':
        return '已取消';
      case 'missed':
      case 'no_show':
      case '未到诊':
        return '未到诊';
      default:
        return status; // 显示原始状态
    }
  }

  // 获取状态图标
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return Icons.schedule;
      case 'completed':
      case '已完成':
        return Icons.check_circle_outline;
      case 'cancelled':
      case '已取消':
        return Icons.cancel_outlined;
      case 'missed':
      case 'no_show':
      case '未到诊':
        return Icons.unpublished_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // 构建预约状态卡片
  Widget _buildAppointmentStatusCard() {
    final status = widget.appointment.status ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预约状态',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontSize: 16,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 获取预约关联患者的医生字段，用于权限检查
  Future<String?> _getAppointmentPatientDoctor() async {
    try {
      if (_patient != null) {
        return _patient!.doctor;
      }
      
      // 如果患者数据还没加载，尝试获取
      if (widget.appointment.patientId != null) {
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        final patient = await patientProvider.getPatientById(widget.appointment.patientId);
        return patient?.doctor;
      }
      
      return null;
    } catch (e) {
      print('获取预约患者医生信息失败: $e');
      return null;
    }
  }

  // 修改预约状态
  Future<void> _changeAppointmentStatus(String newStatus) async {
    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);

      // 创建更新后的预约对象
      final updatedAppointment = widget.appointment.copyWith(status: newStatus);

      // 更新预约状态
      await appointmentsProvider.updateAppointment(updatedAppointment);

      // 显示成功提示
      if (!mounted) return;
      ToastUtil.showSuccess(context, '预约状态已更新');

      // 标记数据已更新并返回上一页
      setState(() {
        _dataUpdated = true;
      });
      Navigator.of(context).pop(true); // 返回true表示数据已修改，需要刷新
    } catch (e) {
      print('更新预约状态错误: $e');
      if (!mounted) return;
      ToastUtil.showError(context, '更新预约状态失败: $e');
    }
  }
}

