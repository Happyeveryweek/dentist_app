import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/dental_treatment.dart';
import '../providers/app_state.dart';
import '../screens/appointment_details_screen.dart';
import '../screens/appointments_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/patient_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

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
  List<Patient> _recentPatients = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 牙位映射表 - 从医生视角看患者牙齿
  final Map<String, String> positionMap = {
    'topLeft': '右上',
    'topRight': '左上',
    'bottomLeft': '右下',
    'bottomRight': '左下',
  };

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
    );

    // 启动动画
    _animationController.forward();

    // 延迟加载数据以允许动画先播放
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 获取数据库提供者
    final dbProvider = Provider.of<DatabaseProvider>(context);
    final appState = Provider.of<AppState>(context);

    // 如果仪表盘需要刷新，重新加载数据
    if (dbProvider.dashboardNeedRefresh || appState.activePageIndex == 0) {
      _loadData();
      dbProvider.resetDashboardRefreshFlag();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 加载数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 获取当前用户
      final currentUser = await dbProvider.getCurrentUser();
      final isAdmin = currentUser?.role == 'admin';
      final doctorName = currentUser?.doctor;

      // 如果是普通医生且有医生姓名
      final bool isFilterByDoctor =
          !isAdmin && doctorName != null && doctorName.isNotEmpty;

      print('开始加载仪表盘数据...');

      // 获取统计数据，根据用户角色过滤
      final patientCount = await dbProvider.getPatientCount(
          doctorName: isFilterByDoctor ? doctorName : null);
      print('获取到患者总数: $patientCount');

      final appointmentCount = await dbProvider.getAppointmentCount(
          doctorName: isFilterByDoctor ? doctorName : null);
      print('获取到预约总数: $appointmentCount');

      final completedAppointments =
          await dbProvider.getCompletedAppointmentCount(
              doctorName: isFilterByDoctor ? doctorName : null);
      print('获取到已完成预约数: $completedAppointments');

      final todayAppointments = await dbProvider.getTodayAppointments(
          doctorName: isFilterByDoctor ? doctorName : null);
      print('获取到今日预约数: ${todayAppointments.length}');

      final recentPatients = await dbProvider.getRecentPatients(
          limit: 5, doctorName: isFilterByDoctor ? doctorName : null);
      print('获取到最近患者数: ${recentPatients.length}');

      // 更新状态
      setState(() {
        _patientCount = patientCount;
        _appointmentCount = appointmentCount;
        _completedAppointments = completedAppointments;
        _upcomingAppointments = todayAppointments.length;
        _todayAppointments = todayAppointments;
        _recentPatients = recentPatients;
        _isLoading = false;
      });

      print('仪表盘数据加载完成');
    } catch (e) {
      print('加载仪表盘数据错误: $e');
      setState(() {
        _isLoading = false;
      });

      // 显示错误消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 欢迎消息
                    const Text('欢迎使用牙科诊所管理系统', style: AppTheme.headingStyle),
                    const SizedBox(height: 8),
                    Text(
                      '今天是 ${DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(DateTime.now())}',
                      style: AppTheme.bodyStyle,
                    ),
                    const SizedBox(height: 24),

                    // 统计卡片行
                    _buildStatisticsRow(),
                    const SizedBox(height: 24),

                    // 今日预约
                    _buildTodayAppointmentsSection(),
                    const SizedBox(height: 24),

                    // 最近添加的患者
                    _buildRecentPatientsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // 构建统计卡片行
  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '总患者数',
            _patientCount.toString(),
            Icons.people,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '总预约数',
            _appointmentCount.toString(),
            Icons.event,
            AppTheme.accentColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '已完成预约',
            _completedAppointments.toString(),
            Icons.check_circle,
            AppTheme.secondaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '今日预约',
            _upcomingAppointments.toString(),
            Icons.today,
            AppTheme.infoColor,
          ),
        ),
      ],
    );
  }

  // 构建统计卡片
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isGreyMode =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.greyBackground;
    final bool isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    // 确定卡片颜色
    final Color cardBgColor = isDarkMode
        ? AppTheme.darkCardBackground
        : isGreyMode
            ? AppTheme.greyCardBackground
            : isPurpleTheme
                ? AppTheme.purpleCardBackground
                : Colors.white;

    // 确定阴影
    final List<BoxShadow> cardShadow = isDarkMode || isGreyMode
        ? [] // 深色模式和灰色模式下不使用阴影
        : isPurpleTheme
            ? AppTheme.purpleCardShadow // 紫色主题使用紫色阴影
            : AppTheme.cardShadow;

    // 紫色主题下添加边框
    final Border? cardBorder = isPurpleTheme
        ? Border.all(
            color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
        : null;

    // 文字颜色
    final Color textColor = isDarkMode
        ? AppTheme.darkPrimaryText
        : isGreyMode
            ? AppTheme.greyPrimaryText
            : isPurpleTheme
                ? AppTheme.purplePrimaryText
                : AppTheme.primaryText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: cardShadow,
        border: cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: isPurpleTheme ? AppTheme.purpleColor : color,
                  size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isPurpleTheme
                      ? AppTheme.purpleSecondaryText
                      : isDarkMode
                          ? AppTheme.darkSecondaryText
                          : isGreyMode
                              ? AppTheme.greySecondaryText
                              : AppTheme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // 构建今日预约部分
  Widget _buildTodayAppointmentsSection() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isGreyMode =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.greyBackground;
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    // 卡片背景色
    final Color cardColor = isDarkMode
        ? AppTheme.darkCardBackground
        : isGreyMode
            ? AppTheme.greyCardBackground
            : isPurpleTheme
                ? AppTheme.purpleCardBackground
                : Colors.white;

    // 标题样式
    final TextStyle titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: isDarkMode
          ? AppTheme.darkPrimaryText
          : isGreyMode
              ? AppTheme.greyPrimaryText
              : isPurpleTheme
                  ? AppTheme.purplePrimaryText
                  : AppTheme.primaryText,
    );

    // 文本样式
    final TextStyle textStyle = TextStyle(
      color: isDarkMode
          ? AppTheme.darkSecondaryText
          : isGreyMode
              ? AppTheme.greySecondaryText
              : isPurpleTheme
                  ? AppTheme.purpleSecondaryText
                  : AppTheme.secondaryText,
    );

    // 阴影设置
    final List<BoxShadow> cardShadow = isDarkMode || isGreyMode
        ? []
        : isPurpleTheme
            ? AppTheme.purpleCardShadow
            : AppTheme.cardShadow;

    // 紫色主题下添加边框
    final Border? cardBorder = isPurpleTheme
        ? Border.all(
            color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('今日预约', style: titleStyle),
        const SizedBox(height: 16),
        if (_todayAppointments.isEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              boxShadow: cardShadow,
              border: cardBorder,
            ),
            child: Center(
              child: Text('今天没有预约', style: textStyle),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              boxShadow: cardShadow,
              border: cardBorder,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayAppointments.length,
              separatorBuilder: (context, index) => Divider(
                color: isDarkMode
                    ? AppTheme.darkDividerColor
                    : isGreyMode
                        ? AppTheme.greyDividerColor
                        : isPurpleTheme
                            ? AppTheme.purpleDividerColor
                            : Colors.grey.shade200,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final appointment = _todayAppointments[index];
                final timeString =
                    DateFormat('HH:mm').format(appointment.appointment_date);
                final gender = appointment.patient?.gender ?? '';

                // 根据性别设置颜色
                final Color genderColor = gender == '女'
                    ? Colors.pink.shade100.withOpacity(0.3)
                    : Colors.blue.shade100.withOpacity(0.3);

                final Color iconColor =
                    gender == '女' ? Colors.pink.shade300 : Colors.blue.shade300;

                // 处理治疗项目显示
                String treatmentDisplay = '常规复诊';
                if (appointment.treatment_type != null &&
                    appointment.treatment_type!.isNotEmpty) {
                  try {
                    // 尝试解析JSON格式的treatment_type
                    Map<String, dynamic> data =
                        json.decode(appointment.treatment_type!);

                    // 处理治疗项目
                    List<String> treatments = [];
                    if (data.containsKey('treatments') &&
                        data['treatments'] is List &&
                        (data['treatments'] as List).isNotEmpty) {
                      treatments = List<String>.from(data['treatments']);
                      treatmentDisplay = treatments.join('、');
                    }

                    // 处理牙位信息
                    List<String> teethPositions = [];
                    if (data.containsKey('teethData') &&
                        data['teethData'] is List &&
                        (data['teethData'] as List).isNotEmpty) {
                      List teethData = data['teethData'];

                      for (int i = 0; i < teethData.length; i++) {
                        Map<String, dynamic> tooth = teethData[i];
                        List<String> positions = [];

                        // 使用正确的字段名和映射关系处理牙位
                        tooth.forEach((region, value) {
                          if (value != null && value.toString().isNotEmpty) {
                            String? position = positionMap[region];
                            if (position != null) {
                              positions.add('$position$value');
                            }
                          }
                        });

                        if (positions.isNotEmpty) {
                          teethPositions
                              .add('牙位${i + 1}: ${positions.join('，')}');
                        }
                      }
                    }

                    // 组合最终显示文本
                    if (teethPositions.isNotEmpty) {
                      if (treatments.isNotEmpty) {
                        treatmentDisplay =
                            '${teethPositions.join(' ')}${treatments.isEmpty ? '' : ' - ${treatments.join("、")}'}';
                      } else {
                        treatmentDisplay = teethPositions.join(' ');
                      }
                    }
                  } catch (e) {
                    // 如果解析失败，使用原始字符串
                    treatmentDisplay = appointment.treatment_type!;
                  }
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: genderColor,
                    child: Icon(
                      Icons.calendar_today,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    appointment.patient?.name ?? '未知患者',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppTheme.darkPrimaryText
                          : isGreyMode
                              ? AppTheme.greyPrimaryText
                              : isPurpleTheme
                                  ? AppTheme.purplePrimaryText
                                  : AppTheme.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    '$treatmentDisplay · ${DateFormat('MM-dd').format(appointment.appointment_date)} ${timeString}',
                    style: textStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(appointment.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(appointment.status),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _getStatusColor(appointment.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(appointment.status),
                          style: TextStyle(
                            color: _getStatusColor(appointment.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                );
              },
            ),
          ),
      ],
    );
  }

  // 构建最近患者部分
  Widget _buildRecentPatientsSection() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isGreyMode =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.greyBackground;
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    // 卡片背景色
    final Color cardColor = isDarkMode
        ? AppTheme.darkCardBackground
        : isGreyMode
            ? AppTheme.greyCardBackground
            : isPurpleTheme
                ? AppTheme.purpleCardBackground
                : Colors.white;

    // 标题样式
    final TextStyle titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: isDarkMode
          ? AppTheme.darkPrimaryText
          : isGreyMode
              ? AppTheme.greyPrimaryText
              : isPurpleTheme
                  ? AppTheme.purplePrimaryText
                  : AppTheme.primaryText,
    );

    // 文本样式
    final TextStyle textStyle = TextStyle(
      color: isDarkMode
          ? AppTheme.darkSecondaryText
          : isGreyMode
              ? AppTheme.greySecondaryText
              : isPurpleTheme
                  ? AppTheme.purpleSecondaryText
                  : AppTheme.secondaryText,
    );

    // 阴影设置
    final List<BoxShadow> cardShadow = isDarkMode || isGreyMode
        ? []
        : isPurpleTheme
            ? AppTheme.purpleCardShadow
            : AppTheme.cardShadow;

    // 紫色主题下添加边框
    final Border? cardBorder = isPurpleTheme
        ? Border.all(
            color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最近添加的患者', style: titleStyle),
        const SizedBox(height: 16),
        if (_recentPatients.isEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              boxShadow: cardShadow,
              border: cardBorder,
            ),
            child: Center(
              child: Text('暂无患者数据', style: textStyle),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              boxShadow: cardShadow,
              border: cardBorder,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentPatients.length,
              separatorBuilder: (context, index) => Divider(
                color: isDarkMode
                    ? AppTheme.darkDividerColor
                    : isGreyMode
                        ? AppTheme.greyDividerColor
                        : isPurpleTheme
                            ? AppTheme.purpleDividerColor
                            : Colors.grey.shade200,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final patient = _recentPatients[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.secondaryColor.withOpacity(0.2),
                    child: Text(
                      patient.name.isNotEmpty ? patient.name[0] : '?',
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    patient.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppTheme.darkPrimaryText
                          : isGreyMode
                              ? AppTheme.greyPrimaryText
                              : isPurpleTheme
                                  ? AppTheme.purplePrimaryText
                                  : AppTheme.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    '${patient.age}岁 · ${patient.gender} · ${DateFormat('yyyy/MM/dd').format(patient.first_visit_date)}',
                    style: textStyle,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: isDarkMode
                        ? AppTheme.darkSecondaryText
                        : isGreyMode
                            ? AppTheme.greySecondaryText
                            : isPurpleTheme
                                ? AppTheme.purpleSecondaryText
                                : Colors.grey,
                  ),
                  onTap: () {
                    if (patient.id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientDetailScreen(
                            patientId: patient.id!,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // 获取状态颜色
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case '已预约':
        return Colors.blue;
      case 'completed':
      case '已完成':
        return Colors.green;
      case 'cancelled':
      case '已取消':
        return Colors.red;
      case 'no_show':
      case 'missed':
      case '未到诊':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // 获取状态文本
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return '已预约';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      case 'no_show':
      case 'missed':
        return '未到诊';
      default:
        // 如果状态本身就是中文，直接返回
        if (status == '已预约' ||
            status == '已完成' ||
            status == '已取消' ||
            status == '未到诊') {
          return status;
        }
        return status; // 使用原始状态文本而不是'未知'
    }
  }
}
