import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/user_provider.dart';
import '../providers/app_state.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';

import '../widgets/dental_icons.dart';
import '../utils/message_toast_helper.dart';
import '../widgets/loading_dialog.dart';
import '../utils/notification_helper.dart';

import 'package:dentist_app/screens/settings_screen.dart';
import '../models/database_config.dart';

/// 登录界面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isInitializing = true; // 添加初始化状态标志
  bool _rememberPassword = false; // 记住密码选项

  @override
  void initState() {
    super.initState();
    
    // 加载保存的登录信息
    _loadSavedCredentials();
    
    // 监听数据库切换
    _setupDatabaseSwitchListener();
    
    // 等待数据库初始化完成
    _waitForInitialization();
  }
  
  /// 加载保存的登录信息
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('saved_username');
      final savedPassword = prefs.getString('saved_password');
      final rememberPassword = prefs.getBool('remember_password') ?? false;
      
      if (rememberPassword && savedUsername != null && savedPassword != null) {
        setState(() {
          _usernameController.text = savedUsername;
          _passwordController.text = savedPassword;
          _rememberPassword = true;
        });
      } else {
        // 设置默认的用户名和密码
        _usernameController.text = 'admin';
        _passwordController.text = '123456';
      }
    } catch (e) {
      print('加载保存的登录信息失败: $e');
      // 设置默认的用户名和密码
      _usernameController.text = 'admin';
      _passwordController.text = '123456';
    }
  }
  
  /// 保存登录信息
  Future<void> _saveCredentials(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberPassword) {
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_password', true);
      } else {
        await prefs.remove('saved_username');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_password', false);
      }
    } catch (e) {
      print('保存登录信息失败: $e');
    }
  }
  
  // 等待数据库和用户表初始化完成
  Future<void> _waitForInitialization() async {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      print('🔄 等待数据库初始化...');
      
      // 第一步：等待数据库初始化（最多等待10秒）
      int retryCount = 0;
      while (!dbProvider.isInitialized && retryCount < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }
      
      if (!dbProvider.isInitialized) {
        print('❌ 数据库初始化超时');
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
          MessageToastHelper.showError(context, '数据库初始化超时，请重启应用');
        }
        return;
      }
      
      print('✅ 数据库初始化完成 (${dbProvider.dbType})');
      
      // 如果是自动切换到SQLite，显示提示
      if (dbProvider.isAutoSwitchedToSQLite) {
        print('⚠️ MySQL连接失败，已自动切换到SQLite');
      }
      
      print('🔄 等待 UserProvider 初始化...');
      
      // 第二步：等待 UserProvider 初始化
      if (!userProvider.initialized) {
        try {
          await userProvider.initializeFromDatabase(dbProvider);
        } catch (e) {
          print('❌ UserProvider 初始化失败: $e');
          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
            MessageToastHelper.showError(context, 'UserProvider初始化失败: ${e.toString()}');
          }
          return;
        }
      }
      
      // 等待 UserProvider 完全初始化（最多等待2秒）
      retryCount = 0;
      while (!userProvider.initialized && retryCount < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }
      
      if (!userProvider.initialized) {
        print('❌ UserProvider 初始化超时');
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
          MessageToastHelper.showError(context, 'UserProvider初始化超时，请重启应用');
        }
        return;
      }
      
      print('✅ UserProvider 初始化完成');
      print('✅ 系统初始化完成，可以登录');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      print('❌ 等待初始化失败: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        MessageToastHelper.showError(context, '初始化失败: ${e.toString()}');
      }
    }
  }

  // 设置数据库切换监听器
  void _setupDatabaseSwitchListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 使用单次监听器，确保只触发一次
      void listener() {
        if (mounted && dbProvider.databaseChanged && dbProvider.dbType == 'sqlite') {
          // 立即移除监听器，防止重复触发
          dbProvider.removeListener(listener);
          
          // 延迟显示提示，确保UI已完全加载
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              NotificationHelper.showDatabaseSwitchDialog(
                context,
                fromType: 'MySQL',
                toType: 'SQLite',
                reason: '无法连接到MySQL服务器',
              );
              
              // 重置标志
              dbProvider.resetDatabaseChanged();
            }
          });
        }
      }
      
      // 添加一次性监听器
      dbProvider.addListener(listener);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
    // 添加安全区域检查
    if (!mounted) return const SizedBox.shrink();
    
    return Scaffold(
      resizeToAvoidBottomInset: true, // 允许键盘弹出时调整布局
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 根据屏幕高度调整间距和内容大小
          final screenHeight = constraints.maxHeight;
          final isSmallScreen = screenHeight < 600;
          final verticalSpacing = isSmallScreen ? 20.0 : 40.0;
          final logoSize = isSmallScreen ? 80.0 : 100.0;
          final fontSize = isSmallScreen ? 24.0 : 28.0;
          
          return Stack(
            children: [
              // 背景图片层
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage('assets/images/login.jpg'),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.15),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                ),
              ),
              // 内容层 - 使用可滚动但智能适配的布局
              SafeArea(
                child: SingleChildScrollView(
                  physics: screenHeight > 700 
                      ? const NeverScrollableScrollPhysics() // 大屏幕禁止滚动
                      : const ClampingScrollPhysics(), // 小屏幕允许必要滚动
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo和标题 - 根据屏幕大小调整
                          _buildAdaptiveHeader(logoSize: logoSize, fontSize: fontSize),
                          
                          SizedBox(height: verticalSpacing),
                          
                          // 登录表单 - 根据屏幕大小调整
                          _buildAdaptiveLoginForm(isSmallScreen: isSmallScreen),
                          
                          SizedBox(height: verticalSpacing * 0.6),
                          
                          // 底部装饰元素 - 根据屏幕大小调整
                          _buildAdaptiveBottomDecorations(isSmallScreen: isSmallScreen),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建自适应头部
  Widget _buildAdaptiveHeader({required double logoSize, required double fontSize}) {
    return Column(
      children: [
        // 应用图标 - 使用牙齿图标
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.7),
                    Colors.blue.shade50.withOpacity(0.5),
                    Colors.indigo.shade50.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 背景装饰圆圈
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                      child: Container(
                        width: logoSize * 0.8,
                        height: logoSize * 0.8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade100.withOpacity(0.15),
                              Colors.indigo.shade100.withOpacity(0.08),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  // 牙齿图标
                  Icon(
                    FontAwesomeIcons.tooth,
                    size: logoSize * 0.48,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 应用名称
        Text(
          '牙科诊所管理系统',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.4),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 副标题
        Text(
          'Dental Clinic Management System',
          style: TextStyle(
            fontSize: fontSize * 0.57,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 装饰性分隔线
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: Container(
              width: logoSize * 0.6,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.blue.shade200.withOpacity(0.5),
                    Colors.indigo.shade200.withOpacity(0.5),
                    Colors.white.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // 装饰性图标
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDecorIcon(FontAwesomeIcons.tooth, Colors.blue.shade300),
            const SizedBox(width: 12),
            _buildDecorIcon(FontAwesomeIcons.teeth, Colors.indigo.shade300),
            const SizedBox(width: 12),
            _buildDecorIcon(FontAwesomeIcons.heartbeat, Colors.purple.shade300),
          ],
        ),
      ],
    );
  }


    /// 构建装饰性图标
  Widget _buildDecorIcon(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

    /// 构建登录表单
  Widget _buildAdaptiveLoginForm({required bool isSmallScreen}) {
    final formPadding = isSmallScreen ? 16.0 : 24.0;
    final fieldSpacing = isSmallScreen ? 12.0 : 16.0;
    final buttonHeight = isSmallScreen ? 45.0 : 50.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(formPadding),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题区域
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade50.withOpacity(0.6),
                            Colors.indigo.shade50.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.login_rounded,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '用户登录',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '请输入您的用户名和密码',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: fieldSpacing * 1.75),

                _buildUsernameField(),
                SizedBox(height: fieldSpacing),
                _buildPasswordField(),
                SizedBox(height: fieldSpacing * 0.8),
                _buildRememberPasswordCheckbox(),
                SizedBox(height: fieldSpacing * 1.2),
                _buildLoginButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建用户名字段（自适应版本）
  Widget _buildUsernameField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 350;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: Colors.blue.shade600,
                  size: isSmallScreen ? 16 : 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '用户名',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _usernameController,
                style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                decoration: InputDecoration(
                  hintText: '请输入用户名',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isSmallScreen ? 12 : 13,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.blue.shade600,
                      size: isSmallScreen ? 18 : 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade300,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade300,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade600,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.blue.shade50.withOpacity(0.25),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 12 : 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建密码字段（自适应版本）
  Widget _buildPasswordField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 350;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.blue.shade600,
                  size: isSmallScreen ? 16 : 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '密码',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                decoration: InputDecoration(
                  hintText: '请输入密码',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isSmallScreen ? 12 : 13,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.blue.shade600,
                      size: isSmallScreen ? 18 : 20,
                    ),
                  ),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: Colors.blue.shade500,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade200,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade200,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade500,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.blue.shade50.withOpacity(0.4),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 12 : 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建记住密码复选框
  Widget _buildRememberPasswordCheckbox() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _rememberPassword,
            onChanged: (value) {
              setState(() {
                _rememberPassword = value ?? false;
              });
            },
            activeColor: Colors.blue.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _rememberPassword = !_rememberPassword;
            });
          },
          child: Text(
            '记住密码',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建登录按钮（自适应版本）
  Widget _buildLoginButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 350;
        return Container(
          width: double.infinity,
          height: isSmallScreen ? 48 : 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: _isInitializing
                  ? [
                      Colors.grey.shade400,
                      Colors.grey.shade500,
                      Colors.grey.shade600,
                    ]
                  : [
                      Colors.blue.shade600,
                      Colors.blue.shade500,
                      Colors.indigo.shade400,
                    ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _isInitializing
                    ? Colors.grey.shade400.withOpacity(0.3)
                    : Colors.blue.shade400.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isInitializing ? null : _handleLogin,
              child: Container(
                alignment: Alignment.center,
                child: _isInitializing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '初始化中...',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 20 : 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '登录',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
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
  }

  /// 构建底部装饰元素
  Widget _buildAdaptiveBottomDecorations({required bool isSmallScreen}) {
    final textSize = isSmallScreen ? 12.0 : 14.0;
    final spacing = isSmallScreen ? 4.0 : 8.0;
    
    return Column(
      children: [
        SizedBox(height: spacing * 2.5),
        Text(
          '技术支持: 牙医诊所管理系统',
          style: TextStyle(
            fontSize: textSize,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: spacing),
        Container(
          width: isSmallScreen ? 40 : 50,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  /// 处理登录
  Future<void> _handleLogin() async {
    // 如果还在初始化，不允许登录
    if (_isInitializing) {
      MessageToastHelper.showWarning(context, '系统正在初始化，请稍候...');
      return;
    }
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      MessageToastHelper.showError(context, '请输入用户名和密码');
      return;
    }

    // 显示加载提示
    LoadingDialog.show(context, message: '正在登录...');

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 再次确认数据库已初始化
      if (!dbProvider.isInitialized) {
        if (mounted) LoadingDialog.hide(context);
        MessageToastHelper.showError(context, '数据库未初始化，请重启应用');
        return;
      }
      
      // 验证用户登录（authenticateUser 内部会处理 UserProvider 的初始化）
      final user = await userProvider.authenticateUser(username, password);
      
      // 隐藏加载提示
      if (mounted) LoadingDialog.hide(context);
      
      if (user != null) {
        // 保存登录信息
        await _saveCredentials(username, password);
        
        // 登录成功，更新应用状态
        appState.setCurrentUser(user);
        appState.setLoggedIn(true);
        
        if (mounted) {
          MessageToastHelper.showSuccess(context, '登录成功！欢迎回来，${user.username}');
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // 登录失败
        if (mounted) {
          MessageToastHelper.showError(context, '用户名或密码错误');
        }
      }
    } catch (e) {
      // 隐藏加载提示
      if (mounted) LoadingDialog.hide(context);
      
      if (mounted) {
        // 检查是否是数据库连接错误
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('连接') || 
            errorMessage.contains('connection') || 
            errorMessage.contains('socketexception') ||
            errorMessage.contains('无法连接') ||
            errorMessage.contains('timeout')) {
          _showDatabaseErrorDialog();
        } else {
          MessageToastHelper.showError(context, '登录失败: ${e.toString()}');
        }
      }
    }
  }

  /// 显示数据库连接错误对话框
  void _showDatabaseErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('数据库连接失败'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('无法连接到MySQL数据库，可能的原因：'),
              SizedBox(height: 8),
              Text('• 网络连接不稳定'),
              Text('• MySQL服务器未启动'),
              Text('• 数据库配置错误'),
              SizedBox(height: 12),
              Text('您可以选择：'),
              Text('• 重试MySQL连接'),
              Text('• 切换到SQLite本地数据库'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _retryMySQLConnection();
              },
              child: const Text('重试MySQL'),
            ),
            ElevatedButton(
              onPressed: () => _switchToSQLite(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text('切换到SQLite'),
            ),
          ],
        );
      },
    );
  }

  /// 重试MySQL连接
  Future<void> _retryMySQLConnection() async {
    LoadingDialog.show(context, message: '正在重试MySQL连接...');
    
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // 重新初始化数据库
      await dbProvider.initDatabase();
      
      if (mounted) {
        LoadingDialog.hide(context);
        
        // 检查是否成功连接
        if (dbProvider.isConnected) {
          MessageToastHelper.showSuccess(context, 'MySQL连接成功！');
        } else {
          MessageToastHelper.showWarning(context, 'MySQL连接失败，请检查配置');
        }
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.hide(context);
        MessageToastHelper.showError(context, '重试MySQL连接失败: ${e.toString()}');
      }
    }
  }

  /// 切换到SQLite数据库
  Future<void> _switchToSQLite() async {
    LoadingDialog.show(context, message: '正在切换到SQLite...');
    
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 更新数据库配置为SQLite
      final dbConfig = await DatabaseConfig.loadConfig();
      dbConfig.dbType = 'sqlite';
      await dbConfig.saveConfig();
      
      // 重新初始化数据库
      await dbProvider.initDatabase();
      
      // 重新初始化UserProvider
      await userProvider.initializeFromDatabase(dbProvider);
      
      if (mounted) {
        LoadingDialog.hide(context);
        MessageToastHelper.showSuccess(context, '已成功切换到SQLite数据库');
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.hide(context);
        MessageToastHelper.showError(context, '切换到SQLite失败: ${e.toString()}');
      }
    }
  }
}