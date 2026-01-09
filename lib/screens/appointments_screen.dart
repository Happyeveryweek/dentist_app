import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/widgets/appointment_form_sheet.dart';
import 'package:dentist_app/screens/appointment_detail_screen.dart';
import 'dart:convert';
import 'package:dentist_app/utils/toast_util.dart';
import 'package:dentist_app/widgets/success_toast.dart'; // 添加新的公共组件导入
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

  Widget _buildAppointmentsHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '预约管理',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: AppTheme.primaryColor.withOpacity(0.1),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.secondaryText,
            tabs: const [Tab(text: '全部预约'), Tab(text: '今日预约')],
          ),
        ],
      ),
    );
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
      body: Column(
        children: [
          _buildAppointmentsHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '加载预约数据中...',
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    _buildSearchAndFilterBar(),
                    Expanded(
                      child: _showCalendar
                          ? _buildCalendarView()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                RefreshIndicator(
                                  onRefresh: () => _loadAppointments(isRefresh: true),
                                  child: _buildAllAppointmentsView(),
                                ),
                                RefreshIndicator(
                                  onRefresh: () => _loadAppointments(isRefresh: true),
                                  child: _buildTodayAppointmentsView(),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
          ),
        ],
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

  Widget _buildCalendarView() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppTheme.primaryColor,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppTheme.primaryColor,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markersAlignment: Alignment.bottomCenter,
                markerDecoration: const BoxDecoration(
                  color: AppTheme.secondaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) {
                final dateOnly = DateTime(day.year, day.month, day.day);
                return _appointmentsByDay[dateOnly] ?? [];
              },
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${DateFormat('MM月dd日').format(_selectedDay)} 预约',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              Text(
                '共 ${_selectedDayAppointments.length} 个预约',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child:
              _selectedDayAppointments.isEmpty
                  ? SingleChildScrollView(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 48,
                              color: AppTheme.lightText.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '当天无预约',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            PermissionWrapper(
                              module: 'appointments',
                              action: 'create',
                              hideWhenDenied: true,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _showAppointmentDialog(context, initialDate: _selectedDay);
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('添加预约'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.borderRadius,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _selectedDayAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = _selectedDayAppointments[index];
                        return _buildAppointmentCard(appointment);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: '搜索患者姓名或治疗项目',
              style: const TextStyle(color: AppTheme.primaryText, fontSize: 14),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_alt,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '筛选',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 14),
                ),
              ],
            ),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAllAppointmentsView() {
    final appointments = _filteredAppointments;

    if (appointments.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppTheme.lightText.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  '没有找到符合条件的预约',
                  style: TextStyle(fontSize: 16, color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildTodayAppointmentsView() {
    final appointments = _todayAppointments;

    if (appointments.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.today,
                  size: 64,
                  color: AppTheme.lightText.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  '今日无预约',
                  style: TextStyle(fontSize: 16, color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final statusInfo = _getStatusInfo(appointment.status);
    final patientName = appointment.patientName ?? '未知患者';
    final avatarColor = _getPatientAvatarColor(patientName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shadowColor: AppTheme.lightText.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => AppointmentDetailScreen(appointment: appointment),
            ),
          );
          
          print('预约详情返回值: $result'); // 调试输出
          
          // 只有在数据更新时才刷新（静默刷新，不显示提示）
          if (result == true && mounted) {
            print('触发刷新'); // 调试输出
            _loadAppointments(isRefresh: false);
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: avatarColor.withOpacity(0.2),
                    child: Text(
                      patientName.isNotEmpty ? patientName.substring(0, 1) : '?',
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('yyyy-MM-dd').format(appointment.appointmentDate)} ${DateFormat.Hm().format(appointment.appointmentDate)}',
                          style: const TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(statusInfo.icon, color: statusInfo.color, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusInfo.text,
                          style: TextStyle(
                            color: statusInfo.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.dividerColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    color: AppTheme.secondaryText,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatTreatmentType(appointment.treatmentType),
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.notes_outlined,
                      color: AppTheme.secondaryText,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.notes!,
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FutureBuilder<String?>(
                    future: _getAppointmentPatientDoctor(appointment),
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
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAppointmentDialog(context, appointment: appointment),
                        ),
                      );
                    },
                  ),
                  FutureBuilder<String?>(
                    future: _getAppointmentPatientDoctor(appointment),
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
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(appointment),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return _StatusInfo(
          text: '已预约',
          color: AppTheme.infoColor,
          icon: Icons.event_available,
        );
      case 'completed':
      case '已完成':
        return _StatusInfo(
          text: '已完成',
          color: AppTheme.successColor,
          icon: Icons.check_circle_outline,
        );
      case 'cancelled':
      case '已取消':
        return _StatusInfo(
          text: '已取消',
          color: AppTheme.errorColor,
          icon: Icons.cancel_outlined,
        );
      case 'missed':
      case 'no_show':
      case '未到诊':
        return _StatusInfo(
          text: '未到诊',
          color: AppTheme.warningColor,
          icon: Icons.hourglass_empty,
        );
      default:
        return _StatusInfo(
          text: '未知',
          color: AppTheme.secondaryText,
          icon: Icons.help_outline,
        );
    }
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

class _StatusInfo {
  final String text;
  final Color color;
  final IconData icon;

  _StatusInfo({required this.text, required this.color, required this.icon});
}