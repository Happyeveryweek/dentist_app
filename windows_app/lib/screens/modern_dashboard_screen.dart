import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import 'package:animated_text_kit/animated_text_kit.dart'; // 暂时注释掉
// import 'package:shimmer/shimmer.dart'; // 暂时注释掉
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../features/dashboard/widgets/hoverable_stat_card.dart';
import '../features/dashboard/services/dashboard_treatment_formatter.dart';
import '../features/dashboard/services/dashboard_data_service.dart';
import '../features/dashboard/helpers/dashboard_status_helper.dart';
import '../widgets/dental_icons.dart';
import '../widgets/hoverable_list_card.dart';
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
import 'package:dentist_app_windows/theme/medical_semantic_colors.dart';

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
  late AnimationController _welcomeAmbientController;
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

    _welcomeAmbientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

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
    _welcomeAmbientController.dispose();
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
          SnackBar(
              content: Text('加载数据失败: $e'),
              backgroundColor: context.tokens.error),
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
              color: context.tokens.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: context.tokens.shadow,
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 980;
            final bannerHeight =
                (constraints.maxWidth / 7.2).clamp(140.0, 214.0).toDouble();
            final horizontalPadding = isCompact ? 28.0 : 40.0;

            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  height: bannerHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: context.tokens.cardShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform.scale(
                          scale: 1.08,
                          child: Image.asset(
                            'assets/images/home_welcome_banner.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                        IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _welcomeAmbientController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _WelcomeBannerAmbientPainter(
                                  progress: _welcomeAmbientController.value,
                                  primary: context.tokens.primaryAccent,
                                  secondary: context.tokens.secondaryAccent,
                                  panel: context.tokens.cardBackground,
                                  border: context.tokens.border,
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: isCompact ? 22 : 28,
                          ),
                          child: Row(
                            children: [
                              _buildWelcomeAvatar(
                                size: isCompact ? 56 : 64,
                              ),
                              SizedBox(width: isCompact ? 16 : 20),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '你好，$_currentUserName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isCompact ? 24 : 28,
                                        fontWeight: FontWeight.bold,
                                        color: context.tokens.primaryAccent,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '欢迎回来工作，祝您今天心情愉快！',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isCompact ? 14 : 15,
                                        color: context.colors.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  color: context.tokens.primaryAccent,
                                  size: 24,
                                ),
                                onPressed: _loadData,
                                tooltip: '刷新数据',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeAvatar({required double size}) {
    final avatar = _currentUserAvatar;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: context.tokens.border.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: avatar != null && avatar.isNotEmpty
            ? Image.memory(
                avatar,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) {
                  return _buildWelcomeAvatarFallback();
                },
              )
            : _buildWelcomeAvatarFallback(),
      ),
    );
  }

  Widget _buildWelcomeAvatarFallback() {
    return Container(
      color: context.tokens.cardBackground.withValues(alpha: 0.42),
      child: Icon(
        DentalIcons.userDoctor,
        color: context.tokens.primaryAccent,
        size: 32,
      ),
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
                    color: context.tokens.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: '即将到来',
                    value: _upcomingAppointments.toString(),
                    icon: DentalIcons.pending,
                    color: context.tokens.info,
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
                    color: context.tokens.textMuted,
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
              color: context.tokens.textMuted,
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
                color: context.tokens.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.tokens.shadow,
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
                            color: context.tokens.primaryAccent
                                .withValues(alpha: 0.1),
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
                                color: context.tokens.info,
                              ),
                              _buildTodaySummaryChip(
                                label: '已完成',
                                value: dataTodayCompletedAppointments,
                                color: context.tokens.success,
                              ),
                              _buildTodaySummaryChip(
                                label: '未完成',
                                value: dataTodayUnfinishedAppointments,
                                color: context.tokens.warning,
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
                  Divider(height: 1, color: context.tokens.divider),
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
                                        color: context.tokens.pageBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        DentalIcons.calendarCheck,
                                        size: 48,
                                        color: context.tokens.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '今天暂无预约',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '享受轻松的一天吧',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.tokens.textMuted,
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
        DashboardStatusHelper.getStatusColor(context, appointment.status);
    final gender = appointment.patient?.gender ?? '';

    return HoverableListCard(
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
      background: context.tokens.pageBackground,
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      showShadow: false,
      margin: EdgeInsets.zero,
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
                          ? MedicalSemanticColors.femaleGender
                          : MedicalSemanticColors.maleGender,
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
                    color: context.tokens.textMuted,
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
                color: context.tokens.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.tokens.shadow,
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
                            color: context.tokens.secondaryAccent
                                .withValues(alpha: 0.1),
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
                              size: 18, color: context.tokens.textMuted),
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
                  Divider(height: 1, color: context.tokens.divider),
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
                                        color: context.tokens.pageBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        DentalIcons.hospitalUser,
                                        size: 48,
                                        color: context.tokens.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '暂无患者记录',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '开始添加您的第一位患者',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.tokens.textMuted,
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
                                color: context.tokens.divider,
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
    final genderColor = patient.gender == '女'
        ? MedicalSemanticColors.femaleGender
        : MedicalSemanticColors.maleGender;

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

    return HoverableListCard(
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      borderRadius: 8,
      showShadow: false,
      margin: EdgeInsets.zero,
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
                        color: context.tokens.primaryAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${patient.medicalRecordNumber}',
                        style: TextStyle(
                          color: context.tokens.primaryAccent,
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
                      color: context.tokens.success,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        displayPhone,
                        style: TextStyle(
                          color: context.tokens.success,
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
                            color: context.tokens.warning,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                color: context.tokens.warning,
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
                  color: context.tokens.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: context.tokens.textMuted,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomeBannerAmbientPainter extends CustomPainter {
  const _WelcomeBannerAmbientPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.panel,
    required this.border,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final Color panel;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSoftOrbits(canvas, size);
    _paintFloatingDots(canvas, size);
    _paintClinicalGlyphs(canvas, size);
  }

  void _paintSoftOrbits(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = panel.withValues(alpha: 0.34);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = secondary.withValues(alpha: 0.08);

    for (var i = 0; i < 2; i++) {
      final path = Path();
      final baseY = size.height * (0.44 + i * 0.16);
      final amplitude = size.height * (0.08 + i * 0.02);
      path.moveTo(size.width * 0.22, baseY);
      for (var x = size.width * 0.22; x <= size.width * 0.82; x += 18) {
        final normalized = x / size.width;
        final y = baseY +
            math.sin(normalized * math.pi * 3.4 + phase + i) * amplitude;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, pathPaint);
    }
  }

  void _paintFloatingDots(Canvas canvas, Size size) {
    final dotPaint = Paint();
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final points = <Offset>[
      Offset(size.width * 0.39, size.height * 0.37),
      Offset(size.width * 0.51, size.height * 0.62),
      Offset(size.width * 0.63, size.height * 0.31),
      Offset(size.width * 0.73, size.height * 0.55),
    ];

    for (var i = 0; i < points.length; i++) {
      final pulse = (math.sin(progress * math.pi * 2 + i * 1.3) + 1) / 2;
      final drift = math.sin(progress * math.pi * 2 + i) * size.height * 0.018;
      final center = points[i].translate(0, drift);
      final color = i.isEven ? primary : secondary;
      glowPaint.color = color.withValues(alpha: 0.10 + pulse * 0.06);
      dotPaint.color = panel.withValues(alpha: 0.58 + pulse * 0.18);
      canvas.drawCircle(center, 11 + pulse * 5, glowPaint);
      canvas.drawCircle(center, 3.2 + pulse * 1.5, dotPaint);
    }
  }

  void _paintClinicalGlyphs(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    _drawIconBubble(
      canvas,
      size,
      icon: Icons.monitor_heart_outlined,
      center: Offset(
        size.width * 0.58,
        size.height * (0.36 + math.sin(phase) * 0.018),
      ),
      radius: size.height * 0.18,
      color: primary,
    );
    _drawIconBubble(
      canvas,
      size,
      icon: Icons.health_and_safety_outlined,
      center: Offset(
        size.width * 0.70,
        size.height * (0.58 + math.cos(phase * 0.85) * 0.018),
      ),
      radius: size.height * 0.15,
      color: secondary,
    );
  }

  void _drawIconBubble(
    Canvas canvas,
    Size size, {
    required IconData icon,
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final bubblePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = panel.withValues(alpha: 0.24);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = panel.withValues(alpha: 0.07);

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, bubblePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: radius * 0.9,
          color: color.withValues(alpha: 0.18),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _WelcomeBannerAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.panel != panel ||
        oldDelegate.border != border;
  }
}
