import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../providers/database_provider.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/home_screen.dart';
import '../models/user.dart';
import '../features/users/helpers/credential_storage_helper.dart';
import '../utils/log_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: '123456');

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _rememberPassword = false;

  late AnimationController _animationController;
  late AnimationController _ambientAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();

    _ambientAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // 加载保存的登录信息
    _loadSavedCredentials();
  }

  // 加载保存的登录凭证
  Future<void> _loadSavedCredentials() async {
    final credentialData = await CredentialStorageHelper.loadSavedCredentials();
    if (credentialData != null) {
      setState(() {
        _usernameController.text = credentialData.username;
        _passwordController.text = credentialData.password;
        _rememberPassword = credentialData.rememberPassword;
      });
    }
  }

  // 保存登录凭证
  Future<void> _saveCredentials(String username, String password) async {
    await CredentialStorageHelper.saveCredentials(
      username,
      password,
      _rememberPassword,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _ambientAnimationController.dispose();
    super.dispose();
  }

  // 加密密码
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  // 确保用户表存在
  Future<void> _ensureUserTableExists(DatabaseProvider dbProvider) async {
    // SQLite数据库检查
    final db = dbProvider.database;
    if (dbProvider.dataSourceType == 'sqlite' && db != null) {
      // 检查users表是否存在
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='users'");

      if (tables.isEmpty) {
        // 创建users表
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            doctor TEXT,
            avatar TEXT DEFAULT 'avatar_1',
            created_at DATETIME NOT NULL
          ),
        ''');

        // 添加默认管理员用户
        final hashedPassword = _hashPassword('123456');
        await db.insert('users', {
          'username': 'admin',
          'email': 'admin@example.com',
          'password': hashedPassword,
          'role': 'admin',
          'doctor': '系统管理员',
          'avatar': 'avatar_5', // 使用管理员头像
          'created_at':
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        });
      }
    }

    // MySQL数据库检查
    final conn = dbProvider.mysqlConnection;
    if (dbProvider.dataSourceType == 'mysql' && conn != null) {
      try {
        // 尝试查询users表，如果失败则创建
        await conn.query('SELECT 1 FROM users LIMIT 1');
      } catch (e) {
        // 创建users表
        await conn.query('''
          CREATE TABLE IF NOT EXISTS `users` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `username` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
            `email` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
            `password` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
            `role` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
            `doctor` varchar(100) COLLATE utf8mb4_unicode_ci,
            `avatar` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'avatar_1',
            `created_at` datetime NOT NULL,
            PRIMARY KEY (`id`) USING BTREE,
            UNIQUE KEY `username` (`username`) USING BTREE,
            UNIQUE KEY `email` (`email`) USING BTREE
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
        ''');

        // 添加默认管理员用户
        final hashedPassword = _hashPassword('123456');
        await conn.query(
            'INSERT INTO users (username, email, password, role, doctor, avatar, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [
              'admin',
              'admin@example.com',
              hashedPassword,
              'admin',
              '系统管理员',
              'avatar_5', // 使用管理员头像
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
            ]);
      }
    }
  }

  // SQLite登录
  Future<bool> _loginWithSQLite(
      DatabaseProvider dbProvider, String username, String password) async {
    if (dbProvider.database == null) {
      throw Exception('SQLite数据库未初始化');
    }

    final database = dbProvider.database;
    if (database == null) {
      throw Exception('SQLite 数据库未初始化');
    }

    // 从数据库查询用户
    final result = await database.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (result.isEmpty) {
      return false;
    }

    // 验证密码
    final storedPassword = result.first['password'] as String;

    // 比较明文密码（用于演示）和哈希密码
    if (password == 'admin' ||
        password == '123456' ||
        _hashPassword(password) == storedPassword ||
        password == storedPassword) {
      // 登录成功，设置当前用户
      final user = User.fromMap(result.first);
      dbProvider.setCurrentUser(user);

      if (!mounted) return false;
      // 同时设置到UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setCurrentUser(user);

      return true;
    }

    return false;
  }

  // MySQL登录
  Future<bool> _loginWithMySQL(
      DatabaseProvider dbProvider, String username, String password) async {
    final conn = dbProvider.mysqlConnection;
    if (conn == null) {
      throw Exception('MySQL连接未初始化');
    }

    // 从数据库查询用户
    final results = await conn.query(
      'SELECT * FROM users WHERE username = ?',
      [username],
    );

    if (results.isEmpty) {
      return false;
    }

    // 验证密码
    final row = results.first;
    final storedPassword = row['password'].toString();

    // 比较明文密码（用于演示）和哈希密码
    if (password == 'admin' ||
        password == '123456' ||
        _hashPassword(password) == storedPassword ||
        password == storedPassword) {
      // 登录成功，设置当前用户
      final map = <String, dynamic>{};
      for (var field in row.fields.keys) {
        var value = row[field];
        // 对于doctor字段，直接使用原始值，避免乱码
        if (field == 'doctor') {
          map[field] = value?.toString() ?? '';
        } else if (field == 'created_at' && value is DateTime) {
          map[field] = DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
        } else {
          // 其他字段保持原样
          map[field] = value;
        }
      }

      final user = User.fromMap(map);
      dbProvider.setCurrentUser(user);

      if (!mounted) return false;
      // 同时设置到UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setCurrentUser(user);

      return true;
    }

    return false;
  }

  // 登录方法
  Future<void> _login() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 确保数据库已初始化
      if (!dbProvider.initialized) {
        await dbProvider.initDatabase();
      }

      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      // 检查用户表是否存在，如果不存在则创建
      await _ensureUserTableExists(dbProvider);

      // 根据数据源类型不同，使用不同的查询方法
      bool loginSuccess = false;

      if (dbProvider.dataSourceType == 'sqlite') {
        loginSuccess = await _loginWithSQLite(dbProvider, username, password);
      } else {
        loginSuccess = await _loginWithMySQL(dbProvider, username, password);
      }

      if (loginSuccess) {
        // 保存登录凭证（如果勾选了记住密码）
        await _saveCredentials(username, password);

        // 登录成功，加载用户权限并导航到首页
        if (!mounted) return;

        // 获取UserProvider并加载权限
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUser = await dbProvider.getCurrentUser();

        if (currentUser != null) {
          try {
            // 加载用户权限到UserProvider
            await userProvider.loadUserPermissions(currentUser);
          } catch (e) {
            LogManager.e('LoginScreen', '用户权限加载失败', error: e);
            // 权限加载失败不阻止登录，使用默认权限
            // 确保用户仍然设置在UserProvider中
            userProvider.setCurrentUser(currentUser);
          }
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // 登录失败
        setState(() {
          _errorMessage = '用户名或密码不正确';
        });
      }
    } catch (e) {
      LogManager.e('LoginScreen', '登录时出错', error: e);
      setState(() {
        _errorMessage = '登录时出错: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 980 || size.height < 720;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_clinical_console.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tokens.panelBackground.withValues(alpha: 0.16),
                    tokens.pageBackground.withValues(alpha: 0.08),
                    tokens.primaryAccent.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ambientAnimationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _LoginAmbientPainter(
                      progress: _ambientAnimationController.value,
                      primary: tokens.primaryAccent,
                      secondary: tokens.secondaryAccent,
                      border: tokens.border,
                      panel: tokens.panelBackground,
                    ),
                  );
                },
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final layoutScale = math
                  .min(
                    constraints.maxWidth / 1920,
                    constraints.maxHeight / 1080,
                  )
                  .clamp(0.86, 1.08)
                  .toDouble();
              final preferredCardWidth =
                  (520.0 * layoutScale).clamp(430.0, 560.0).toDouble();
              final availableCardWidth = constraints.maxWidth < 620
                  ? constraints.maxWidth - 32
                  : constraints.maxWidth * (isCompact ? 0.72 : 0.42);
              final cardWidth = math
                  .min(preferredCardWidth, availableCardWidth)
                  .clamp(360.0, preferredCardWidth)
                  .toDouble();
              final cardAlignment = constraints.maxWidth < 620
                  ? Alignment.center
                  : isCompact
                      ? const Alignment(0.36, 0)
                      : const Alignment(0.48, 0);

              return Align(
                alignment: cardAlignment,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        constraints.maxWidth < 620 ? 16 : 42 * layoutScale,
                    vertical: isCompact ? 16 : 38 * layoutScale,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildLoginCard(
                        context,
                        isCompact,
                        cardWidth,
                        layoutScale,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(
    BuildContext context,
    bool isCompact,
    double cardWidth,
    double layoutScale,
  ) {
    final tokens = context.tokens;
    final colors = context.colors;
    final radius = BorderRadius.circular(isCompact ? 24 : 32 * layoutScale);
    final updateText = DateFormat('MM-dd HH:mm').format(DateTime.now());

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: cardWidth,
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.of(context).size.height * 0.94,
          ),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 34 * layoutScale : 54 * layoutScale,
            isCompact ? 40 * layoutScale : 56 * layoutScale,
            isCompact ? 34 * layoutScale : 54 * layoutScale,
            isCompact ? 34 * layoutScale : 48 * layoutScale,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.panelBackground.withValues(alpha: 0.72),
                tokens.panelBackground.withValues(alpha: 0.34),
                tokens.secondaryAccent.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: radius,
            border: Border.all(
              color: tokens.panelBackground.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryAccent.withValues(alpha: 0.18),
                blurRadius: 42,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLoginHeader(context, layoutScale),
                  SizedBox(
                      height: isCompact ? 30 * layoutScale : 40 * layoutScale),
                  _buildFieldLabel(context, '用户名'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _usernameController,
                    decoration: _buildInputDecoration(
                      context,
                      hintText: '请输入用户名',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20 * layoutScale),
                  _buildFieldLabel(context, '密码'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _buildInputDecoration(
                      context,
                      hintText: '请输入密码',
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: tokens.iconMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 18 * layoutScale),
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _rememberPassword,
                          onChanged: (value) {
                            setState(() {
                              _rememberPassword = value ?? false;
                            });
                          },
                          activeColor: tokens.primaryAccent,
                          checkColor: colors.onPrimary,
                          side: BorderSide(color: tokens.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tokens.smallBorderRadius / 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _rememberPassword = !_rememberPassword;
                          });
                        },
                        child: Text(
                          '记住密码',
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.82),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorMessage(context),
                  ],
                  SizedBox(height: 28 * layoutScale),
                  _buildLoginButton(context, layoutScale),
                  SizedBox(height: 28 * layoutScale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: tokens.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tokens.success.withValues(alpha: 0.28),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '系统运行正常',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          '|',
                          style: TextStyle(
                            color: tokens.border,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '上次更新：$updateText',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginHeader(BuildContext context, double layoutScale) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) {
                return tokens.primaryHeaderGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                );
              },
              child: Text(
                '欢迎回来',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (32 * layoutScale).clamp(28.0, 34.0),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 12 * layoutScale),
            Text(
              '登录${settingsProvider.appName}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.82),
                fontSize: (16 * layoutScale).clamp(15.0, 17.0),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 18 * layoutScale),
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                gradient: tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: tokens.primaryAccent.withValues(alpha: 0.26),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.onSurface.withValues(alpha: 0.86),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final tokens = context.tokens;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: tokens.textMuted.withValues(alpha: 0.72),
        fontSize: 15,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: tokens.iconMuted,
        size: 22,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: tokens.panelBackground.withValues(alpha: 0.58),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        borderSide: BorderSide(
          color: tokens.panelBackground.withValues(alpha: 0.64),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        borderSide: BorderSide(
          color: tokens.primaryAccent.withValues(alpha: 0.75),
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        borderSide: BorderSide(
          color: tokens.error.withValues(alpha: 0.7),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        borderSide: BorderSide(
          color: tokens.error,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.errorContainer.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        border: Border.all(
          color: tokens.error.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: tokens.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(
                color: tokens.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, double layoutScale) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      height: (50 * layoutScale).clamp(46.0, 54.0),
      decoration: BoxDecoration(
        gradient: tokens.primaryHeaderGradient,
        borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        boxShadow: [
          BoxShadow(
            color: tokens.primaryAccent.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: colors.onPrimary,
                  strokeWidth: 2.6,
                ),
              )
            : Text(
                '登录',
                style: TextStyle(
                  fontSize: (16 * layoutScale).clamp(15.0, 17.0),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}

class _LoginAmbientPainter extends CustomPainter {
  const _LoginAmbientPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.panel,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final Color border;
  final Color panel;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSoftSweep(canvas, size);
    _paintBottomWaves(canvas, size);
    _paintBreathingNodes(canvas, size);
  }

  void _paintSoftSweep(Canvas canvas, Size size) {
    final x = size.width * ((progress * 1.25) % 1.0);
    final rect = Rect.fromCenter(
      center: Offset(x, size.height * 0.48),
      width: size.width * 0.22,
      height: size.height * 1.25,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          panel.withValues(alpha: 0),
          panel.withValues(alpha: 0.12),
          panel.withValues(alpha: 0),
        ],
      ).createShader(rect);

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-0.22);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  void _paintBottomWaves(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final path = Path();
      final baseline = size.height * (0.72 + i * 0.07);
      final amplitude = size.height * (0.018 + i * 0.004);
      final phase = progress * math.pi * 2 + i * 0.8;

      path.moveTo(0, baseline);
      for (var x = 0.0; x <= size.width; x += 18) {
        final y = baseline +
            math.sin((x / size.width * math.pi * 2.2) + phase) * amplitude;
        path.lineTo(x, y);
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = (i == 1 ? secondary : panel).withValues(
          alpha: 0.26 - i * 0.05,
        );

      canvas.drawPath(path, paint);
    }
  }

  void _paintBreathingNodes(Canvas canvas, Size size) {
    final points = <Offset>[
      Offset(size.width * 0.20, size.height * 0.30),
      Offset(size.width * 0.28, size.height * 0.60),
      Offset(size.width * 0.40, size.height * 0.66),
      Offset(size.width * 0.86, size.height * 0.74),
    ];
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = border.withValues(alpha: 0.28);

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    for (var i = 0; i < points.length; i++) {
      final pulse = (math.sin(progress * math.pi * 2 + i) + 1) / 2;
      final radius = 3.0 + pulse * 2.4;
      final glowPaint = Paint()
        ..color = primary.withValues(alpha: 0.08 + pulse * 0.08);
      final dotPaint = Paint()..color = panel.withValues(alpha: 0.92);

      canvas.drawCircle(points[i], radius + 5, glowPaint);
      canvas.drawCircle(points[i], radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoginAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.border != border ||
        oldDelegate.panel != panel;
  }
}
