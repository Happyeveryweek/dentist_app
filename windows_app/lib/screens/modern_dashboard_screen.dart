import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import 'package:animated_text_kit/animated_text_kit.dart'; // 暂时注释掉
// import 'package:shimmer/shimmer.dart'; // 暂时注释掉
import 'dart:convert';
import 'dart:typed_data';

import '../features/dashboard/widgets/hoverable_stat_card.dart';
import '../features/dashboard/services/dashboard_treatment_formatter.dart';
import '../features/dashboard/services/dashboard_data_service.dart';
import '../features/dashboard/helpers/dashboard_status_helper.dart';
import '../widgets/dental_icons.dart';
import '../providers/database_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/user_provider.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../providers/app_state.dart';
import '../screens/appointment_details_screen.dart';
import '../screens/patient_detail_screen.dart';
import '../utils/permission_utils.dart';
import '../widgets/success_toast.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../theme/app_theme.dart';

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
  int _todayAppointmentCount = 0;
  List<Appointment> _todayAppointments = [];
  List<Patient> _recentPatients = [];
  bool _isLoading = true;
  bool _isRefreshingData = false;
  bool _hasLoadedOnce = false;
  String _currentUserName = '';
  Uint8List? _currentUserAvatar;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late DashboardDataService _dashboardDataService;
  late AppointmentProvider _appointmentProvider;

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

    // 初始化仪表盘数据服务
    final patientProvider =
        Provider.of<PatientProvider>(context, listen: false);
    final appointmentProvider =
        Provider.of<AppointmentProvider>(context, listen: false);
    final databaseProvider =
        Provider.of<DatabaseProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _dashboardDataService = DashboardDataService(
      patientProvider: patientProvider,
      appointmentProvider: appointmentProvider,
      databaseProvider: databaseProvider,
      userProvider: userProvider,
    );
    _appointmentProvider = appointmentProvider;
    _appointmentProvider.addListener(_handleAppointmentProviderChanged);

    _loadData();
  }

  @override
  void dispose() {
    _appointmentProvider.removeListener(_handleAppointmentProviderChanged);
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleAppointmentProviderChanged() {
    if (!mounted || _isRefreshingData) {
      return;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    if (_isRefreshingData) {
      return;
    }

    _isRefreshingData = true;
    if (mounted && !_hasLoadedOnce) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _dashboardDataService.loadData();

      if (!mounted) return;

      setState(() {
        _patientCount = data.patientCount;
        _appointmentCount = data.appointmentCount;
        _completedAppointments = data.completedAppointments;
        _upcomingAppointments = data.upcomingAppointments;
        _todayAppointmentCount = data.todayAppointmentsCount;
        _todayAppointments = data.todayAppointments;
        _recentPatients = data.recentPatients;
        _currentUserName = data.currentUserName;
        _currentUserAvatar = data.currentUserAvatar;
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _isRefreshingData = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.pageBackground,
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
                  color: Colors.black.withValues(alpha: 0.1),
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
                color: context.tokens.primaryAccent,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '正在加载数据...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.tokens.primaryAccent,
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
                    context.tokens.primaryAccent,
                    context.tokens.primaryAccent.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: context.tokens.primaryAccent.withValues(alpha: 0.3),
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Builder(builder: (context) {
                      final avatar = _currentUserAvatar;
                      if (avatar != null && avatar.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Image.memory(
                              avatar,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.1),
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
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          DentalIcons.userDoctor,
                          color: Colors.white,
                          size: 32,
                        ),
                      );
                    }),
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
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 24),
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
                    color: context.tokens.primaryAccent,
                    onTap: PermissionUtils.hasModulePermission(
                            context, 'patients')
                        ? () {
                            final appState =
                                Provider.of<AppState>(context, listen: false);
                            appState.activePageIndex = 1;
                          }
                        : () {
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
                    color: context.tokens.secondaryAccent,
                    onTap: PermissionUtils.hasModulePermission(
                            context, 'appointments')
                        ? () {
                            final appState =
                                Provider.of<AppState>(context, listen: false);
                            appState.activePageIndex = 2;
                          }
                        : () {
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
    return HoverableStatCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
                    color: Colors.black.withValues(alpha: 0.05),
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
                            color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            DentalIcons.calendarCheck,
                            color: context.tokens.primaryAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '今日预约',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildTodaySummaryChip(
                                label: '已预约',
                                value: dataTodayScheduledAppointments,
                                color: DentalColors.info,
                              ),
                              _buildTodaySummaryChip(
                                label: '已完成',
                                value: dataTodayCompletedAppointments,
                                color: DentalColors.success,
                              ),
                              _buildTodaySummaryChip(
                                label: '未完成',
                                value: dataTodayUnfinishedAppointments,
                                color: DentalColors.warning,
                              ),
                              _buildTodaySummaryChip(
                                label: '合计',
                                value: _todayAppointmentCount,
                                color: context.tokens.primaryAccent,
                              ),
                            ],
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
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildTodayAppointmentCard(
                                    _todayAppointments[index]);
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

  int get dataTodayScheduledAppointments {
    return _todayAppointments
        .where((appointment) =>
            DashboardStatusHelper.isScheduled(appointment.status))
        .length;
  }

  int get dataTodayCompletedAppointments {
    return _todayAppointments
        .where((appointment) =>
            DashboardStatusHelper.isCompleted(appointment.status))
        .length;
  }

  int get dataTodayUnfinishedAppointments {
    return _todayAppointments
        .where((appointment) =>
            DashboardStatusHelper.isUnfinished(appointment.status))
        .length;
  }

  Widget _buildTodaySummaryChip({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentCard(Appointment appointment) {
    final time = DateFormat('HH:mm').format(appointment.appointmentDate);
    final statusColor =
        DashboardStatusHelper.getStatusColor(appointment.status);
    final gender = appointment.patient?.gender ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: PermissionUtils.hasModulePermission(context, 'appointments')
              ? () {
                  final appointmentId = appointment.id;
                  if (appointmentId == null) {
                    AppToastManager.showError(context, message: '预约 ID 为空');
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentDetailsScreen(
                        appointmentId: appointmentId,
                      ),
                    ),
                  );
                }
              : () {
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
                    color: statusColor.withValues(alpha: 0.1),
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
                          color: statusColor.withValues(alpha: 0.7),
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
                            color: gender == '女'
                                ? DentalColors.femalePink
                                : DentalColors.maleBlue,
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
                        DashboardTreatmentFormatter.formatTreatmentType(
                            appointment.treatmentType),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.statusDisplay,
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
                    color: Colors.black.withValues(alpha: 0.05),
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
                            color:
                                context.tokens.secondaryAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            DentalIcons.hospitalUser,
                            color: context.tokens.secondaryAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '最近患者',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        PermissionWrapper(
                          requiredModule: 'patients',
                          fallback: Icon(Icons.lock,
                              size: 18, color: Colors.grey[400]),
                          child: TextButton.icon(
                            onPressed: () {
                              final appState =
                                  Provider.of<AppState>(context, listen: false);
                              appState.activePageIndex = 1;
                            },
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 16),
                            label: const Text('查看全部'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.tokens.primaryAccent,
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
                                return _buildPatientListTile(
                                    _recentPatients[index]);
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
    final genderColor =
        patient.gender == '女' ? DentalColors.femalePink : DentalColors.maleBlue;

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
      onTap: PermissionUtils.hasModulePermission(context, 'patients')
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientDetailScreen(patient: patient),
                ),
              );
            }
          : () {
              PermissionUtils.showPermissionDeniedDialog(
                context,
                message: '您没有查看患者详情的权限。',
              );
            },
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: genderColor.withValues(alpha: 0.1),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 病历号
                      if (patient.medicalRecordNumber != null) ...[
                        Icon(
                          Icons.badge,
                          size: 12,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.medicalRecordNumber}',
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
                  Builder(builder: (context) {
                    final address = patient.address;
                    if (address == null || address.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
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
                                address,
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
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('MM/dd').format(patient.updatedAt),
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
}
