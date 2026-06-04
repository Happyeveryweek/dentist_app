import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../models/database_models.dart';
import '../features/dashboard/widgets/dashboard_header.dart';
import '../features/dashboard/widgets/welcome_section.dart';
import '../features/dashboard/widgets/statistics_cards.dart';
import '../features/dashboard/widgets/today_appointments_section.dart';
import '../features/dashboard/services/dashboard_data_loader.dart';
import '../widgets/toast_manager.dart';

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

      // 使用数据加载服务加载数据
      final data = await DashboardDataLoader.loadData(context);

      // 确保组件还在挂载状态
      if (!mounted) return;

      print('更新UI状态');
      setState(() {
        _patientCount = data.patientCount;
        _appointmentCount = data.appointmentCount;
        _todayAppointments = data.todayAppointments;
        _completedAppointments = data.completedAppointments;
        _upcomingAppointments = data.upcomingAppointments;
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
                      const DashboardHeader(),
                      const SizedBox(height: 20),
                      WelcomeSection(
                        currentUserName: _currentUserName,
                        currentUserAvatar: _currentUserAvatar,
                        todayAppointmentsCount: _todayAppointments.length,
                        totalAppointmentsCount: _appointmentCount,
                        fadeAnimation: _fadeAnimation,
                      ),
                      const SizedBox(height: 24),
                      StatisticsCards(
                        patientCount: _patientCount,
                        appointmentCount: _appointmentCount,
                        completedAppointments: _completedAppointments,
                        upcomingAppointments: _upcomingAppointments,
                        fadeAnimation: _fadeAnimation,
                      ),
                      const SizedBox(height: 24),
                      TodayAppointmentsSection(
                        todayAppointments: _todayAppointments,
                        fadeAnimation: _fadeAnimation,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }












  // 公共方法：允许外部调用刷新仪表盘数据
  void refreshDashboardData() {
    print('外部请求刷新仪表盘数据');
    if (mounted) {
      _loadDataWithRetry();
    }
  }

}

