import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/main.dart';
import 'package:dentist_app/screens/appointment_detail_screen.dart';
import 'package:dentist_app/screens/patients_screen.dart';
import 'package:dentist_app/screens/appointments_screen.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _patientCount = 0;
  int _appointmentCount = 0;
  int _completedAppointments = 0;
  int _upcomingAppointments = 0;
  List<Appointment> _todayAppointments = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeIn,
    );

    // 启动动画
    _animationController.forward();

    // 主动加载数据，不等待依赖变更
    print('DashboardScreen 初始化，立即开始加载数据');
    _loadDataWithRetry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 获取数据库提供者
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // 在首次加载或当仪表盘需要刷新时加载数据
    if (dbProvider.isInitialized &&
        (_isLoading || dbProvider.dashboardNeedsRefresh)) {
      print('DashboardScreen 需要刷新数据');
      _loadDataWithRetry();

      // 重置刷新标志
      if (dbProvider.dashboardNeedsRefresh) {
        dbProvider.resetDashboardRefreshFlag();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 带重试机制的数据加载
  Future<void> _loadDataWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;
    bool success = false;

    while (!success && retryCount < maxRetries) {
      try {
        await _loadData();
        success = true;
      } catch (e) {
        retryCount++;
        print('加载数据失败 (尝试 $retryCount/$maxRetries): $e');

        if (retryCount < maxRetries) {
          // 增加延迟时间，以便后续尝试更可能成功
          await Future.delayed(Duration(seconds: 1 * retryCount));
        }
      }
    }

    if (!success && mounted) {
      print('多次重试后数据加载仍然失败');
      setState(() {
        _isLoading = false;
      });

      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('加载数据失败，请检查网络或存储权限'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '刷新',
            onPressed: _loadDataWithRetry,
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    print('开始加载仪表盘数据');
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取DatabaseProvider并确保初始化完成
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      print('获取到数据库提供者实例');

      // 确保数据库已初始化
      if (!dbProvider.isInitialized) {
        print('数据库未初始化，正在初始化...');
        try {
          await dbProvider.initDatabase();
          // 添加一点延迟确保数据库连接稳定
          await Future.delayed(const Duration(milliseconds: 500));
          print('数据库初始化完成');
        } catch (e) {
          print('尝试初始化数据库时出错: $e');
          // 再次尝试初始化
          print('尝试再次初始化数据库...');
          await Future.delayed(const Duration(seconds: 1));
          await dbProvider.initDatabase();
        }
      } else {
        print('数据库已初始化');
      }

      // 使用try-catch包装每个数据库操作，防止单个操作失败影响整体
      int patientCount = 0;
      try {
        print('正在获取患者数量...');
        patientCount = await dbProvider.getPatientCount();
        print('成功获取患者数量: $patientCount，数据库类型: ${dbProvider.dbType}');
      } catch (e) {
        print('获取患者数量错误: $e');
      }

      int appointmentCount = 0;
      try {
        print('正在获取预约数量...');
        appointmentCount = await dbProvider.getAppointmentCount();
        print('成功获取预约数量: $appointmentCount，数据库类型: ${dbProvider.dbType}');
      } catch (e) {
        print('获取预约数量错误: $e');
      }

      List<Appointment> todayAppointments = [];
      try {
        print('正在获取今日预约...');
        todayAppointments = await dbProvider.getTodayAppointments();
        print('成功获取今日预约: ${todayAppointments.length}');
      } catch (e) {
        print('获取今日预约错误: $e');
      }

      // 计算已完成和即将到来的预约数
      int completed = 0;
      int upcoming = 0;

      try {
        print('正在获取所有预约...');
        final allAppointments = await dbProvider.getAllAppointments();
        print('成功获取所有预约: ${allAppointments.length}');
        for (var appointment in allAppointments) {
          if (appointment.status == 'completed') {
            completed++;
          } else if (appointment.status == 'scheduled' &&
              appointment.appointmentDate.isAfter(DateTime.now())) {
            upcoming++;
          }
        }
        print('已完成预约: $completed, 即将到来的预约: $upcoming');
      } catch (e) {
        print('获取所有预约错误: $e');
      }

      // 确保组件还在挂载状态
      if (!mounted) return;

      print('更新UI状态');
      setState(() {
        _patientCount = patientCount;
        _appointmentCount = appointmentCount;
        _todayAppointments = todayAppointments;
        _completedAppointments = completed;
        _upcomingAppointments = upcoming;
        _isLoading = false;
      });

      // 启动动画
      if (mounted) {
        _animationController.reset();
        _animationController.forward();
        print('仪表盘数据加载完成');
      }
    } catch (e) {
      print('加载仪表盘数据错误: $e');
      // 确保组件还在挂载状态
      if (!mounted) return;

      // 即使出错也需要更新加载状态
      setState(() {
        _isLoading = false;
        // 设置默认值，确保UI不会因为数据缺失而崩溃
        _patientCount = 0;
        _appointmentCount = 0;
        _todayAppointments = [];
        _completedAppointments = 0;
        _upcomingAppointments = 0;
      });

      // 显示错误消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据出错，请尝试刷新: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '刷新',
              onPressed: _loadData,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('牙科诊所管理系统'),
        centerTitle: true,
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新数据',
          ),
        ],
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
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 24),
                    Text(
                      '正在加载仪表盘数据...',
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '首次加载可能需要几秒钟',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(),
                      const SizedBox(height: 24),
                      _buildStatisticsCards(),
                      const SizedBox(height: 24),
                      _buildTodayAppointmentsSection(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildWelcomeSection() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(now),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '今日预约: ${_todayAppointments.length}个',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value:
                  _appointmentCount > 0
                      ? _todayAppointments.length / _appointmentCount
                      : 0,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '患者总数',
                  value: _patientCount.toString(),
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.infoColor,
                  onTap: () {
                    // 导航到患者列表页面
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PatientsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: '预约总数',
                  value: _appointmentCount.toString(),
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.primaryColor,
                  onTap: () {
                    // 导航到预约管理页面
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AppointmentsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '已完成',
                  value: _completedAppointments.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.successColor,
                  onTap: () {
                    // 导航到预约管理页面（过滤为已完成）
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => const AppointmentsScreen(
                              initialFilterStatus: '已完成',
                            ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: '待处理',
                  value: _upcomingAppointments.toString(),
                  icon: Icons.schedule_rounded,
                  color: AppTheme.warningColor,
                  onTap: () {
                    // 导航到预约管理页面（过滤为待处理）
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => const AppointmentsScreen(
                              initialFilterStatus: '已预约',
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentsSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.today_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('今日预约', style: AppTheme.titleStyle),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (context) => MainScreen(
                            initialIndex: 2,
                            onDataChanged: () {
                              // 空实现，因为替换了整个页面
                            },
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text('全部预约'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _todayAppointments.isEmpty
              ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallBorderRadius,
                  ),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_available,
                        color: AppTheme.lightText,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '今日暂无预约',
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder:
                                  (context) => MainScreen(
                                    initialIndex: 2,
                                    onDataChanged: () {
                                      // 空实现，因为替换了整个页面
                                    },
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('新增预约'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : Column(
                children:
                    _todayAppointments.map((appointment) {
                      return FutureBuilder<Patient?>(
                        future: Provider.of<DatabaseProvider>(
                          context,
                          listen: false,
                        ).getPatientById(appointment.patientId),
                        builder: (context, snapshot) {
                          final patient = snapshot.data;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(
                                AppTheme.smallBorderRadius,
                              ),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppTheme.smallBorderRadius,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.smallBorderRadius,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => AppointmentDetailScreen(
                                            appointment: appointment,
                                          ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: _getColorForStatus(
                                              appointment.status,
                                            ).withOpacity(0.2),
                                            radius: 20,
                                            child: Text(
                                              patient?.name.isNotEmpty == true
                                                  ? patient!.name.substring(
                                                    0,
                                                    1,
                                                  )
                                                  : '?',
                                              style: TextStyle(
                                                color: _getColorForStatus(
                                                  appointment.status,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  patient?.name ?? '加载中...',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (patient
                                                        ?.medicalRecordNumber !=
                                                    null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '病历号: ${patient!.medicalRecordNumber}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme
                                                              .secondaryText,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          _buildStatusChip(appointment.status),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        children: [
                                          _buildInfoItem(
                                            icon: Icons.access_time,
                                            text: DateFormat('HH:mm').format(
                                              appointment.appointmentDate,
                                            ),
                                            color: AppTheme.infoColor,
                                          ),
                                          const SizedBox(width: 16),
                                          if (patient?.phone != null &&
                                              patient!.phone.isNotEmpty)
                                            _buildInfoItem(
                                              icon: Icons.phone,
                                              text: _getDisplayPhone(
                                                patient.phone,
                                              ),
                                              color: AppTheme.successColor,
                                            ),
                                        ],
                                      ),
                                      if (appointment.treatmentType !=
                                          null) ...[
                                        const SizedBox(height: 12),
                                        _buildInfoItem(
                                          icon: Icons.medical_services,
                                          text:
                                              '治疗项目: ${appointment.treatmentType}',
                                          color: AppTheme.primaryColor,
                                        ),
                                      ],
                                      if (patient?.treatmentItems != null &&
                                          patient!
                                              .treatmentItems!
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _buildInfoItem(
                                          icon: Icons.medical_information,
                                          text:
                                              '病患治疗项目: ${patient.treatmentItems!.length > 15 ? '${patient.treatmentItems!.substring(0, 15)}...' : patient.treatmentItems}',
                                          color: Colors.deepOrange,
                                        ),
                                      ],
                                      if (appointment.notes != null &&
                                          appointment.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _buildInfoItem(
                                          icon: Icons.notes,
                                          text: '备注: ${appointment.notes}',
                                          color: AppTheme.warningColor,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.secondaryText),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final statusInfo = _getStatusInfo(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusInfo.text,
        style: TextStyle(
          color: statusInfo.color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getColorForStatus(String status) {
    return _getStatusInfo(status).color;
  }

  StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'scheduled':
        return StatusInfo(color: AppTheme.infoColor, text: '已预约');
      case 'completed':
        return StatusInfo(color: AppTheme.successColor, text: '已完成');
      case 'cancelled':
        return StatusInfo(color: AppTheme.errorColor, text: '已取消');
      case 'in_progress':
        return StatusInfo(color: AppTheme.warningColor, text: '进行中');
      default:
        return StatusInfo(color: AppTheme.lightText, text: '未知');
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

  // 公共方法：允许外部调用刷新仪表盘数据
  void refreshDashboardData() {
    print('外部请求刷新仪表盘数据');
    if (mounted) {
      _loadDataWithRetry();
    }
  }
}

class StatusInfo {
  final Color color;
  final String text;

  StatusInfo({required this.color, required this.text});
}
