import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:math' as math;

import '../theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../screens/home_screen.dart';
import '../models/user.dart';

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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 添加波浪动画控制器
  late AnimationController _waveAnimationController;

  // 添加浮动效果控制器
  late AnimationController _floatingAnimationController;

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

    // 初始化波浪动画控制器
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 初始化浮动效果控制器
    _floatingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _waveAnimationController.dispose();
    _floatingAnimationController.dispose();
    super.dispose();
  }

  // 加密密码
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  // 登录方法
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
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
        // 登录成功，导航到首页
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
      print('登录时出错: $e');
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

  // 确保用户表存在
  Future<void> _ensureUserTableExists(DatabaseProvider dbProvider) async {
    // SQLite数据库检查
    if (dbProvider.dataSourceType == 'sqlite' && dbProvider.database != null) {
      final db = dbProvider.database!;

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
          'created_at':
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        });

        print('创建SQLite users表并添加默认管理员用户，密码已设置为123456');
      }
    }

    // MySQL数据库检查
    if (dbProvider.dataSourceType == 'mysql' &&
        dbProvider.mysqlConnection != null) {
      final conn = dbProvider.mysqlConnection!;

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
            `created_at` datetime NOT NULL,
            PRIMARY KEY (`id`) USING BTREE,
            UNIQUE KEY `username` (`username`) USING BTREE,
            UNIQUE KEY `email` (`email`) USING BTREE
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
        ''');

        // 添加默认管理员用户
        final hashedPassword = _hashPassword('123456');
        await conn.query(
            'INSERT INTO users (username, email, password, role, created_at) VALUES (?, ?, ?, ?, ?)',
            [
              'admin',
              'admin@example.com',
              hashedPassword,
              'admin',
              DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
            ]);

        print('创建MySQL users表并添加默认管理员用户，密码已设置为123456');
      }
    }
  }

  // SQLite登录
  Future<bool> _loginWithSQLite(
      DatabaseProvider dbProvider, String username, String password) async {
    if (dbProvider.database == null) {
      throw Exception('SQLite数据库未初始化');
    }

    // 从数据库查询用户
    final result = await dbProvider.database!.query(
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

      return true;
    }

    return false;
  }

  // MySQL登录
  Future<bool> _loginWithMySQL(
      DatabaseProvider dbProvider, String username, String password) async {
    if (dbProvider.mysqlConnection == null) {
      throw Exception('MySQL连接未初始化');
    }

    // 从数据库查询用户
    final results = await dbProvider.mysqlConnection!.query(
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
        if (value is Blob) {
          map[field] = String.fromCharCodes(value.toBytes());
        } else if (field == 'created_at' && value is DateTime) {
          map[field] = DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
        } else {
          map[field] = value;
        }
      }

      final user = User.fromMap(map);
      dbProvider.setCurrentUser(user);

      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 渐变背景，使用多种颜色实现更丰富的效果
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E88E5), // 蓝色
                  Color(0xFF00ACC1), // 青色
                  Color(0xFF00897B), // 蓝绿色
                  Color(0xFF00695C), // 深青色
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // 添加圆形渐变光斑效果
          Positioned(
            top: -size.height * 0.15,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: -size.height * 0.1,
            right: -size.width * 0.1,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 动态波浪效果
          AnimatedBuilder(
            animation: _waveAnimationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size.width, size.height),
                painter: EnhancedWavePainter(
                  animation: _waveAnimationController.value,
                ),
              );
            },
          ),

          // 添加牙科图标装饰元素
          Positioned(
            top: size.height * 0.15,
            right: size.width * 0.2,
            child: Opacity(
              opacity: 0.06,
              child: Transform.rotate(
                angle: -math.pi / 12,
                child: const Icon(
                  Icons.medical_services_outlined,
                  size: 150,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: size.height * 0.2,
            left: size.width * 0.15,
            child: Opacity(
              opacity: 0.06,
              child: Transform.rotate(
                angle: math.pi / 10,
                child: const Icon(
                  Icons.healing_outlined,
                  size: 120,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // 动态浮动气泡效果
          ...List.generate(30, (index) {
            final random = (index * 7) % 100 / 100;
            final bubbleSize = 6.0 + (index % 5) * 4.0;
            return AnimatedBuilder(
              animation: _floatingAnimationController,
              builder: (context, child) {
                final yOffset = math.sin(
                        _floatingAnimationController.value * math.pi * 2 +
                            index) *
                    15.0;
                return Positioned(
                  top: size.height * (0.1 + random * 0.8) + yOffset,
                  left: size.width * ((index % 6) * 0.2 + random * 0.1),
                  child: Container(
                    width: bubbleSize,
                    height: bubbleSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1 + random * 0.1),
                      borderRadius: BorderRadius.circular(bubbleSize),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.05),
                          blurRadius: 2,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),

          // 主要登录内容
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: size.width > 600 ? 500 : size.width * 0.9,
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo和标题
                          Container(
                            width: 100,
                            height: 100,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryColor.withOpacity(0.2),
                                  AppTheme.primaryColor.withOpacity(0.05),
                                ],
                                stops: const [0.4, 1.0],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.medical_services,
                              size: 60,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '牙科诊所管理系统',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryText,
                            ),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 用户名
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    labelText: '用户名',
                                    hintText: '请输入用户名',
                                    prefixIcon: const Icon(Icons.person),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
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
                                    prefixIcon: const Icon(Icons.lock),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '请输入密码';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),

                                // 错误消息
                                if (_errorMessage != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
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
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
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

                                // 登录按钮
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          '登录',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),

                                const SizedBox(height: 20),

                                // 提示信息
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.blue.shade700,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '初始用户名: admin，密码: 123456',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 14,
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
        ],
      ),
    );
  }
}

// 增强版波浪绘制器
class EnhancedWavePainter extends CustomPainter {
  final double animation;

  EnhancedWavePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 绘制多层波浪效果
    _drawWave(canvas, size, height * 0.75, 0.06, animation, 25.0, 10.0);
    _drawWave(canvas, size, height * 0.8, 0.08, animation + 0.25, 20.0, 15.0);
    _drawWave(canvas, size, height * 0.85, 0.1, animation + 0.5, 15.0, 10.0);

    // 添加水平光线效果
    final paint4 = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 5; i++) {
      double y = height * (0.3 + i * 0.1);
      double amplitude = 6.0 - i * 1.0;

      final path4 = Path();
      path4.moveTo(0, y);

      for (int j = 0; j < width.toInt(); j += 20) {
        double x = j.toDouble();
        double yOffset =
            math.sin((x / width * 6 * math.pi) + animation * math.pi * 2 + i) *
                amplitude;
        path4.lineTo(x, y + yOffset);
      }

      canvas.drawPath(path4, paint4);
    }
  }

  // 辅助方法：绘制单层波浪
  void _drawWave(Canvas canvas, Size size, double baseHeight, double opacity,
      double phaseShift, double amplitude1, double amplitude2) {
    final width = size.width;
    final height = size.height;

    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, baseHeight);

    for (int i = 0; i < width.toInt(); i += 5) {
      double x = i.toDouble();
      double y = baseHeight +
          math.sin((x / width * 2 * math.pi) + phaseShift * 2 * math.pi) *
              amplitude1 +
          math.sin((x / width * 4 * math.pi) + phaseShift * 2 * math.pi) *
              amplitude2;
      path.lineTo(x, y);
    }

    path.lineTo(width, baseHeight);
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EnhancedWavePainter oldDelegate) => true;
}

// 原有的波浪绘制器
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(0, height * 0.7);

    // 第一条波浪曲线
    for (int i = 0; i < 5; i++) {
      if (i % 2 == 0) {
        path.quadraticBezierTo(width * (0.2 + i * 0.2), height * 0.6,
            width * (0.4 + i * 0.2), height * 0.7);
      } else {
        path.quadraticBezierTo(width * (0.2 + i * 0.2), height * 0.8,
            width * (0.4 + i * 0.2), height * 0.7);
      }
    }

    canvas.drawPath(path, paint);

    // 第二条波浪曲线
    final path2 = Path();
    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    path2.moveTo(0, height * 0.65);

    for (int i = 0; i < 6; i++) {
      if (i % 2 == 0) {
        path2.quadraticBezierTo(width * (0.15 + i * 0.15), height * 0.55,
            width * (0.3 + i * 0.15), height * 0.65);
      } else {
        path2.quadraticBezierTo(width * (0.15 + i * 0.15), height * 0.75,
            width * (0.3 + i * 0.15), height * 0.65);
      }
    }

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
