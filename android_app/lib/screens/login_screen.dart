import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/message_toast_helper.dart';
import '../features/users/widgets/login_header.dart';
import '../features/users/widgets/login_form.dart';
import '../features/users/widgets/login_bottom_decorations.dart';
import '../features/users/widgets/database_error_dialog.dart';
import '../features/users/services/login_credentials_service.dart';
import '../features/users/services/login_database_switch_service.dart';
import '../features/users/services/login_initialization_service.dart';
import '../features/users/services/login_handler.dart';
import '../features/users/services/database_connection_service.dart';

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
  bool _isInitializing = true;
  bool _rememberPassword = false;

  @override
  void initState() {
    super.initState();

    // 加载保存的登录信息
    _loadSavedCredentials();

    // 监听数据库切换
    LoginDatabaseSwitchService.setupDatabaseSwitchListener(context);

    // 等待数据库初始化完成
    _waitForInitialization();
  }
  
  /// 加载保存的登录信息
  Future<void> _loadSavedCredentials() async {
    final credentials = await LoginCredentialsService.loadSavedCredentials();
    setState(() {
      _usernameController.text = credentials.username;
      _passwordController.text = credentials.password;
      _rememberPassword = credentials.rememberPassword;
    });
  }
  
  // 等待数据库和用户表初始化完成
  Future<void> _waitForInitialization() async {
    await LoginInitializationService.waitForInitialization(
      context,
      (initialized) {
        if (mounted) {
          setState(() {
            _isInitializing = !initialized;
          });
        }
      },
    );
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
                          LoginHeader(
                            logoSize: logoSize,
                            fontSize: fontSize,
                          ),
                          
                          SizedBox(height: verticalSpacing),
                          
                          // 登录表单 - 根据屏幕大小调整
                          LoginForm(
                            formKey: _formKey,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            rememberPassword: _rememberPassword,
                            isInitializing: _isInitializing,
                            isSmallScreen: isSmallScreen,
                            onObscurePasswordChanged: (value) {
                              setState(() {
                                _obscurePassword = value;
                              });
                            },
                            onRememberPasswordChanged: (value) {
                              setState(() {
                                _rememberPassword = value;
                              });
                            },
                            onLogin: _handleLogin,
                          ),
                          
                          SizedBox(height: verticalSpacing * 0.6),
                          
                          // 底部装饰元素 - 根据屏幕大小调整
                          LoginBottomDecorations(
                            isSmallScreen: isSmallScreen,
                          ),
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

  /// 处理登录
  Future<void> _handleLogin() async {
    // 如果还在初始化，不允许登录
    if (_isInitializing) {
      MessageToastHelper.showWarning(context, '系统正在初始化，请稍候...');
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await LoginHandler.handleLogin(
        context,
        username,
        password,
        _rememberPassword,
      );
    } on LoginDatabaseException {
      // 数据库连接错误，显示对话框
      if (mounted) {
        DatabaseErrorDialog.show(
          context,
          onRetryMySQL: _retryMySQLConnection,
          onSwitchToSQLite: _switchToSQLite,
        );
      }
    }
  }

  /// 重试MySQL连接
  Future<void> _retryMySQLConnection() async {
    await DatabaseConnectionService.retryMySQLConnection(context);
  }

  /// 切换到SQLite数据库
  Future<void> _switchToSQLite() async {
    await DatabaseConnectionService.switchToSQLite(context);
  }
}
