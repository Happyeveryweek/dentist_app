import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/features/appointments/widgets/appointment_form_sheet.dart';
import 'package:dentist_app/features/appointments/widgets/appointments_screen_body.dart';
import 'dart:convert';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart'; // 添加新的公共日期时间选择器
import 'package:dentist_app/utils/pinyin_util.dart'; // 添加拼音工具类
import 'package:dentist_app/utils/permission_utils.dart'; // 添加权限工具类导入

class AppointmentsScreen extends StatefulWidget {
  final String? initialFilterStatus;

  const AppointmentsScreen({super.key, this.initialFilterStatus});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late String _filterStatus;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _showCalendar = false;
  bool _isInitialLoad = true;

  // 新增：用于日期范围筛选
  DateTime? _startDate;
  DateTime? _endDate;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  Map<DateTime, List<Appointment>> _appointmentsByDay = {};

  final CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilterStatus ?? '全部';
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 逻辑简化，避免循环加载
    if (_isInitialLoad) {
      _isInitialLoad = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments({bool isRefresh = false}) async {
    print('_loadAppointments 被调用，isRefresh: $isRefresh'); // 调试输出
    
    // 只有在手动刷新时才显示提示并重置筛选
    if (isRefresh) {
      if (!mounted) return;
      setState(() {
        _searchQuery = '';
        _filterStatus = '全部';
        _startDate = null;
        _endDate = null;
        _searchController.clear();
      });
    }

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      if (!appointmentsProvider.initialized) {
        // 只有在初始化时才显示加载动画
        setState(() {
          _isLoading = true;
        });
        await appointmentsProvider.initializeFromDatabase(dbProvider, userProvider: userProvider);
      }
      
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      if (!patientProvider.initialized) {
        // 只有在初始化时才显示加载动画
        setState(() {
          _isLoading = true;
        });
        await patientProvider.initializeFromDatabase(dbProvider, userProvider: userProvider);
      }
      
      // 如果是刷新操作，强制清除缓存并显示加载动画
      if (isRefresh) {
        setState(() {
          _isLoading = true;
        });
        appointmentsProvider.forceRefreshAppointments();
        patientProvider.forceRefreshPatients();
      }
      
      final appointments = await appointmentsProvider.getAllAppointments();
      
      // 批量获取所有患者信息（使用缓存）
      final allPatients = await patientProvider.getAllPatients();
      final patientMap = {for (var p in allPatients) p.id: p};
      
      // 快速关联患者信息
      final List<Appointment> appointmentsWithPatients = appointments.map((appointment) {
        if (appointment.patientId != null) {
          final patient = patientMap[appointment.patientId];
          if (patient != null) {
            return appointment.copyWith(patientName: patient.name);
          }
        }
        return appointment;
      }).toList();

      Map<DateTime, List<Appointment>> appointmentMap = {};
      for (var appointment in appointmentsWithPatients) {
        final dateOnly = DateTime(
          appointment.appointmentDate.year,
          appointment.appointmentDate.month,
          appointment.appointmentDate.day,
        );

        if (!appointmentMap.containsKey(dateOnly)) {
          appointmentMap[dateOnly] = [];
        }
        appointmentMap[dateOnly]!.add(appointment);
      }

      if (mounted) {
        setState(() {
          _appointments = appointmentsWithPatients;
          _appointmentsByDay = appointmentMap;
          _isLoading = false;
        });
        if (isRefresh && mounted) {
          print('显示刷新成功提示'); // 调试输出
          SuccessToastManager.show(
            context,
            message: '刷新成功',
          );
        }
      }
    } catch (e) {
      print('加载预约数据错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (isRefresh && mounted) {
          SuccessToastManager.showError(context, message: '刷新失败: $e');
        }
      }
    }
  }

  List<Appointment> get _filteredAppointments {
    List<Appointment> filtered = _appointments;

    if (_filterStatus != '全部') {
      String status;
      switch (_filterStatus) {
        case '已预约':
          status = 'scheduled';
          break;
        case '已完成':
          status = 'completed';
          break;
        case '已取消':
          status = 'cancelled';
          break;
        case '未到诊':
          status = 'no_show';
          break;
        default:
          status = '';
      }

      if (status.isNotEmpty) {
        filtered = filtered.where((appointment) =>
              appointment.status == status ||
              (status == 'no_show' && (appointment.status == 'missed' || appointment.status == '未到诊'))
        ).toList();
      }
    }

    if (_startDate != null && _endDate != null) {
      final endDateEndOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((appointment) {
        return !appointment.appointmentDate.isBefore(_startDate!) && !appointment.appointmentDate.isAfter(endDateEndOfDay);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((appointment) {
        final patientName = appointment.patientName ?? '';
        final treatmentType = appointment.treatmentType ?? '';
        final query = _searchQuery.toLowerCase();
        
        // 支持多种搜索方式
        bool nameMatch = patientName.toLowerCase().contains(query);
        bool treatmentMatch = treatmentType.toLowerCase().contains(query);
        
        // 拼音搜索支持
        bool pinyinMatch = false;
        bool initialsMatch = false;
        
        if (patientName.isNotEmpty) {
          try {
            // 获取完整拼音（无空格）
            final pinyin = PinyinUtil.toPinyin(patientName, separator: '').toLowerCase();
            // 获取拼音首字母
            final initials = PinyinUtil.getInitials(patientName).toLowerCase();
            
            pinyinMatch = pinyin.contains(query);
            initialsMatch = initials.contains(query);
          } catch (e) {
            print('拼音搜索错误: $e');
          }
        }
        
        return nameMatch || treatmentMatch || pinyinMatch || initialsMatch;
      }).toList();
    }

    filtered.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    return filtered;
  }

  List<Appointment> get _selectedDayAppointments {
    final dateOnly = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    return _appointmentsByDay[dateOnly] ?? [];
  }

  List<Appointment> get _todayAppointments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final appointments = _appointmentsByDay[today] ?? [];

    appointments.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

    return appointments;
  }

  String _formatTreatmentType(dynamic treatmentType) {
    if (treatmentType == null) {
      return '常规复诊';
    }

    if (treatmentType is int) {
      return '治疗项目 $treatmentType';
    }

    if (treatmentType is String) {
      if (treatmentType.isEmpty) {
        return '常规复诊';
      }

      try {
        final data = json.decode(treatmentType);
        
        if (data is Map && data.containsKey('treatments') &&
            data['treatments'] is List &&
            (data['treatments'] as List).isNotEmpty) {
          final treatments = (data['treatments'] as List);
          return treatments.join('、');
        }
        
        return '常规复诊';
      } catch (e) {
        print('解析治疗类型JSON失败: $e');
        return treatmentType;
      }
    }

    return treatmentType.toString();
  }

  Color _getPatientAvatarColor(String patientName) {
    if (patientName.isEmpty) {
      return AppTheme.primaryColor;
    }
    
    final int colorSeed = patientName.hashCode;
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      AppTheme.infoColor,
      AppTheme.successColor,
      AppTheme.warningColor,
    ];
    return colors[colorSeed % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: AppointmentsScreenBody(
        isLoading: _isLoading,
        tabController: _tabController,
        showCalendar: _showCalendar,
        calendarFormat: _calendarFormat,
        selectedDay: _selectedDay,
        focusedDay: _focusedDay,
        appointmentsByDay: _appointmentsByDay,
        selectedDayAppointments: _selectedDayAppointments,
        filteredAppointments: _filteredAppointments,
        todayAppointments: _todayAppointments,
        searchController: _searchController,
        onSearchChanged: (value) {
          setState(() {});
        },
        onSearchSubmitted: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
        },
        onClearSearch: () {
          setState(() {
            _searchQuery = '';
            _searchController.clear();
          });
        },
        onFilterPressed: _showFilterDialog,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onAddAppointment: (date) {
          _showAppointmentDialog(context, initialDate: date);
        },
        onRefreshAll: () => _loadAppointments(isRefresh: true),
        formatTreatmentType: _formatTreatmentType,
        getPatientAvatarColor: _getPatientAvatarColor,
        getAppointmentPatientDoctor: _getAppointmentPatientDoctor,
        onEditAppointment: (appointment) {
          _showAppointmentDialog(context, appointment: appointment);
        },
        onDeleteAppointment: (appointment) {
          _showDeleteConfirmation(appointment);
        },
      ),
      floatingActionButton: PermissionWrapper(
        module: 'appointments',
        action: 'create',
        hideWhenDenied: true,
        child: FloatingActionButton(
          onPressed: () {
            _showAppointmentDialog(context);
          },
          backgroundColor: AppTheme.secondaryColor,
          tooltip: '添加预约',
          heroTag: 'appointment_add_button',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAppointmentDialog(BuildContext context, {DateTime? initialDate, Appointment? appointment}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: AppointmentFormSheet(
              onSaved: (isSuccess, message) {
                if (isSuccess) {
                  _loadAppointments(isRefresh: true);
                  SuccessToastManager.show(context, message: message);
                } else {
                  SuccessToastManager.showError(context, message: message);
                }
              },
              initialDate: initialDate ?? appointment?.appointmentDate,
              appointment: appointment,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Appointment appointment) async {
    final patientName = appointment.patientName ?? '未知患者';
    final appointmentInfo =
        '患者: $patientName\n日期: ${DateFormat('yyyy-MM-dd HH:mm').format(appointment.appointmentDate)}';

    final confirmed = await ModernDeleteDialogManager.showAppointmentDelete(
      context,
      appointmentInfo: appointmentInfo,
    );
    
    if (confirmed == true) {
      _deleteAppointment(appointment);
    }
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    if (appointment.id == null) {
      if (!mounted) return;
      SuccessToastManager.showError(context, message: '无法删除：预约ID无效');
      return;
    }

    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
      await appointmentsProvider.deleteAppointment(appointment.id!);

      _loadAppointments(isRefresh: true);

      if (!mounted) return;
      SuccessToastManager.show(context, message: '预约已删除');
    } catch (e) {
      print('删除预约错误: $e');

      if (!mounted) return;
      SuccessToastManager.showError(context, message: '删除预约失败: $e');
    }
  }

  void _showFilterDialog() {
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    String tempFilterStatus = _filterStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '筛选预约',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.secondaryText),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('日期范围', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDialog<DateTime>(
                              context: context,
                              builder: (BuildContext context) {
                                return ModernDatePickerDialog(
                                  initialDate: tempStartDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                  title: '选择开始日期',
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempStartDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.dividerColor),
                              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                            ),
                            child: Text(
                              tempStartDate != null
                                  ? DateFormat('yyyy-MM-dd').format(tempStartDate!)
                                  : '开始日期',
                              style: const TextStyle(color: AppTheme.primaryText),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('至'),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDialog<DateTime>(
                              context: context,
                              builder: (BuildContext context) {
                                return ModernDatePickerDialog(
                                  initialDate: tempEndDate ?? DateTime.now(),
                                  firstDate: tempStartDate ?? DateTime(2020),
                                  lastDate: DateTime(2030),
                                  title: '选择结束日期',
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempEndDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.dividerColor),
                              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                            ),
                            child: Text(
                              tempEndDate != null
                                  ? DateFormat('yyyy-MM-dd').format(tempEndDate!)
                                  : '结束日期',
                              style: const TextStyle(color: AppTheme.primaryText),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('预约状态', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: ['全部', '已预约', '已完成', '已取消', '未到诊'].map((status) {
                      return ChoiceChip(
                        label: Text(status),
                        selected: tempFilterStatus == status,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              tempFilterStatus = status;
                            });
                          }
                        },
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: tempFilterStatus == status ? Colors.white : AppTheme.primaryText,
                        ),
                        backgroundColor: AppTheme.cardBackground,
                      );
                    }).toList(),
                  ),
                  const Spacer(),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempStartDate = null;
                              tempEndDate = null;
                              tempFilterStatus = '全部';
                            });
                          },
                          child: const Text('重置'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryText,
                            side: const BorderSide(color: AppTheme.dividerColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _startDate = tempStartDate;
                              _endDate = tempEndDate;
                              _filterStatus = tempFilterStatus;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('应用筛选'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 获取预约关联患者的医生字段，用于权限检查
  Future<String?> _getAppointmentPatientDoctor(Appointment appointment) async {
    try {
      if (appointment.patientId == null) return null;
      
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final patient = await patientProvider.getPatientById(appointment.patientId);
      
      return patient?.doctor;
    } catch (e) {
      print('获取预约患者医生信息失败: $e');
      return null;
    }
  }
}
