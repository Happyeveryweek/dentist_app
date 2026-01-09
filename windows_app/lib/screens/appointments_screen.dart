import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:convert';
import 'dart:collection';

import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

import '../providers/appointment_provider.dart';
import '../providers/user_provider.dart';
import '../providers/app_state.dart';
import './appointment_details_screen.dart';
import './appointment_form_dialog.dart';
import '../widgets/dental_icons.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../widgets/success_toast.dart';
import '../widgets/unified_search_field.dart';
import '../utils/permission_utils.dart';

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
  DateTime _selectedDate = DateTime.now();
  DateTime? _endDate;
  List<Appointment> _appointments = [];
  List<Appointment> _filteredAppointments = [];
  bool _isLoading = true;
  bool _showAllAppointments = true;
  bool _isFiltering = false;
  bool _isDateRangeFiltering = false;
  bool _patientDropdownOpen = false;
  final TextEditingController _patientSearchController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Patient> _filteredPatients = [];
  List<Patient> _patients = [];
  bool _isLoadingPatients = true;

  // 治疗类型选项
  List<String> _treatmentTypes = [];
  List<String> _selectedTreatments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    if (appointmentProvider.appointmentsNeedRefresh) {
      _loadAppointments();
      appointmentProvider.resetAppointmentsRefreshFlag();
    }
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);

    try {
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);

      // 获取当前用户信息
      final currentUser = await appointmentProvider.getCurrentUser();
      final isAdmin = currentUser?.role == 'admin';
      final doctorName = currentUser?.doctor;

      List<Appointment> appointments = [];

      // 根据用户角色过滤预约
      if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
        // 医生只能看到自己的预约
        appointments = await appointmentProvider.getAppointmentsByDoctor(doctorName);
      } else {
        // 管理员可以看到所有预约
        appointments = await appointmentProvider.getAllAppointments();
      }

      appointments.sort((a, b) {
        final now = DateTime.now();
        final diffA = a.appointment_date.difference(now).inMinutes.abs();
        final diffB = b.appointment_date.difference(now).inMinutes.abs();

        if (a.appointment_date.isAfter(now) &&
            b.appointment_date.isBefore(now)) {
          return -1;
        }
        if (a.appointment_date.isBefore(now) &&
            b.appointment_date.isAfter(now)) {
          return 1;
        }

        return diffA.compareTo(diffB);
      });

      setState(() {
        _appointments = appointments;
        _filterAppointmentsByDate();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '加载预约数据失败: $e',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade500,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
    }
  }

  void _filterAppointmentsByDate() {
    List<Appointment> base;
    if (!_isFiltering) {
      base = List.from(_appointments);
    } else if (_isDateRangeFiltering && _endDate != null) {
      base = _appointments.where((appointment) {
        final d = appointment.appointment_date;
        final startDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final endDateTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        return d.isAfter(startDateTime.subtract(const Duration(seconds: 1))) && d.isBefore(endDateTime.add(const Duration(seconds: 1)));
      }).toList();
    } else {
      base = _appointments.where((appointment) {
        final d = appointment.appointment_date;
        return d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
      }).toList();
    }

    // 叠加搜索过滤（患者姓名、备注等）
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base.where((a) {
        final name = (a.patient?.name ?? '').toLowerCase();
        final notes = (a.notes ?? '').toLowerCase();
        return name.contains(q) || notes.contains(q);
      }).toList();
    }

    setState(() {
      _filteredAppointments = base;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ModernDatePickerDialog(
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _endDate = null; // 清除结束日期
        _isFiltering = true;
        _isDateRangeFiltering = false; // 设置为单日筛选
        _filterAppointmentsByDate();
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final result = await ReusableDateRangePicker.show(
      context,
      start: _selectedDate,
      end: _endDate ?? _selectedDate.add(const Duration(days: 7)),
      title: '选择日期范围',
    );
    if (result != null) {
      setState(() {
        _selectedDate = result.start;
        _endDate = result.end;
        _isFiltering = true;
        _isDateRangeFiltering = true;
      });
      _filterAppointmentsByDate();
    }
  }

  // 紧凑日期范围选择（样式对齐财务管理）
  Future<void> _showCompactDateRangePicker() async {
    final picked = await ReusableDateRangePicker.show(
      context,
      start: _selectedDate,
      end: _endDate ?? _selectedDate,
      title: '选择日期范围',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.start;
        _endDate = picked.end;
        _isFiltering = true;
        _isDateRangeFiltering = true;
      });
      _filterAppointmentsByDate();
    }
  }

  void _toggleFiltering() {
    setState(() {
      _isFiltering = !_isFiltering;
      if (!_isFiltering) {
        _isDateRangeFiltering = false;
        _endDate = null;
      } else {
        // 切换到筛选状态时，自动打开日期范围选择器
        _selectDateRange(context);
      }
      _filterAppointmentsByDate();
    });
  }

  String _formatAppointmentTime(DateTime dateTime) {
    return DateFormat.Hm().format(dateTime);
  }

  String _formatAppointmentDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  Future<void> _showAddEditAppointmentDialog([Appointment? appointment]) async {
    final bool isEditing = appointment != null;
    
    // 检查权限
    if (isEditing && !PermissionUtils.canEditDoctor(context, appointment?.patient?.doctor)) {
      SuccessToastManager.showError(
        context,
        message: '您只能编辑自己医生患者的预约',
      );
      return;
    }
    
    // 所有登录用户都可以添加预约，编辑时检查医生权限

    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        initialDate: _selectedDate,
        appointment: appointment,
      ),
    );

    if (result != null) {
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);

      try {
        if (isEditing) {
          // 添加防重复提交保护
          await appState.showLoading(
            appointmentProvider.updateAppointment(result),
            message: '正在更新预约...',
          );

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
          // 添加防重复提交保护
          await appState.showLoading(
            appointmentProvider.addAppointment(result),
            message: '正在添加预约...',
          );

          // 使用公用成功提示组件
          SuccessToastManager.show(context, message: '预约已添加');
        }

        _loadAppointments();
      } catch (e) {
        // 显示错误提示
        SuccessToastManager.showError(context, message: '${isEditing ? "更新" : "添加"}预约失败: $e');
      }
    }
  }

  Future<void> _confirmDeleteAppointment(Appointment appointment) async {
    // 检查删除权限
    if (!PermissionUtils.canDeleteDoctor(context, appointment.patient?.doctor)) {
      SuccessToastManager.showError(
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
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);

      try {
        // 添加防重复提交保护
        await appState.showLoading(
          appointmentProvider.deleteAppointment(appointment.id!),
          message: '正在删除预约...',
        );

        DeleteSuccessToastManager.show(context, message: '预约已删除');

        _loadAppointments();
      } catch (e) {
        SuccessToastManager.showError(context, message: '删除预约失败: $e');
      }
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

  // 构建今日预约以及预约列表的显示格式 - 紧凑版
  Widget _buildAppointmentCard(Appointment appointment) {
    // 获取状态颜色
    Color statusColor = Color(
      int.parse(appointment.statusColor.replaceAll('#', '0xff')),
    );

    // 根据性别决定头像背景颜色
    final gender = appointment.patient?.gender ?? '';

    // 获取日期和时间
    String appointmentDate =
        _formatAppointmentDate(appointment.appointment_date);
    String appointmentTime =
        _formatAppointmentTime(appointment.appointment_date);

    // 处理治疗项目显示
    String treatmentDisplay = '常规复诊';
    if (appointment.treatment_type != null &&
        appointment.treatment_type!.isNotEmpty) {
      try {
        // 尝试解析JSON格式的treatment_type
        treatmentDisplay =
            _formatTreatmentTypeForDisplay(appointment.treatment_type);
      } catch (e) {
        // 如果解析失败，使用原始字符串
        treatmentDisplay = appointment.treatment_type!;

        // 如果治疗类型包含多个项目（用顿号分隔），保持原样
        if (!treatmentDisplay.contains('{')) {
          treatmentDisplay = treatmentDisplay;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: DentalCard(
        color: Colors.white,
        child: InkWell(
          onTap: () {
            if (appointment.id != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppointmentDetailsScreen(
                    appointmentId: appointment.id!,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 左侧：头像
                DentalAvatar(
                  gender: gender,
                  name: appointment.patient?.name ?? "未知",
                  size: 36,
                ),
                
                const SizedBox(width: 12),
                
                // 中间：患者信息和治疗项目
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 第一行：患者姓名 + 状态标签
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
                      
                      // 第二行：时间 + 治疗项目
                      Row(
                        children: [
                          // 时间标签
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
                                  '$appointmentDate $appointmentTime',
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
                          
                          // 治疗项目
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
                          
                          // 费用标签（如果有）
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
                
                // 右侧：操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 查看按钮
                    _buildCompactActionButton(
                      icon: Icons.visibility_rounded,
                      color: DentalColors.info,
                      tooltip: '查看',
                      onPressed: () {
                        if (appointment.id != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AppointmentDetailsScreen(
                                appointmentId: appointment.id!,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    
                    const SizedBox(width: 6),
                    
                    // 编辑按钮
                    PermissionUtils.canEditDoctor(context, appointment.patient?.doctor)
                      ? _buildCompactActionButton(
                          icon: Icons.edit_rounded,
                          color: DentalColors.warning,
                          tooltip: '编辑',
                          onPressed: () => _showAddEditAppointmentDialog(appointment),
                        )
                      : _buildCompactActionButton(
                          icon: Icons.lock,
                          color: Colors.grey,
                          tooltip: '权限不足',
                          onPressed: () => SuccessToastManager.showError(
                            context,
                            message: '您只能编辑自己医生患者的预约',
                          ),
                        ),
                    
                    const SizedBox(width: 6),
                    
                    // 删除按钮
                    PermissionUtils.canDeleteDoctor(context, appointment.patient?.doctor)
                      ? _buildCompactActionButton(
                          icon: Icons.delete_rounded,
                          color: DentalColors.error,
                          tooltip: '删除',
                          onPressed: () => _confirmDeleteAppointment(appointment),
                        )
                      : _buildCompactActionButton(
                          icon: Icons.lock,
                          color: Colors.grey,
                          tooltip: '权限不足',
                          onPressed: () => SuccessToastManager.showError(
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
    // 计算筛选文本
    String filterText = '';
    if (_isFiltering && _endDate != null) {
      filterText =
          '显示 ${DateFormat('yyyy年MM月dd日').format(_selectedDate)} 至 ${DateFormat('yyyy年MM月dd日').format(_endDate!)} 的预约';
    } else {
      filterText = '显示所有预约，按与当前时间接近程度排序';
    }

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
                await _loadAppointments();
                if (!mounted) return;
                SuccessToastManager.show(context, message: '刷新数据成功');
              },
              tooltip: '刷新数据',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部工具条：搜索 + 日期（紧凑白底）
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: UnifiedSearchField(
                      controller: _searchController,
                      hintText: '搜索预约记录',
                      prefixIcon: Icons.search_rounded,
                      searchQuery: _searchQuery,
                      onChanged: (v) { setState(() { _searchQuery = v; }); _filterAppointmentsByDate(); },
                      onClear: () { setState(() { _searchQuery = ''; _searchController.clear(); }); _filterAppointmentsByDate(); },
                    ),
                  ),
                  const SizedBox(width: 12),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      height: 44,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _showCompactDateRangePicker,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 20, color: DentalColors.info),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                                  child: Text(
                                    _endDate == null
                                        ? '全部时间'
                                        : '${DateFormat('yyyy-MM-dd').format(_selectedDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                                    style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_endDate != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.clear, size: 20, color: Colors.grey[600]),
                                    onPressed: () { setState(() { _isFiltering = false; _isDateRangeFiltering = false; _endDate = null; }); _filterAppointmentsByDate(); },
                                    tooltip: '清空日期筛选',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
                // 预约列表
                Expanded(
                  child: _filteredAppointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                DentalIcons.calendarCheck,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _isFiltering && _endDate != null
                                    ? '${DateFormat('MM月dd日').format(_selectedDate)} 至 ${DateFormat('MM月dd日').format(_endDate!)} 没有预约'
                                    : '暂无预约记录',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showAddEditAppointmentDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('添加预约'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredAppointments.length,
                          itemBuilder: (context, index) {
                            return _buildAppointmentCard(
                                _filteredAppointments[index]);
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
