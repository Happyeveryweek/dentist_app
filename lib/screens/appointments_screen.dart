import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/widgets/appointment_form_sheet.dart';
import 'package:dentist_app/screens/appointment_detail_screen.dart';
import 'dart:convert';
import 'package:dentist_app/utils/toast_util.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
};

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

    // 检查Provider是否有变更
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // 如果是初始化后的依赖变更，考虑重新加载数据
    if (!_isLoading && dbProvider.isInitialized) {
      print('AppointmentsScreen 依赖已变更，检查是否需要重新加载数据');
      _loadAppointments();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final appointments = await dbProvider.getAllAppointments();

      // 创建以日期为键的映射
      Map<DateTime, List<Appointment>> appointmentMap = {};
      for (var appointment in appointments) {
        // 获取日期部分（不含时间）
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

      setState(() {
        _appointments = appointments;
        _appointmentsByDay = appointmentMap;
        _isLoading = false;
      });
    } catch (e) {
      print('加载预约数据错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Appointment> get _filteredAppointments {
    List<Appointment> filtered = _appointments;

    // 按状态筛选
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
        filtered =
            filtered
                .where(
                  (appointment) =>
                      appointment.status == status ||
                      // 特殊处理未到诊，可能是missed或no_show
                      (status == 'no_show' &&
                          (appointment.status == 'missed' ||
                              appointment.status == '未到诊')),
                )
                .toList();
      }
    }

    // 按搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((appointment) {
            // 这里需要获取患者信息进行搜索，但为了简化，我们只搜索预约ID和日期
            return appointment.id.toString().contains(_searchQuery) ||
                DateFormat(
                  'yyyy-MM-dd',
                ).format(appointment.appointmentDate).contains(_searchQuery) ||
                (appointment.treatmentType ?? '').toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
    }

    // 按日期排序（最近的在前）
    filtered.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    return filtered;
  }

  // 获取选中日期的预约
  List<Appointment> get _selectedDayAppointments {
    final dateOnly = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    return _appointmentsByDay[dateOnly] ?? [];
  }

  // 按照时间排序获取今天的预约
  List<Appointment> get _todayAppointments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final appointments = _appointmentsByDay[today] ?? [];

    // 按时间排序
    appointments.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));

    return appointments;
  }

  // 格式化治疗类型显示
  String _formatTreatmentType(String? treatmentType) {
    if (treatmentType == null || treatmentType.isEmpty) {
      return '常规复诊';
    }

    try {
      // 尝试解析JSON
      final data = json.decode(treatmentType);
      final List<String> displayParts = [];

      // 处理牙位信息
      if (data.containsKey('teethData') &&
          data['teethData'] is List &&
          (data['teethData'] as List).isNotEmpty) {
        for (var i = 0; i < (data['teethData'] as List).length; i++) {
          final teethData = data['teethData'][i];
          final List<String> positions = [];

          // 获取各个牙位的值
          teethData.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              // 使用牙位映射表转换位置名称
              if (positionMap.containsKey(key)) {
                positions.add('${positionMap[key]} $value');
              }
            }
          });

          if (positions.isNotEmpty) {
            displayParts.add('牙位${i + 1}: ${positions.join('，')}');
          }
        }
      }

      // 处理治疗项目
      if (data.containsKey('treatments') &&
          data['treatments'] is List &&
          (data['treatments'] as List).isNotEmpty) {
        final treatments = (data['treatments'] as List).join('、');
        if (displayParts.isNotEmpty) {
          displayParts.add('- $treatments');
        } else {
          displayParts.add(treatments);
        }
      }

      // 返回格式化后的显示文本
      return displayParts.isEmpty ? '常规复诊' : displayParts.join(' ');
    } catch (e) {
      print('解析治疗类型JSON失败: $e');
      return treatmentType; // 如果解析失败，直接返回原始字符串
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('预约管理'),
        centerTitle: true,
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.list : Icons.calendar_month,
              color: AppTheme.primaryColor,
            ),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
            tooltip: _showCalendar ? '列表视图' : '日历视图',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
            tooltip: '刷新预约',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryText,
          tabs: const [Tab(text: '全部预约'), Tab(text: '今日预约')],
        ),
      ),
      body:
          _isLoading
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
                    child:
                        _showCalendar
                            ? _buildCalendarView()
                            : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildAllAppointmentsView(),
                                _buildTodayAppointmentsView(),
                              ],
                            ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAppointmentDialog(context);
        },
        backgroundColor: AppTheme.secondaryColor,
        tooltip: '添加预约',
        heroTag: 'appointment_add_button',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        // 日历视图
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

        // 预约列表标题
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

        // 预约列表
        Expanded(
          child:
              _selectedDayAppointments.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: AppTheme.lightText.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '当天无预约',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed:
                              () => _showAppointmentDialog(
                                context,
                                initialDate: _selectedDay,
                              ),
                          icon: const Icon(Icons.add),
                          label: const Text('添加预约'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.smallBorderRadius,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _selectedDayAppointments.length,
                    itemBuilder: (context, index) {
                      return _buildAppointmentCard(
                        _selectedDayAppointments[index],
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildAllAppointmentsView() {
    return _filteredAppointments.isEmpty
        ? _buildEmptyState()
        : RefreshIndicator(
          onRefresh: _loadAppointments,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppTheme.padding),
            itemCount: _filteredAppointments.length,
            itemBuilder: (context, index) {
              final appointment = _filteredAppointments[index];
              return _buildAppointmentCard(appointment);
            },
          ),
        );
  }

  Widget _buildTodayAppointmentsView() {
    return _todayAppointments.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_available,
                size: 64,
                color: AppTheme.lightText.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '今日无预约',
                style: TextStyle(fontSize: 16, color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showAppointmentDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('添加今日预约'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.smallBorderRadius,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.all(AppTheme.padding),
          itemCount: _todayAppointments.length,
          itemBuilder: (context, index) {
            final appointment = _todayAppointments[index];
            return _buildAppointmentCard(appointment);
          },
        );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: AppTheme.lightText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '暂无预约数据' : '未找到符合"$_searchQuery"的预约',
            style: const TextStyle(fontSize: 16, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('清除搜索'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _showAppointmentDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('添加首个预约'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallBorderRadius,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索预约ID、日期或治疗类型',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.secondaryText,
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppTheme.secondaryText,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                      : null,
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              hintStyle: const TextStyle(
                color: AppTheme.lightText,
                fontSize: 14,
              ),
            ),
            style: const TextStyle(color: AppTheme.primaryText, fontSize: 14),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildHorizontalFilterChips(),
        ],
      ),
    );
  }

  Widget _buildHorizontalFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('全部'),
            selected: _filterStatus == '全部',
            onSelected: (_) => _onStatusFilterSelected('全部'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('已预约'),
            selected: _filterStatus == '已预约',
            onSelected: (_) => _onStatusFilterSelected('已预约'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('已完成'),
            selected: _filterStatus == '已完成',
            onSelected: (_) => _onStatusFilterSelected('已完成'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('已取消'),
            selected: _filterStatus == '已取消',
            onSelected: (_) => _onStatusFilterSelected('已取消'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('未到诊'),
            selected: _filterStatus == '未到诊',
            onSelected: (_) => _onStatusFilterSelected('未到诊'),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  void _onStatusFilterSelected(String status) {
    setState(() {
      _filterStatus = status;
    });
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return FutureBuilder<Patient?>(
      future: Provider.of<DatabaseProvider>(
        context,
        listen: false,
      ).getPatientById(appointment.patientId),
      builder: (context, snapshot) {
        final patient = snapshot.data;
        final statusInfo = _getStatusInfo(appointment.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            AppointmentDetailScreen(appointment: appointment),
                  ),
                ).then((_) => _loadAppointments());
              },
              child: Column(
                children: [
                  // 顶部时间栏
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppTheme.borderRadius),
                        topRight: Radius.circular(AppTheme.borderRadius),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 18,
                              color: statusInfo.color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'yyyy年MM月dd日',
                              ).format(appointment.appointmentDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryText,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.access_time,
                              size: 18,
                              color: statusInfo.color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(appointment.appointmentDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusInfo.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusInfo.color.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusInfo.icon,
                                size: 14,
                                color: statusInfo.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusInfo.text,
                                style: TextStyle(
                                  color: statusInfo.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 内容区域
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 患者信息
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.primaryColor
                                  .withOpacity(0.1),
                              child: Text(
                                patient?.name.isNotEmpty == true
                                    ? patient!.name.substring(0, 1)
                                    : "?",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient?.name ?? '加载中...',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryText,
                                    ),
                                  ),
                                  if (patient != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${patient.gender} | ${patient.age}岁 | ${_getDisplayPhone(patient.phone)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppTheme.backgroundColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chevron_right),
                                iconSize: 20,
                                color: AppTheme.secondaryText,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => AppointmentDetailScreen(
                                            appointment: appointment,
                                          ),
                                    ),
                                  ).then((_) => _loadAppointments());
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 预约详情
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(
                              AppTheme.smallBorderRadius,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailItem(
                                icon: Icons.medical_services_outlined,
                                title: '治疗类型',
                                value: _formatTreatmentType(
                                  appointment.treatmentType,
                                ),
                                color: AppTheme.secondaryColor,
                              ),
                              const Divider(height: 16),
                              _buildDetailItem(
                                icon: Icons.event_note_outlined,
                                title: '预约备注',
                                value:
                                    appointment.notes?.isNotEmpty == true
                                        ? appointment.notes!
                                        : '无备注',
                                color: AppTheme.accentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 底部操作区
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(AppTheme.borderRadius),
                        bottomRight: Radius.circular(AppTheme.borderRadius),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 预约ID
                        Text(
                          '预约 #${appointment.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.lightText,
                          ),
                        ),

                        // 操作按钮
                        Row(
                          children: [
                            _buildActionButton(
                              icon: Icons.edit_outlined,
                              label: '编辑',
                              color: AppTheme.primaryColor,
                              onTap:
                                  () => _showAppointmentDialog(
                                    context,
                                    editAppointment: appointment,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            if (appointment.status == 'scheduled')
                              _buildActionButton(
                                icon: Icons.check_circle_outline,
                                label: '完成',
                                color: AppTheme.successColor,
                                onTap:
                                    () => _changeAppointmentStatus(
                                      appointment,
                                      'completed',
                                    ),
                              ),
                            const SizedBox(width: 8),
                            if (appointment.status == 'scheduled')
                              _buildActionButton(
                                icon: Icons.cancel_outlined,
                                label: '取消',
                                color: AppTheme.errorColor,
                                onTap:
                                    () => _changeAppointmentStatus(
                                      appointment,
                                      'cancelled',
                                    ),
                              ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete_outline,
                              label: '删除',
                              color: AppTheme.errorColor,
                              onTap: () => _showDeleteConfirmation(appointment),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示预约表单对话框
  void _showAppointmentDialog(
    BuildContext context, {
    Appointment? editAppointment,
    DateTime? initialDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (dialogContext) => AppointmentFormSheet(
            appointment: editAppointment,
            initialDate: initialDate,
            onSaved: (isSuccess, message) {
              if (isSuccess) {
                // 使用局部刷新方法，只刷新预约列表，不影响其他页面
                Provider.of<DatabaseProvider>(
                  context,
                  listen: false,
                ).refreshAppointmentsData();

                // 主动触发当前页面刷新
                _loadAppointments();

                // 使用自定义Toast显示成功消息
                ToastUtil.showSuccess(context, message);
              } else {
                ToastUtil.showError(context, message);
              }
            },
          ),
    );
  }

  // 修改预约状态
  Future<void> _changeAppointmentStatus(
    Appointment appointment,
    String newStatus,
  ) async {
    final updated = appointment.copyWith(status: newStatus);

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      await dbProvider.updateAppointment(updated);

      // 刷新数据
      _loadAppointments();

      // 不再立即强制刷新仪表盘
      // dbProvider.forceDataChanged();

      // 显示提示
      if (!mounted) return;
      ToastUtil.showSuccess(context, '预约状态已更新');
    } catch (e) {
      print('更新预约状态错误: $e');

      // 显示错误提示
      if (!mounted) return;
      ToastUtil.showError(context, '更新预约状态失败: $e');
    }
  }

  // 获取状态信息
  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return _StatusInfo(
          text: '已预约',
          color: AppTheme.infoColor,
          icon: Icons.schedule,
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
          color: Colors.orange,
          icon: Icons.unpublished_outlined,
        );
      default:
        return _StatusInfo(
          text: status, // 显示原始状态
          color: AppTheme.secondaryText,
          icon: Icons.help_outline,
        );
    }
  }

  // 从JSON格式中获取显示电话号码
  String _getDisplayPhone(String phone) {
    if (phone.startsWith('[') && phone.endsWith(']')) {
      try {
        List<dynamic> phones = jsonDecode(phone);
        if (phones.isNotEmpty) {
          return phones[0].toString();
        }
      } catch (e) {
        print('解析电话号码JSON失败: $e');
      }
    }
    return phone;
  }

  void _showDeleteConfirmation(Appointment appointment) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这个预约吗？此操作无法撤销。'),
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
                  _deleteAppointment(appointment); // 再执行删除操作
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

  Future<void> _deleteAppointment(Appointment appointment) async {
    if (appointment.id == null) {
      if (!mounted) return;
      ToastUtil.showError(context, '无法删除：预约ID无效');
      return;
    }

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      await dbProvider.deleteAppointment(appointment.id!);

      // 刷新数据
      _loadAppointments();

      // 显示提示
      if (!mounted) return;
      ToastUtil.showSuccess(context, '预约已删除');
    } catch (e) {
      print('删除预约错误: $e');

      // 显示错误提示
      if (!mounted) return;
      ToastUtil.showError(context, '删除预约失败: $e');
    }
  }
}

class _StatusInfo {
  final String text;
  final Color color;
  final IconData icon;

  _StatusInfo({required this.text, required this.color, required this.icon});
}
