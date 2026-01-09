import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:animated_text_kit/animated_text_kit.dart'; // 暂时注释掉
// import 'package:shimmer/shimmer.dart'; // 暂时注释掉
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../providers/database_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/user_provider.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../providers/app_state.dart';
import '../screens/appointment_details_screen.dart';
import '../screens/appointments_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/patient_detail_screen.dart';
import '../utils/permission_utils.dart';

class ModernDashboardScreen extends StatefulWidget {
  const ModernDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ModernDashboardScreen> createState() => _ModernDashboardScreenState();
}

class _ModernDashboardScreenState extends State<ModernDashboardScreen>
    with TickerProviderStateMixin {
  int _patientCount = 0;
  int _appointmentCount = 0;
  int _completedAppointments = 0;
  int _upcomingAppointments = 0;
  List<Appointment> _todayAppointments = [];
  List<Patient> _recentPatients = [];
  bool _isLoading = true;
  String _currentUserName = '';
  Uint8List? _currentUserAvatar;
  
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }



  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 获取当前用户信息（优先从UserProvider获取）
      final currentUser = userProvider.currentUser ?? await databaseProvider.getCurrentUser();
      // 优先使用医生姓名，如果没有则使用用户名
      _currentUserName = currentUser?.doctor?.isNotEmpty == true 
          ? currentUser!.doctor! 
          : (currentUser?.username ?? '');
      // 获取用户头像
      if (currentUser?.imageData != null && currentUser!.imageData!.isNotEmpty) {
        _currentUserAvatar = Uint8List.fromList(currentUser!.imageData!);
      } else {
        _currentUserAvatar = null;
      }
      
      // 获取统计数据（已通过Provider自动应用权限过滤）
      final patients = await patientProvider.getAllPatients();
      final appointments = await appointmentProvider.getAllAppointments();
      
      // 记录权限过滤信息
      if (currentUser != null && !currentUser.isAdmin) {
        print('仪表盘数据权限过滤: 用户=${currentUser.username}, 医生=${currentUser.doctor}, 患者数=${patients.length}, 预约数=${appointments.length}');
      } else {
        print('仪表盘数据无权限过滤: 管理员用户或未登录, 患者数=${patients.length}, 预约数=${appointments.length}');
      }
      
      // 获取今日预约
      final today = DateTime.now();
      final todayAppointments = appointments.where((appointment) {
        final appointmentDate = appointment.appointment_date;
        return appointmentDate.year == today.year &&
            appointmentDate.month == today.month &&
            appointmentDate.day == today.day;
      }).toList();
      
      // 按时间排序今日预约
      todayAppointments.sort((a, b) => a.appointment_date.compareTo(b.appointment_date));
      
      // 获取最近的患者（按更新时间排序）
      final recentPatients = List<Patient>.from(patients);
      recentPatients.sort((a, b) => b.updated_at.compareTo(a.updated_at));
      
      // 计算完成和即将到来的预约
      final completed = appointments.where((a) => a.status == '已完成').length;
      final upcoming = appointments.where((a) => 
        a.appointment_date.isAfter(DateTime.now()) && a.status == '已预约').length;

      setState(() {
        _patientCount = patients.length;
        _appointmentCount = appointments.length;
        _completedAppointments = completed;
        _upcomingAppointments = upcoming;
        _todayAppointments = todayAppointments.take(5).toList();
        _recentPatients = recentPatients.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载数据失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DentalColors.background,
      body: _isLoading ? _buildLoadingView() : _buildDashboardContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Icon(
                DentalIcons.tooth,
                size: 64,
                color: DentalColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '正在加载数据...',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w600,
              color: DentalColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildStatsGrid(),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 500,
                      child: _buildTodaySection(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 500,
                      child: _buildRecentPatientsSection(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }



  Widget _buildWelcomeCard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DentalColors.primary,
                    DentalColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: DentalColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: _currentUserAvatar != null && _currentUserAvatar!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Image.memory(
                                _currentUserAvatar!,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      DentalIcons.userDoctor,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              DentalIcons.userDoctor,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '你好，$_currentUserName',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '欢迎回来工作，祝您今天心情愉快！',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                    onPressed: _loadData,
                    tooltip: '刷新数据',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 0.8),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: '总患者数',
                    value: _patientCount.toString(),
                    icon: DentalIcons.hospitalUser,
                    color: DentalColors.primary,
                    onTap: PermissionUtils.hasModulePermission(context, 'patients') ? () {
                      final appState = Provider.of<AppState>(context, listen: false);
                      appState.activePageIndex = 1;
                    } : () {
                      PermissionUtils.showPermissionDeniedDialog(
                        context,
                        message: '您没有访问患者管理的权限。',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: '总预约数',
                    value: _appointmentCount.toString(),
                    icon: DentalIcons.calendarCheck,
                    color: DentalColors.secondary,
                    onTap: PermissionUtils.hasModulePermission(context, 'appointments') ? () {
                      final appState = Provider.of<AppState>(context, listen: false);
                      appState.activePageIndex = 2;
                    } : () {
                      PermissionUtils.showPermissionDeniedDialog(
                        context,
                        message: '您没有访问预约管理的权限。',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: '已完成',
                    value: _completedAppointments.toString(),
                    icon: DentalIcons.completed,
                    color: DentalColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: '即将到来',
                    value: _upcomingAppointments.toString(),
                    icon: DentalIcons.pending,
                    color: DentalColors.info,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return _HoverableStatCard(
      onTap: onTap,
      child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey[400],
                  ),
              ],
            ),
    );
  }

  Widget _buildTodaySection() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 0.6),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DentalColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            DentalIcons.calendarCheck,
                            color: DentalColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '今日预约',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: DentalColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: DentalColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_todayAppointments.length} 个',
                            style: TextStyle(
                              color: DentalColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _todayAppointments.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(48),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        DentalIcons.calendarCheck,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '今天暂无预约',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '享受轻松的一天吧',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _todayAppointments.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildTodayAppointmentCard(_todayAppointments[index]);
                              },
                            ),
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

  Widget _buildTodayAppointmentCard(Appointment appointment) {
    final time = DateFormat('HH:mm').format(appointment.appointment_date);
    final statusColor = _getStatusColor(appointment.status);
    final gender = appointment.patient?.gender ?? '';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: PermissionUtils.hasModulePermission(context, 'appointments') ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailsScreen(
                  appointmentId: appointment.id!,
                ),
              ),
            );
          } : () {
            PermissionUtils.showPermissionDeniedDialog(
              context,
              message: '您没有查看预约详情的权限。',
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time.split(':')[0],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        time.split(':')[1],
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            DentalIcons.getGenderIcon(gender),
                            size: 16,
                            color: gender == '女' ? DentalColors.femalePink : DentalColors.maleBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            appointment.patient?.name ?? '未知患者',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTreatmentType(appointment.treatment_type),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPatientsSection() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 0.4),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DentalColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            DentalIcons.hospitalUser,
                            color: DentalColors.secondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '最近患者',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: DentalColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        PermissionWrapper(
                          requiredModule: 'patients',
                          fallback: Icon(Icons.lock, size: 18, color: Colors.grey[400]),
                          child: TextButton.icon(
                            onPressed: () {
                              final appState = Provider.of<AppState>(context, listen: false);
                              appState.activePageIndex = 1;
                            },
                            icon: Icon(Icons.arrow_forward_rounded, size: 16),
                            label: const Text('查看全部'),
                            style: TextButton.styleFrom(
                              foregroundColor: DentalColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _recentPatients.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(48),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        DentalIcons.hospitalUser,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '暂无患者记录',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '开始添加您的第一位患者',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _recentPatients.length,
                              separatorBuilder: (context, index) => Divider(
                                color: Colors.grey[200],
                                height: 24,
                              ),
                              itemBuilder: (context, index) {
                                return _buildPatientListTile(_recentPatients[index]);
                              },
                            ),
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

  Widget _buildPatientListTile(Patient patient) {
    final genderColor = patient.gender == '女' 
        ? DentalColors.femalePink 
        : DentalColors.maleBlue;
    
    // 获取显示的电话号码
    String displayPhone = '未设置';
    if (patient.phone.isNotEmpty) {
      try {
        // 尝试解析JSON格式的电话号码
        if (patient.phone.startsWith('[')) {
          final phones = json.decode(patient.phone) as List;
          if (phones.isNotEmpty) {
            displayPhone = phones[0].toString();
          }
        } else {
          displayPhone = patient.phone;
        }
      } catch (e) {
        displayPhone = patient.phone;
      }
    }
    
    return InkWell(
      onTap: PermissionUtils.hasModulePermission(context, 'patients') ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailScreen(patient: patient),
          ),
        );
      } : () {
        PermissionUtils.showPermissionDeniedDialog(
          context,
          message: '您没有查看患者详情的权限。',
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: genderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                DentalIcons.getGenderIcon(patient.gender),
                color: genderColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: DentalColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 病历号
                      if (patient.medical_record_number != null) ...[
                        Icon(
                          Icons.badge,
                          size: 12,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.medical_record_number}',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // 电话
                      Icon(
                        Icons.phone,
                        size: 12,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          displayPhone,
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // 地址（如果有）
                  if (patient.address != null && patient.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.orange[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            patient.address!,
                            style: TextStyle(
                              color: Colors.orange[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('MM/dd').format(patient.updated_at),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Color _getStatusColor(String status) {
    switch (status) {
      case '已完成':
        return DentalColors.success;
      case '已预约':
        return DentalColors.info;
      case '已取消':
        return DentalColors.error;
      case '未到诊':
        return DentalColors.warning;
      default:
        return DentalColors.onSurfaceVariant;
    }
  }

  String _formatTreatmentType(String? treatmentType) {
    if (treatmentType == null || treatmentType.isEmpty) {
      return '常规检查';
    }
    
    try {
      final data = json.decode(treatmentType);
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

      return displayParts.isNotEmpty ? displayParts.join(' ') : '常规检查';
    } catch (e) {
      // 如果不是JSON格式，直接返回
      return treatmentType;
    }
  }
}

// 可悬浮的统计卡片组件
class _HoverableStatCard extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _HoverableStatCard({
    Key? key,
    this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  State<_HoverableStatCard> createState() => _HoverableStatCardState();
}

class _HoverableStatCardState extends State<_HoverableStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered && widget.onTap != null
                ? Color(0xFFE3F2FD)  // 淡蓝色
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
