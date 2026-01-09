import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../providers/appointments_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/user_provider.dart';
import '../models/database_models.dart';
import '../main.dart';
import 'appointment_detail_screen.dart';
import 'patients_screen.dart';
import 'appointments_screen.dart';
import 'home_screen.dart';
import 'dart:convert';
import '../utils/permission_utils.dart';
import '../widgets/success_toast.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
};

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
  Uint8List? _currentUserAvatar;
  String _currentUserName = '';
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

    // 延迟加载数据，确保Provider完全初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('DashboardScreen 初始化完成，开始加载数据');
      _loadDataWithRetry();
    });
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
        print('数据加载成功，无需重试');
        break; // 成功后直接跳出循环
      } catch (e) {
        retryCount++;
        print('加载数据失败 (尝试 $retryCount/$maxRetries): $e');

        if (retryCount < maxRetries) {
          // 增加延迟时间，以便后续尝试更可能成功
          await Future.delayed(Duration(seconds: 1 * retryCount));
        }
      }
    }

    // 只有在真正失败且不是"数据库未初始化"错误时才显示错误信息
    if (!success && mounted) {
      print('多次重试后数据加载仍然失败');
      setState(() {
        _isLoading = false;
      });

      // 暂时注释掉错误显示，看看问题是否解决
      // 检查是否是"数据库未初始化"错误，如果是则不显示错误信息
      // 因为从日志看数据库实际上是初始化成功的
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: const Text('数据加载遇到问题，请稍后重试'),
      //       backgroundColor: AppTheme.errorColor,
      //       duration: const Duration(seconds: 5),
      //       action: SnackBarAction(
      //         label: '刷新',
      //         onPressed: _loadDataWithRetry,
      //         textColor: Colors.white,
      //       ),
      //     ),
      //   );
      // }
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

      // 确保所有Provider都初始化完成
      await _initializeAllProviders();

      // 获取UserProvider和当前用户信息
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      // 获取用户头像和医生姓名
      if (currentUser?.imageData != null && currentUser!.imageData!.isNotEmpty) {
        _currentUserAvatar = Uint8List.fromList(currentUser.imageData!);
      } else {
        _currentUserAvatar = null;
      }
      
      // 获取医生姓名，优先使用 doctor 字段，否则使用 username
      _currentUserName = currentUser?.doctor?.isNotEmpty == true 
          ? currentUser!.doctor! 
          : (currentUser?.username ?? '');

      // 使用try-catch包装每个数据库操作，防止单个操作失败影响整体
      int patientCount = 0;
      try {
        print('正在获取患者数量...');
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        // 不再重复初始化，_initializeAllProviders 已经初始化过了
        
        // Android端：直接获取所有患者数量，不过滤
        patientCount = await patientProvider.getPatientCount();
        print('成功获取患者数量: $patientCount，数据库类型: ${dbProvider.dbType}');
      } catch (e) {
        print('获取患者数量错误: $e');
      }

      int appointmentCount = 0;
      List<Appointment> todayAppointments = [];
      int completed = 0;
      int upcoming = 0;
      
      try {
        print('正在获取预约数量...');
        final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
        // 不再重复初始化，_initializeAllProviders 已经初始化过了
        
        // Android端：直接获取所有预约数量，不过滤
        appointmentCount = await appointmentsProvider.getAppointmentCount();
        print('成功获取预约数量: $appointmentCount，数据库类型: ${dbProvider.dbType}');
      } catch (e) {
        print('获取预约数量错误: $e');
      }

      try {
        print('正在获取今日预约...');
        final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
        
        // Android端：直接获取所有今日预约，不过滤
        todayAppointments = await appointmentsProvider.getTodayAppointments();
        print('成功获取今日预约: ${todayAppointments.length}');
      } catch (e) {
        print('获取今日预约错误: $e');
      }

      // 计算已完成和即将到来的预约数
      try {
        print('正在获取所有预约...');
        final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
        
        // Android端：直接获取所有预约，不过滤
        final allAppointments = await appointmentsProvider.getAllAppointments();
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

      // 过滤掉"数据库未初始化"的错误，因为从日志看数据库实际上是初始化成功的
      if (mounted) {
        // 检查是否是"数据库未初始化"错误，如果是则不显示错误信息
        if (!e.toString().contains('数据库未初始化')) {
          String errorMessage = '数据加载遇到问题，请稍后重试';
          
          // 如果不是"数据库未初始化"错误，显示具体错误信息
          if (!e.toString().contains('数据库未初始化')) {
            errorMessage = '加载数据出错，请尝试刷新: $e';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '刷新',
                onPressed: _loadDataWithRetry,
                textColor: Colors.white,
              ),
            ),
          );
        } else {
          print('检测到"数据库未初始化"错误，但不显示给用户，因为数据库实际已初始化');
        }
      }
    }
  }

  // 确保所有Provider都初始化完成
  Future<void> _initializeAllProviders() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    try {
      print('开始初始化所有Provider...');
      
      // 初始化PatientProvider
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      if (!patientProvider.initialized) {
        await patientProvider.initializeFromDatabase(dbProvider);
        print('PatientProvider初始化完成');
      }
      
      // 初始化AppointmentsProvider
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (!appointmentsProvider.initialized) {
        await appointmentsProvider.initializeFromDatabase(dbProvider, userProvider: userProvider);
        print('AppointmentsProvider初始化完成');
      }
      
      print('所有Provider初始化完成');
    } catch (e) {
      print('初始化Provider时出错: $e');
    }
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
                onRefresh: () async {
                  await _loadData();
                  if (mounted) {
                    SuccessToastManager.show(
                      context,
                      message: '刷新成功',
                    );
                  }
                },
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDashboardHeader(),
                      const SizedBox(height: 20),
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

  Widget _buildDashboardHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                '牙科诊所管理系统',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
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
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = '早上好';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour < 18) {
      greeting = '下午好';
      greetingIcon = Icons.wb_sunny_outlined;
    } else {
      greeting = '晚上好';
      greetingIcon = Icons.nightlight_round;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1A73E8),
              Color(0xFF4285F4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            greetingIcon,
                            color: Colors.white.withOpacity(0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$greeting${_currentUserName.isNotEmpty ? '，$_currentUserName' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MM月dd日 EEEE', 'zh_CN').format(now),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
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
                          child: Image.memory(
                            _currentUserAvatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatarIcon();
                            },
                          ),
                        )
                      : _buildDefaultAvatarIcon(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: Color(0xFF1A73E8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日预约',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_todayAppointments.length} 个',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_appointmentCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${((_todayAppointments.length / _appointmentCount) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFF1A73E8),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
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
                  onTap: () async {
                    // 检查患者管理权限
                    final hasPermission = await PermissionUtils.canEdit(context, 'patients');
                    if (hasPermission) {
                      // 导航到患者列表页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PatientsScreen(),
                        ),
                      );
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问患者管理',
                      );
                    }
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
                  onTap: () async {
                    // 检查预约管理权限
                    final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                    if (hasPermission) {
                      // 导航到预约管理页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppointmentsScreen(),
                        ),
                      );
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问预约管理',
                      );
                    }
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
                  onTap: () async {
                    // 检查预约管理权限
                    final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                    if (hasPermission) {
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
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问预约管理',
                      );
                    }
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
                  onTap: () async {
                    // 检查预约管理权限
                    final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                    if (hasPermission) {
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
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问预约管理',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatarIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 28,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.secondaryText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
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
              const Text(
                '今日预约',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                  if (hasPermission) {
                    // 返回到HomeScreen并导航到预约页面（索引2）
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(initialIndex: 2),
                      ),
                    );
                  } else {
                    PermissionUtils.showPermissionDeniedMessage(
                      context,
                      customMessage: '您没有权限访问预约管理',
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Row(
                  children: const [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _todayAppointments.isEmpty
              ? Container(
                constraints: const BoxConstraints(minHeight: 180),
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_available_rounded,
                        color: AppTheme.primaryColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '今日暂无预约',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children:
                    _todayAppointments.map((appointment) {
                      return FutureBuilder<Patient?>(
                        future: Provider.of<PatientProvider>(
                          context,
                          listen: false,
                        ).getPatientById(appointment.patientId),
                        builder: (context, snapshot) {
                          final patient = snapshot.data;
                          final statusInfo = _getStatusInfo(appointment.status);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: statusInfo.color.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
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
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  statusInfo.color.withOpacity(0.2),
                                                  statusInfo.color.withOpacity(0.1),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                patient?.name.isNotEmpty == true
                                                    ? patient!.name.substring(0, 1)
                                                    : '?',
                                                style: TextStyle(
                                                  color: statusInfo.color,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                                                    color: AppTheme.primaryText,
                                                  ),
                                                ),
                                                if (patient?.medicalRecordNumber != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '病历号: ${patient!.medicalRecordNumber}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme.secondaryText,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          _buildStatusChip(appointment.status),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.backgroundColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            _buildInfoItem(
                                              icon: Icons.access_time_rounded,
                                              text: DateFormat('HH:mm').format(
                                                appointment.appointmentDate,
                                              ),
                                              color: AppTheme.infoColor,
                                              expanded: true,
                                            ),
                                            if (patient?.phone != null &&
                                                patient!.phone.isNotEmpty) ...[
                                              const SizedBox(width: 16),
                                              _buildInfoItem(
                                                icon: Icons.phone_rounded,
                                                text: _getDisplayPhone(
                                                  patient.phone,
                                                ),
                                                color: AppTheme.successColor,
                                                expanded: true,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (appointment.treatmentType != null) ...[
                                        const SizedBox(height: 12),
                                        _buildInfoItem(
                                          icon: Icons.medical_services_rounded,
                                          text: _formatTreatmentType(appointment.treatmentType),
                                          color: AppTheme.primaryColor,
                                        ),
                                      ],
                                      if (appointment.notes != null &&
                                          appointment.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _buildInfoItem(
                                          icon: Icons.notes_rounded,
                                          text: appointment.notes!,
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
    bool expanded = false,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    
    return expanded ? Expanded(child: content) : content;
  }

  Widget _buildStatusChip(String status) {
    final statusInfo = _getStatusInfo(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusInfo.color.withOpacity(0.15),
            statusInfo.color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusInfo.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        statusInfo.text,
        style: TextStyle(
          color: statusInfo.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
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
      case '已预约':
        return StatusInfo(color: AppTheme.infoColor, text: '已预约');
      case 'completed':
      case '已完成':
        return StatusInfo(color: AppTheme.successColor, text: '已完成');
      case 'cancelled':
      case '已取消':
        return StatusInfo(color: AppTheme.errorColor, text: '已取消');
      case 'in_progress':
        return StatusInfo(color: AppTheme.warningColor, text: '进行中');
      case 'missed':
      case 'no_show':
      case '未到诊':
        return StatusInfo(color: Colors.orange, text: '未到诊');
      default:
        // 不再显示"未知"，而是显示原始状态
        return StatusInfo(color: AppTheme.secondaryText, text: status);
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
}

class StatusInfo {
  final Color color;
  final String text;

  StatusInfo({required this.color, required this.text});
}
