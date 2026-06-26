import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
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
          )
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
    final isSmallScreen = size.height < 700;

    return Scaffold(
      body: Stack(
        children: [
          // AI设计的背景图片
          Positioned.fill(
            child: Image.asset(
              'assets/images/home.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              isAntiAlias: false,
              repeat: ImageRepeat.noRepeat,
            ),
          ),

          // 主要登录内容
          Center(
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 32.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                      child: Container(
                        width: size.width > 600 ? 500 : size.width * 0.9,
                        constraints: BoxConstraints(
                          maxHeight: size.height * 0.95,
                        ),
                        padding: EdgeInsets.all(isSmallScreen ? 20.0 : 32.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 现代医疗风格Logo
                              Container(
                                width: 120,
                                height: 120,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF2196F3)
                                          .withValues(alpha: 0.15),
                                      const Color(0xFF03DAC6)
                                          .withValues(alpha: 0.1),
                                      const Color(0xFF00BCD4)
                                          .withValues(alpha: 0.05),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF2196F3)
                                        .withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2196F3)
                                          .withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // 主医疗图标
                                    const Center(
                                      child: Icon(
                                        Icons.medical_services_rounded,
                                        size: 50,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                    // 装饰性十字符号
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF03DAC6),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    // 装饰性心跳线
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      child: Icon(
                                        Icons.favorite,
                                        size: 12,
                                        color: const Color(0xFFE91E63)
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Consumer<SettingsProvider>(
                                builder: (context, settingsProvider, child) {
                                  return Text(
                                    settingsProvider.appName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryText,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '请登录以继续使用',
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // 登录表单
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 用户名
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        labelText: '用户名',
                                        hintText: '请输入用户名',
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2196F3)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FCFF),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: const Color(0xFF2196F3)
                                                .withValues(alpha: 0.2),
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF2196F3),
                                            width: 2.5,
                                          ),
                                        ),
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF2196F3),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return '请输入用户名';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // 密码
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: '密码',
                                        hintText: '请输入密码',
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF03DAC6)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.lock_rounded,
                                            color: Color(0xFF03DAC6),
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF0FFFE),
                                        suffixIcon: Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          child: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              color: const Color(0xFF03DAC6),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: const Color(0xFF03DAC6)
                                                .withValues(alpha: 0.2),
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF03DAC6),
                                            width: 2.5,
                                          ),
                                        ),
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF03DAC6),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return '请输入密码';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // 记住密码复选框
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _rememberPassword,
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberPassword =
                                                    value ?? false;
                                              });
                                            },
                                            activeColor:
                                                const Color(0xFF2196F3),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _rememberPassword =
                                                  !_rememberPassword;
                                            });
                                          },
                                          child: const Text(
                                            '记住密码',
                                            style: TextStyle(
                                              color: Color(0xFF2196F3),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // 错误消息
                                    if (_errorMessage != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.red.shade400,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _errorMessage ?? '',
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    const SizedBox(height: 24),

                                    // 现代医疗风格登录按钮
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF2196F3),
                                            Color(0xFF03DAC6),
                                            Color(0xFF00BCD4),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF2196F3)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18.0,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 26,
                                                height: 26,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.login_rounded,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '登录',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1.0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // 现代医疗风格提示信息
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(0xFF2196F3)
                                                .withValues(alpha: 0.08),
                                            const Color(0xFF03DAC6)
                                                .withValues(alpha: 0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF2196F3)
                                              .withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2196F3)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.info_outline_rounded,
                                              size: 16,
                                              color: Color(0xFF2196F3),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            '初始用户名: admin，密码: 123456',
                                            style: TextStyle(
                                              color: Color(0xFF2196F3),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
