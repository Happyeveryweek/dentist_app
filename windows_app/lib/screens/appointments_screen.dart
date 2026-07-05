import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../models/appointment.dart';

import '../providers/appointment_provider.dart';
import '../providers/app_state.dart';
import './appointment_details_screen.dart';
import '../features/appointments/widgets/appointment_form_dialog.dart';
import '../widgets/dental_icons.dart';
import '../widgets/mysql_connection_warning.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../widgets/success_toast.dart';
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
  AppointmentStateService get _requireStateService {
    final service = _stateService;
    if (service == null) {
      throw Exception('AppointmentStateService 未初始化');
    }
    return service;
  }
  AppointmentProvider? _appointmentProvider;
  AppointmentProvider get _requireAppointmentProvider {
    final provider = _appointmentProvider;
    if (provider == null) {
      throw Exception('AppointmentProvider 未初始化');
    }
    return provider;
  }
  bool _appointmentProviderListenerAttached = false;
  final TextEditingController _patientSearchController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 移动加载到 state service 初始化后
  }

  @override
  void dispose() {
    final appointmentProvider = _appointmentProvider;
    if (appointmentProvider != null && _appointmentProviderListenerAttached) {
      appointmentProvider.removeListener(_handleAppointmentProviderChanged);
    }
    _patientSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleAppointmentProviderChanged() {
    if (!mounted || _stateService == null || _appointmentProvider == null) {
      return;
    }

    if (!_requireAppointmentProvider.hasValidCache) {
      return;
    }

    _requireStateService.setAppointments(_requireAppointmentProvider.cachedAppointments);
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

  Future<void> _showAddEditAppointmentDialog([Appointment? appointment]) async {
    final bool isEditing = appointment != null;

    // 检查权限
    if (isEditing &&
        !PermissionUtils.canEditDoctor(context, appointment.patient?.doctor)) {
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
        initialDate: _requireStateService.selectedDate,
        appointment: appointment,
      ),
    );

    if (result != null) {
      if (!mounted) return;
      final appointmentProvider =
          Provider.of<AppointmentProvider>(context, listen: false);

      try {
        if (isEditing) {
          await appointmentProvider.updateAppointment(result);
          _stateService?.replaceAppointment(result);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: context.tokens.cardBackground,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '预约已更新',
                      style: TextStyle(
                        color: context.tokens.cardBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: context.tokens.success,
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

          if (!mounted) return;
          // 使用公用成功提示组件
          AppToastManager.showSuccess(context, message: '预约已添加');
        }
      } catch (e) {
        if (!mounted) return;
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
      if (!mounted) return;
      final appointmentProvider =
          Provider.of<AppointmentProvider>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);

      try {
        final appointmentId = appointment.id;
        if (appointmentId == null) {
          AppToastManager.showError(context, message: '无法删除无 ID 的预约');
          return;
        }
        // 添加防重复提交保护
        await appState.showLoading(
          appointmentProvider.deleteAppointment(appointmentId),
          message: '正在删除预约...',
        );

        if (!mounted) return;
        AppToastManager.showDelete(context, message: '预约已删除');

        _requireStateService.loadAppointments();
      } catch (e) {
        if (!mounted) return;
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
        updatedAt: DateTime.now(),
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
              child: Icon(
                Icons.calendar_month_rounded,
                color: context.tokens.cardBackground,
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
        backgroundColor: context.tokens.cardBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: context.tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: context.tokens.cardBackground),
              onPressed: () => _showAddEditAppointmentDialog(),
              tooltip: '添加预约',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
                color: context.tokens.infoContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.tokens.info.withValues(alpha: 0.3),
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: context.tokens.info,
                ),
                onPressed: () async {
                await _requireStateService.loadAppointments(forceRefresh: true);
                if (!context.mounted) return;
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
              animation: _requireStateService,
              builder: (context, _) {
                return AppointmentFilterBar(
                  searchController: _searchController,
                  selectedDate: _requireStateService.selectedDate,
                  endDate: _requireStateService.endDate,
                  isFiltering: _requireStateService.isFiltering,
                  isDateRangeFiltering: _requireStateService.isDateRangeFiltering,
                  searchQuery: _requireStateService.searchQuery,
                  onSearchChanged: (v) {
                    _requireStateService.setSearchQuery(v);
                  },
                  onSearchClear: () {
                    _requireStateService.setSearchQuery('');
                  },
                  onSelectDateRange: () async {
                    final result = await ReusableDateRangePicker.show(
                      context,
                      start: _requireStateService.selectedDate,
                      end: _requireStateService.endDate ??
                          _requireStateService.selectedDate
                              .add(const Duration(days: 7)),
                      title: '选择日期范围',
                    );
                    if (result != null) {
                      _requireStateService.selectDateRange(result.start, result.end);
                    }
                  },
                  onToggleFiltering: () {
                    _requireStateService.toggleFiltering();
                  },
                );
              },
            ),
          ),
          // 预约列表（已拆分为组件）
          Expanded(
            child: AnimatedBuilder(
              animation: _requireStateService,
              builder: (context, _) {
                return AppointmentList(
                  appointments: _requireStateService.filteredAppointments,
                  isLoading: _requireStateService.isLoading,
                  onRefresh: () =>
                      _requireStateService.loadAppointments(forceRefresh: true),
                  onView: (ap) {
                    final appointmentId = ap.id;
                    if (appointmentId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppointmentDetailsScreen(
                            appointmentId: appointmentId,
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
        backgroundColor: context.tokens.primaryAccent,
        child: Icon(DentalIcons.calendarPlus, color: context.tokens.cardBackground),
      ),
    );
  }
}
