import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

import '../providers/appointment_provider.dart';
import '../providers/user_provider.dart';
import '../providers/app_state.dart';
import './appointment_details_screen.dart';
import '../features/appointments/widgets/appointment_form_dialog.dart';
import '../widgets/dental_icons.dart';
import '../widgets/mysql_connection_warning.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../widgets/success_toast.dart';
import '../features/appointments/widgets/appointment_card.dart';
import '../utils/permission_utils.dart';
import '../features/appointments/widgets/appointment_filter_bar.dart';
import '../features/appointments/widgets/appointment_list.dart';
import '../features/appointments/services/appointment_state_service.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
  // 保留旧键名的映射以兼容旧数据
  'upperLeft': '右上',
  'upperRight': '左上',
  'lowerLeft': '右下',
  'lowerRight': '左下',
};

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  AppointmentStateService? _stateService;
  AppointmentProvider? _appointmentProvider;
  bool _appointmentProviderListenerAttached = false;
  bool _patientDropdownOpen = false;
  final TextEditingController _patientSearchController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Patient> _filteredPatients = [];
  List<Patient> _patients = [];
  bool _isLoadingPatients = true;

  // 治疗类型选项
  List<String> _treatmentTypes = [];
  List<String> _selectedTreatments = [];

  @override
  void initState() {
    super.initState();
    // 移动加载到 state service 初始化后
  }

  @override
  void dispose() {
    if (_appointmentProvider != null && _appointmentProviderListenerAttached) {
      _appointmentProvider!.removeListener(_handleAppointmentProviderChanged);
    }
    _patientSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleAppointmentProviderChanged() {
    if (!mounted || _stateService == null || _appointmentProvider == null) {
      return;
    }

    if (!_appointmentProvider!.hasValidCache) {
      return;
    }

    _stateService!.setAppointments(_appointmentProvider!.cachedAppointments);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appointmentProvider =
        Provider.of<AppointmentProvider>(context, listen: false);
    _appointmentProvider = appointmentProvider;
    final stateService = _stateService ??=
        AppointmentStateService(appointmentProvider: appointmentProvider);

    if (!_appointmentProviderListenerAttached) {
      appointmentProvider.addListener(_handleAppointmentProviderChanged);
      _appointmentProviderListenerAttached = true;
    }

    stateService.loadAppointments();

    if (appointmentProvider.appointmentsNeedRefresh) {
      appointmentProvider.resetAppointmentsRefreshFlag();
    }
  }

  // 预约状态管理已下沉到 `AppointmentStateService`，屏幕通过该 service 订阅更新并触发加载/筛选操作。

  String _formatAppointmentTime(DateTime dateTime) {
    return DateFormat.Hm().format(dateTime);
  }

  String _formatAppointmentDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  Future<void> _showAddEditAppointmentDialog([Appointment? appointment]) async {
    final bool isEditing = appointment != null;

    // 检查权限
    if (isEditing &&
        !PermissionUtils.canEditDoctor(context, appointment?.patient?.doctor)) {
      AppToastManager.showError(
        context,
        message: '您只能编辑自己医生患者的预约',
      );
      return;
    }

    // 所有登录用户都可以添加预约，编辑时检查医生权限

    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: _stateService!.selectedDate,
        appointment: appointment,
      ),
    );

    if (result != null) {
      final appointmentProvider =
          Provider.of<AppointmentProvider>(context, listen: false);

      try {
        if (isEditing) {
          await appointmentProvider.updateAppointment(result);
          _stateService?.replaceAppointment(result);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '预约已更新',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          );
        } else {
          final appState = Provider.of<AppState>(context, listen: false);
          // 添加防重复提交保护
          await appState.showLoading(
            appointmentProvider.addAppointment(result),
            message: '正在添加预约...',
          );

          // 使用公用成功提示组件
          AppToastManager.showSuccess(context, message: '预约已添加');
        }
      } catch (e) {
        // 显示错误提示
        AppToastManager.showError(context,
            message: '${isEditing ? "更新" : "添加"}预约失败: $e');
      }
    }
  }

  Future<void> _confirmDeleteAppointment(Appointment appointment) async {
    // 检查删除权限
    if (!PermissionUtils.canDeleteDoctor(
        context, appointment.patient?.doctor)) {
      AppToastManager.showError(
        context,
        message: '您只能删除自己医生患者的预约',
      );
      return;
    }

    final confirmed = await DeleteConfirmDialogManager.showAppointmentDelete(
      context,
      appointmentInfo: '${appointment.patient?.name ?? "未知患者"}的预约',
    );

    if (confirmed == true) {
      final appointmentProvider =
          Provider.of<AppointmentProvider>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);

      try {
        // 添加防重复提交保护
        await appState.showLoading(
          appointmentProvider.deleteAppointment(appointment.id!),
          message: '正在删除预约...',
        );

        AppToastManager.showDelete(context, message: '预约已删除');

        _stateService!.loadAppointments();
      } catch (e) {
        AppToastManager.showError(context, message: '删除预约失败: $e');
      }
    }
  }

  Future<void> _changeAppointmentStatus(
      Appointment appointment, String status) async {
    if (!PermissionUtils.canEditDoctor(context, appointment.patient?.doctor)) {
      AppToastManager.showError(
        context,
        message: '您只能编辑自己医生患者的预约',
      );
      return;
    }

    final appointmentProvider =
        Provider.of<AppointmentProvider>(context, listen: false);

    try {
      final updatedAppointment = appointment.copyWith(
        status: status,
        updated_at: DateTime.now(),
      );
      await appointmentProvider.updateAppointment(updatedAppointment);
      _stateService?.replaceAppointment(updatedAppointment);
      if (!mounted) return;
      AppToastManager.showSuccess(context, message: '预约状态已更新');
    } catch (e) {
      if (!mounted) return;
      AppToastManager.showError(context, message: '更新预约状态失败: $e');
    }
  }

  // 在_AppointmentsScreenState类中添加方法，用于格式化显示治疗类型和牙位信息
  String _formatTreatmentTypeForDisplay(String? treatmentTypeStr) {
    if (treatmentTypeStr == null || treatmentTypeStr.isEmpty) {
      return '';
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

      return displayParts.join(' ');
    } catch (e) {
      // 如果不是JSON格式，直接返回原始字符串
      return treatmentTypeStr;
    }
  }

  // 紧凑型操作按钮
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
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
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
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '预约管理',
              style: TextStyle(
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
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () => _showAddEditAppointmentDialog(),
              tooltip: '添加预约',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
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
              onPressed: () async {
                await _stateService!.loadAppointments();
                if (!mounted) return;
                AppToastManager.showSuccess(context, message: '刷新数据成功');
              },
              tooltip: '刷新数据',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // MySQL连接状态检查
          const MySQLConnectionWarning(moduleName: '预约管理'),

          // 顶部筛选栏（已拆分为独立组件）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AnimatedBuilder(
              animation: _stateService!,
              builder: (context, _) {
                return AppointmentFilterBar(
                  searchController: _searchController,
                  selectedDate: _stateService!.selectedDate,
                  endDate: _stateService!.endDate,
                  isFiltering: _stateService!.isFiltering,
                  isDateRangeFiltering: _stateService!.isDateRangeFiltering,
                  searchQuery: _stateService!.searchQuery,
                  onSearchChanged: (v) {
                    _stateService!.setSearchQuery(v);
                  },
                  onSearchClear: () {
                    _stateService!.setSearchQuery('');
                  },
                  onSelectDateRange: () async {
                    final result = await ReusableDateRangePicker.show(
                      context,
                      start: _stateService!.selectedDate,
                      end: _stateService!.endDate ??
                          _stateService!.selectedDate
                              .add(const Duration(days: 7)),
                      title: '选择日期范围',
                    );
                    if (result != null) {
                      _stateService!.selectDateRange(result.start, result.end);
                    }
                  },
                  onToggleFiltering: () {
                    _stateService!.toggleFiltering();
                  },
                );
              },
            ),
          ),
          // 预约列表（已拆分为组件）
          Expanded(
            child: AnimatedBuilder(
              animation: _stateService!,
              builder: (context, _) {
                return AppointmentList(
                  appointments: _stateService!.filteredAppointments,
                  isLoading: _stateService!.isLoading,
                  onRefresh: () => _stateService!.loadAppointments(),
                  onView: (ap) {
                    if (ap.id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppointmentDetailsScreen(
                            appointmentId: ap.id!,
                          ),
                        ),
                      );
                    }
                  },
                  onEdit: (ap) {
                    if (PermissionUtils.canEditDoctor(
                        context, ap.patient?.doctor)) {
                      _showAddEditAppointmentDialog(ap);
                    } else {
                      AppToastManager.showError(context,
                          message: '您只能编辑自己医生患者的预约');
                    }
                  },
                  onDelete: (ap) {
                    if (PermissionUtils.canDeleteDoctor(
                        context, ap.patient?.doctor)) {
                      _confirmDeleteAppointment(ap);
                    } else {
                      AppToastManager.showError(context,
                          message: '您只能删除自己医生患者的预约');
                    }
                  },
                  onStatusChanged: _changeAppointmentStatus,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditAppointmentDialog(),
        tooltip: '添加预约',
        backgroundColor: DentalColors.primary,
        child: Icon(DentalIcons.calendarPlus, color: Colors.white),
      ),
    );
  }
}
