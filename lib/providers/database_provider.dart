import 'package:flutter/foundation.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/utils/database_utils.dart';
import 'package:dentist_app/utils/pinyin_util.dart'; // 导入拼音工具类
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql1/mysql1.dart' as mysql;
import 'package:excel/excel.dart';

// 数据库提供者，用于管理应用程序与数据库的交互
class DatabaseProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _dbType = 'sqlite'; // 默认使用sqlite
  String _dbPath = '';
  late DatabaseConfig _dbConfig;
  bool _initialized = false;
  // 添加一个数据库变更标志，当数据库切换时会变更
  bool _databaseChanged = false;
  bool _shouldNavigateToDashboard = false; // 添加控制是否导航到仪表盘的标志

  // 用于仪表盘页面检查是否需要刷新数据
  bool _dashboardNeedsRefresh = false;
  bool get dashboardNeedsRefresh => _dashboardNeedsRefresh;

  // 缓存数据
  List<Patient>? _cachedPatients;
  List<Appointment>? _cachedAppointments;
  List<String>? _cachedDoctors;

  // 数据源具体实现
  late SqliteDataSource _sqliteDataSource;
  late MySqlDataSource _mysqlDataSource;

  // MySQL连接配置
  mysql.MySqlConnection? _mysqlConnection;

  // 获取数据库类型
  String get dbType => _dbType;

  // 获取数据库路径
  String get dbPath => _dbPath;

  // 初始化标志
  bool get isInitialized => _initialized;

  // 数据库变更标志
  bool get databaseChanged => _databaseChanged;

  // 是否需要导航到仪表盘
  bool get shouldNavigateToDashboard => _shouldNavigateToDashboard;

  // 构造函数
  DatabaseProvider() {
    _sqliteDataSource = SqliteDataSource(this);
    _mysqlDataSource = MySqlDataSource(this);
  }

  // 获取当前活跃的数据源
  DataSource get _activeDataSource {
    switch (_dbType) {
      case 'sqlite':
        return _sqliteDataSource;
      case 'mysql':
        return _mysqlDataSource;
      default:
        throw Exception('不支持的数据库类型: $_dbType');
    }
  }

  // 为了兼容性，将init()方法作为initDatabase()的别名
  Future<void> init() => initDatabase();

  // 重置数据库变更标志
  void resetDatabaseChanged() {
    _databaseChanged = false;
    _shouldNavigateToDashboard = false;
  }

  // 强制设置数据库变更标志
  void forceDataChanged({bool navigateToDashboard = false}) {
    print('强制设置数据变更标志, 导航到仪表盘: $navigateToDashboard');

    // 只有明确要求导航到仪表盘时才设置全局变更标志
    if (navigateToDashboard) {
      _databaseChanged = true;
      _shouldNavigateToDashboard = true;
    } else {
      // 否则只标记仪表盘需要刷新，不导航
      _dashboardNeedsRefresh = true;
    }

    _forceInvalidateCache();
    notifyListeners();
  }

  // 局部刷新患者数据，不触发全局导航或任何页面重建
  void refreshPatientsData() {
    print('局部刷新患者数据');
    // 仅清除患者缓存
    _cachedPatients = null;
    // 不需要调用notifyListeners，避免任何监听器被触发导致页面重建
  }

  // 局部刷新预约数据，不触发全局导航但通知监听器
  void refreshAppointmentsData() {
    print('局部刷新预约数据');
    // 清除预约缓存
    _cachedAppointments = null;
    // 通知监听器刷新UI
    notifyListeners();
    print('已通知监听器刷新预约数据');
  }

  // 重置仪表盘刷新标志
  void resetDashboardRefreshFlag() {
    print('重置仪表盘刷新标志');
    _dashboardNeedsRefresh = false;
  }

  // 初始化数据库
  Future<void> initDatabase() async {
    if (_initialized) {
      print('数据库已经初始化，跳过初始化过程');
      return;
    }

    try {
      print('开始初始化数据库...');
      // 加载配置
      _dbConfig = await DatabaseConfig.loadConfig();
      _dbType = _dbConfig.dbType;
      print('数据库类型: $_dbType');

      // 如果是SQLite，确保路径存在
      if (_dbType == 'sqlite') {
        if (_dbConfig.sqlite.path.isEmpty) {
          // 设置默认路径
          print('SQLite路径为空，设置默认路径');
          _dbConfig.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
          await _dbConfig.saveConfig();
        } else if (!File(_dbConfig.sqlite.path).existsSync()) {
          print('SQLite路径不存在: ${_dbConfig.sqlite.path}');
          // 确保目录存在
          final dbDir = Directory(path.dirname(_dbConfig.sqlite.path));
          if (!dbDir.existsSync()) {
            print('创建数据库目录: ${dbDir.path}');
            await dbDir.create(recursive: true);
          }
        }

        // 设置数据库路径
        _dbPath = _dbConfig.sqlite.path;
        print('SQLite数据库路径: $_dbPath');
        DatabaseHelper.setCustomDbPath(_dbPath);
      }
      // 如果是MySQL，设置连接参数
      else if (_dbType == 'mysql') {
        print('配置MySQL连接参数...');

        // 检查并转换localhost为10.0.2.2（如果在Android平台）
        if (Platform.isAndroid &&
            (_dbConfig.mysql.host == 'localhost' ||
                _dbConfig.mysql.host == '127.0.0.1')) {
          print('Android平台检测到localhost配置，自动转换为10.0.2.2');
          _dbConfig.mysql.host = '10.0.2.2';

          // 保存更新后的配置
          await _dbConfig.saveConfig();
          print('已自动更新配置文件中的MySQL主机为10.0.2.2');
        }

        _dbPath =
            '${_dbConfig.mysql.host}:${_dbConfig.mysql.port}/${_dbConfig.mysql.database}';
        try {
          await _initMySQLConnection();
        } catch (e) {
          print('MySQL连接失败，回退到SQLite: $e');
          _dbType = 'sqlite';
          _dbConfig.dbType = 'sqlite';
          await _dbConfig.saveConfig();
          _dbPath = _dbConfig.sqlite.path;
          DatabaseHelper.setCustomDbPath(_dbPath);
        }
      }

      // 初始化数据库
      print('获取数据库实例...');
      try {
        if (_dbType == 'sqlite') {
          final db = await _dbHelper.database;
          _dbPath = await _dbHelper.getDatabasePath();
          print('数据库路径确认: $_dbPath');

          // 检查数据库是否正常工作
          try {
            print('测试数据库连接...');
            await db.rawQuery('SELECT 1');
            print('数据库连接测试成功');
          } catch (e) {
            print('数据库连接测试失败: $e');
            throw Exception('数据库连接测试失败: $e');
          }
        }
      } catch (e) {
        print('获取数据库实例失败: $e');

        // 尝试重新创建数据库
        print('尝试重新创建数据库...');
        await _dbHelper.closeDatabase();

        // 如果是SQLite，尝试重置数据库路径
        if (_dbType == 'sqlite') {
          _dbConfig.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
          await _dbConfig.saveConfig();
          _dbPath = _dbConfig.sqlite.path;
          DatabaseHelper.setCustomDbPath(_dbPath);
        }

        // 重新尝试获取数据库实例
        if (_dbType == 'sqlite') {
          final db = await _dbHelper.database;
          _dbPath = await _dbHelper.getDatabasePath();
          print('重试后数据库路径确认: $_dbPath');

          // 再次测试连接
          await db.rawQuery('SELECT 1');
        }
        print('重试后数据库连接测试成功');
      }

      _initialized = true;
      print('数据库初始化完成');
      notifyListeners();
    } catch (e) {
      debugPrint('初始化数据库错误: $e');
      _initialized = false;
      throw Exception('数据库初始化失败: $e');
    }
  }

  // 初始化MySQL连接
  Future<void> _initMySQLConnection() async {
    try {
      print('初始化MySQL连接...');

      // 首先关闭已有连接
      if (_mysqlConnection != null) {
        await _mysqlConnection!.close();
        _mysqlConnection = null;
      }

      // 检查配置
      if (_dbConfig.mysql.host.isEmpty) {
        throw Exception('MySQL主机名为空');
      }

      // 确保使用配置中的主机名，而不是硬编码的localhost
      String host = _dbConfig.mysql.host;
      String port =
          _dbConfig.mysql.port.isEmpty ? '3306' : _dbConfig.mysql.port;

      // 检查并转换localhost为10.0.2.2（如果在Android平台）
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        print('Android连接检测到localhost，自动转换为10.0.2.2');
        host = '10.0.2.2';

        // 记录但不自动保存，因为这可能只是临时连接测试
        print('注意：配置中的主机名保持不变，仅在当前连接中使用10.0.2.2');
      }

      // 对于Android模拟器，如果使用10.0.2.2，记录下来
      if (host == "10.0.2.2") {
        print('使用Android模拟器特殊主机: 10.0.2.2 (模拟器中的localhost)');
      }

      // 创建新连接设置
      final settings = mysql.ConnectionSettings(
        host: host,
        port: int.parse(port),
        user: _dbConfig.mysql.username,
        password: _dbConfig.mysql.password,
        db: _dbConfig.mysql.database,
        timeout: const Duration(seconds: 20), // 增加超时时间到20秒
      );

      // 先测试Socket连接
      print('测试Socket连接到MySQL: $host:$port');
      try {
        final socket = await Socket.connect(
          host,
          int.parse(port),
          timeout: const Duration(seconds: 15),
          sourceAddress: InternetAddress.anyIPv4, // 指定使用IPv4地址
        );
        print('Socket连接成功，销毁临时Socket');
        socket.destroy();
      } catch (socketError) {
        print('Socket连接测试失败: $socketError');
        throw Exception('无法连接到MySQL服务器: $socketError');
      }

      // 尝试连接
      print('准备连接到MySQL: $host:$port/${_dbConfig.mysql.database}');

      try {
        _mysqlConnection = await mysql.MySqlConnection.connect(settings);
      } catch (e) {
        print('MySQL连接错误: $e');
        if (e.toString().contains('SocketException')) {
          throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确');
        } else if (e.toString().contains('Access denied')) {
          throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
        } else if (e.toString().contains('Unknown database')) {
          throw Exception('数据库不存在，请检查数据库名称是否正确');
        } else {
          throw Exception('MySQL连接失败: $e');
        }
      }

      // 测试连接
      try {
        final results = await _mysqlConnection!.query('SELECT 1');
        if (results.isNotEmpty) {
          print('MySQL连接测试成功');
        } else {
          throw Exception('MySQL连接测试失败: 查询返回空结果');
        }
      } catch (e) {
        print('MySQL查询测试错误: $e');
        throw Exception('MySQL连接成功但查询测试失败: $e');
      }
    } catch (e) {
      print('MySQL连接错误: $e');
      _mysqlConnection = null;
      throw Exception('MySQL连接失败: $e');
    }
  }

  // 切换数据库类型
  Future<void> switchDatabaseType(
    String type, {
    String? path, // 可选的SQLite路径
  }) async {
    final oldType = _dbType;
    print('切换数据库类型到 $type，当前类型: $oldType');

    try {
      // 强制清除所有缓存
      _cachedPatients = null;
      _cachedAppointments = null;
      _cachedDoctors = null;

      _dbType = type;
      _dbConfig.dbType = type; // 确保配置也更新

      // 修改标记方式，只刷新仪表盘，不自动导航
      _dashboardNeedsRefresh = true;
      // 不设置全局变更标志，避免导航到仪表盘
      // _databaseChanged = true;

      if (type == 'sqlite') {
        if (path != null) {
          _dbConfig.sqlite.path = path;
        }
        await _dbConfig.saveConfig();

        // 关闭MySQL连接
        if (_mysqlConnection != null) {
          await _mysqlConnection!.close();
          _mysqlConnection = null;
        }

        // 关闭当前数据库连接
        await _dbHelper.closeDatabase();

        // 设置新的数据库路径
        DatabaseHelper.setCustomDbPath(_dbConfig.sqlite.path);

        // 重新初始化数据库
        await _dbHelper.database;
        _dbPath = await _dbHelper.getDatabasePath();
      } else if (type == 'mysql') {
        // 确保配置已保存
        await _dbConfig.saveConfig();

        // 先关闭当前SQLite数据库连接
        await _dbHelper.closeDatabase();

        // 直接使用当前已有配置，不要重新加载
        String host = _dbConfig.mysql.host;
        String port = _dbConfig.mysql.port;
        String database = _dbConfig.mysql.database;
        String username = _dbConfig.mysql.username;
        String password = _dbConfig.mysql.password;

        // 确认配置已正确加载
        print('使用MySQL配置: $host:$port/$database');

        // 重新初始化MySQL连接
        _dbPath = '$host:$port/$database';

        try {
          // 直接使用当前配置值初始化连接
          await _initMySQLConnectionWithParams(
            host,
            port,
            database,
            username,
            password,
          );

          // MySQL切换成功后，测试一下连接和查询
          print('测试MySQL连接...');
          try {
            var testResult = await _mysqlConnection!.query(
              'SELECT COUNT(*) as count FROM patients',
            );
            print('MySQL测试查询结果: ${testResult.length} 行');
            if (testResult.isNotEmpty) {
              var count = testResult.first['count'];
              print('患者总数: $count');
            }
          } catch (testError) {
            print('MySQL测试查询错误: $testError');
          }
        } catch (e) {
          print('连接到MySQL失败: $e');
          throw Exception('无法连接到MySQL服务器，请检查网络或配置');
        }
      }

      // 强制清除所有缓存，确保下次查询时重新获取数据
      _forceInvalidateCache();

      print('进行一些测试查询确保数据库连接正常工作...');
      try {
        int count = await getPatientCount();
        print('数据源切换后的患者总数: $count');

        if (count > 0) {
          // 尝试获取第一个患者以测试数据库
          List<Patient> patients = await getAllPatients();
          if (patients.isNotEmpty) {
            print('成功获取第一个患者: ${patients.first.name}');
          }
        }
      } catch (e) {
        print('测试查询失败: $e');
      }

      // 连续发送多次通知，确保所有监听者都更新
      print('发送多次通知以刷新UI');
      notifyListeners();
    } catch (e) {
      print('切换数据库类型错误: $e');

      // 如果是MySQL切换失败，回退到SQLite
      if (type == 'mysql') {
        print('切换到MySQL失败，回退到SQLite');

        // 重置数据库类型
        _dbType = 'sqlite';
        _dbConfig.dbType = 'sqlite';
        await _dbConfig.saveConfig();

        // 重新初始化SQLite
        DatabaseHelper.setCustomDbPath(_dbConfig.sqlite.path);
        try {
          await _dbHelper.database;
          _dbPath = await _dbHelper.getDatabasePath();
        } catch (sqliteError) {
          print('回退到SQLite时出错: $sqliteError');
        }
      }

      // 通知UI更新
      _forceInvalidateCache();
      notifyListeners();

      // 重新抛出异常，让调用者知道发生了错误
      throw Exception('切换数据库类型失败: $e');
    }
  }

  // 强制使所有缓存失效并重建
  void _forceInvalidateCache() {
    print('强制清除所有缓存数据');
    // 清空所有缓存数据
    _cachedPatients = null;
    _cachedAppointments = null;
    _cachedDoctors = null;

    // 其他可能的缓存数据
    // 修改为仅标记仪表盘需要刷新，不设置全局变更标志
    _dashboardNeedsRefresh = true;
    // _databaseChanged = true;

    // 主动加载一些数据以刷新缓存
    Future.delayed(Duration.zero, () async {
      try {
        print('主动重新加载数据以更新缓存');
        if (_dbType == 'sqlite') {
          final db = await _dbHelper.database;
          // 执行一些简单查询以确保数据库连接正常
          await db.rawQuery('SELECT 1');

          // 主动触发缓存更新
          getAllPatients().then((_) => print('患者数据缓存已更新'));
          getAllAppointments().then((_) => print('预约数据缓存已更新'));

          // 再次通知监听者
          notifyListeners();
        }
      } catch (e) {
        print('主动加载数据失败: $e');
      }
    });
  }

  // 查询MySQL数据
  Future<List<Map<String, dynamic>>> _queryMySQLData(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      // 确保MySQL连接可用
      if (_mysqlConnection == null) {
        await _initMySQLConnection();
        if (_mysqlConnection == null) {
          throw Exception('MySQL连接不可用');
        }
      }

      // 构建查询语句
      String query;
      if (where != null && whereArgs != null) {
        // 替换?为实际参数值
        String processedWhere = where;
        for (var arg in whereArgs) {
          if (arg is String) {
            processedWhere = processedWhere.replaceFirst('?', "'$arg'");
          } else {
            processedWhere = processedWhere.replaceFirst('?', arg.toString());
          }
        }
        query = 'SELECT * FROM $table WHERE $processedWhere';
      } else {
        query = 'SELECT * FROM $table';
      }

      print('执行MySQL查询: $query');
      final results = await _mysqlConnection!.query(query);

      print('MySQL查询结果行数: ${results.length}');

      // 将结果转换为Map列表
      final List<Map<String, dynamic>> resultList = [];
      for (var row in results) {
        // 直接创建一个新的Map，不再依赖字段名映射
        final Map<String, dynamic> rowMap = {};

        // 打印所有字段名称和值，帮助调试
        print('MySQL行数据字段: ${row.fields.keys.join(", ")}');

        // 对于患者表，执行精确的字段映射
        if (table == 'patients') {
          print('处理患者表数据...');

          // ID字段
          rowMap['id'] = _getSafeValue(row, 'id');

          // 病历号
          rowMap['medical_record_number'] = _getSafeValue(
            row,
            'medical_record_number',
          );

          // 姓名
          rowMap['name'] = _getSafeValue(row, 'name')?.toString() ?? '';

          // 姓名拼音
          rowMap['name_pinyin'] = _getSafeValue(row, 'name_pinyin')?.toString();

          // 年龄 - 确保是整数
          if (_getSafeValue(row, 'age') != null) {
            try {
              rowMap['age'] =
                  _getSafeValue(row, 'age') is int
                      ? _getSafeValue(row, 'age')
                      : int.parse(_getSafeValue(row, 'age').toString());
            } catch (e) {
              print('年龄转换错误: $e');
              rowMap['age'] = 0;
            }
          } else {
            rowMap['age'] = 0;
          }

          // 性别 - 标准化为'男'或'女'
          var gender =
              _getSafeValue(row, 'gender')?.toString().trim().toLowerCase() ??
              '';
          if (gender == 'male' ||
              gender == '1' ||
              gender == 'm' ||
              gender == '男') {
            rowMap['gender'] = '男';
          } else if (gender == 'female' ||
              gender == '0' ||
              gender == 'f' ||
              gender == '女') {
            rowMap['gender'] = '女';
          } else {
            rowMap['gender'] = gender;
          }

          // 电话号码 - 处理JSON格式
          var phone = _getSafeValue(row, 'phone')?.toString() ?? '';
          if (phone.startsWith('[') && phone.endsWith(']')) {
            try {
              var phones = jsonDecode(phone);
              if (phones is List && phones.isNotEmpty) {
                rowMap['phone'] = phones.join(',');
              } else {
                rowMap['phone'] = '';
              }
            } catch (e) {
              print('解析电话JSON错误: $e');
              rowMap['phone'] = phone;
            }
          } else {
            rowMap['phone'] = phone;
          }

          // 地址
          rowMap['address'] = _getSafeValue(row, 'address')?.toString();

          // 地址拼音
          rowMap['address_pinyin'] =
              _getSafeValue(row, 'address_pinyin')?.toString();

          // 身份证号
          rowMap['identification_number'] =
              _getSafeValue(row, 'identification_number')?.toString();

          // 医生
          rowMap['doctor'] = _getSafeValue(row, 'doctor')?.toString();

          // 初诊日期
          var firstVisitDate = _getSafeValue(row, 'first_visit_date');
          if (firstVisitDate is DateTime) {
            rowMap['first_visit_date'] = firstVisitDate.toIso8601String();
          } else if (firstVisitDate != null) {
            try {
              // 尝试解析日期字符串
              var date = DateTime.parse(firstVisitDate.toString());
              rowMap['first_visit_date'] = date.toIso8601String();
            } catch (e) {
              print('解析初诊日期错误: $e');
              rowMap['first_visit_date'] = DateTime.now().toIso8601String();
            }
          } else {
            rowMap['first_visit_date'] = DateTime.now().toIso8601String();
          }

          // 牙齿状况
          rowMap['dental_condition'] =
              _getSafeValue(row, 'dental_condition')?.toString();

          // 治疗项目
          rowMap['treatment_items'] =
              _getSafeValue(row, 'treatment_items')?.toString();

          // 总费用
          var totalCost = _getSafeValue(row, 'total_cost');
          if (totalCost != null) {
            try {
              rowMap['total_cost'] =
                  totalCost is double
                      ? totalCost
                      : double.parse(totalCost.toString());
            } catch (e) {
              print('费用转换错误: $e');
              rowMap['total_cost'] = 0.0;
            }
          } else {
            rowMap['total_cost'] = 0.0;
          }

          // 创建和更新时间
          _processDateField(row, rowMap, 'created_at');
          _processDateField(row, rowMap, 'updated_at');

          // 打印最终映射结果
          print('映射后的患者数据: $rowMap');
        } else {
          // 其他表的通用处理
          for (var field in row.fields.keys) {
            // 转换驼峰命名为下划线格式
            String key = field;
            if (key.contains(RegExp(r'[A-Z]'))) {
              key = key.replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => '_${match.group(1)!.toLowerCase()}',
              );
            }

            var value = row[field];

            // 处理特殊类型
            if (value is DateTime) {
              rowMap[key] = value.toIso8601String();
            } else if (key.endsWith('_date') || key.endsWith('_at')) {
              // 日期字段处理
              if (value != null) {
                try {
                  rowMap[key] =
                      DateTime.parse(value.toString()).toIso8601String();
                } catch (e) {
                  rowMap[key] = value?.toString();
                }
              }
            } else {
              rowMap[key] = value;
            }
          }
        }

        resultList.add(rowMap);
      }

      print('MySQL查询已转换为 ${resultList.length} 行数据');
      return resultList;
    } catch (e) {
      print('MySQL查询错误: $e');
      // 尝试重新连接
      try {
        if (_mysqlConnection != null) {
          await _mysqlConnection!.close();
        }
        _mysqlConnection = null;
        await _initMySQLConnection();

        // 重试查询一次
        return await _queryMySQLData(table, where: where, whereArgs: whereArgs);
      } catch (reconnectError) {
        print('MySQL重连失败: $reconnectError');
        throw Exception('MySQL查询失败: $e，重连失败: $reconnectError');
      }
    }
  }

  // 安全获取MySQL结果中的值
  dynamic _getSafeValue(var row, String fieldName) {
    try {
      if (row.fields.containsKey(fieldName)) {
        return row[fieldName];
      }

      // 尝试查找不区分大小写的匹配
      var lowerFieldName = fieldName.toLowerCase();
      for (var key in row.fields.keys) {
        if (key.toLowerCase() == lowerFieldName) {
          return row[key];
        }
      }

      return null;
    } catch (e) {
      print('获取字段 $fieldName 值错误: $e');
      return null;
    }
  }

  // 处理日期字段
  void _processDateField(
    var row,
    Map<String, dynamic> rowMap,
    String fieldName,
  ) {
    var dateValue = _getSafeValue(row, fieldName);
    if (dateValue is DateTime) {
      rowMap[fieldName] = dateValue.toIso8601String();
    } else if (dateValue != null) {
      try {
        var date = DateTime.parse(dateValue.toString());
        rowMap[fieldName] = date.toIso8601String();
      } catch (e) {
        print('解析$fieldName错误: $e');
        rowMap[fieldName] = DateTime.now().toIso8601String();
      }
    } else {
      rowMap[fieldName] = DateTime.now().toIso8601String();
    }
  }

  // 将ISO日期字符串转换为MySQL兼容的格式
  String _formatDateForMySQL(String isoDateString) {
    try {
      // 解析ISO 8601格式的日期字符串
      final date = DateTime.parse(isoDateString);

      // 确保使用本地时间
      final localDate = date.toLocal();

      // 格式化为MySQL兼容的格式 (YYYY-MM-DD HH:MM:SS)
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(localDate);
    } catch (e) {
      print('日期格式转换错误: $e，使用当前时间');
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().toLocal());
    }
  }

  // 患者相关操作
  // 获取所有患者
  Future<List<Patient>> getAllPatients() async {
    try {
      if (_cachedPatients != null) {
        return _cachedPatients!;
      }

      final patients = await _activeDataSource.getAllPatients();
      _cachedPatients = patients;
      return patients;
    } catch (e) {
      print('获取所有患者错误: $e');
      return [];
    }
  }

  // 获取患者总数
  Future<int> getPatientCount() async {
    try {
      print('正在获取患者总数...');
      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        if (db != null) {
          final result = await db.rawQuery(
            'SELECT COUNT(*) as count FROM patients',
          );
          final count = Sqflite.firstIntValue(result) ?? 0;
          print('SQLite数据库中的患者总数: $count');
          return count;
        }
      } else if (_dbType == 'mysql') {
        final conn = await _mysqlConnection;
        if (conn != null) {
          final results = await conn.query(
            'SELECT COUNT(*) as count FROM patients',
          );
          if (results.isNotEmpty) {
            final count = results.first.fields['count'] as int;
            print('MySQL数据库中的患者总数: $count');
            return count;
          }
        }
      }

      // 如果无法获取数据，默认返回0，显示病历号为1
      print('无法获取患者数量，使用默认值0');
      return 0;
    } catch (e) {
      print('获取患者总数错误: $e');
      return 0;
    }
  }

  // 获取最大病历号
  Future<int> getMaxMedicalRecordNumber() async {
    try {
      print('正在获取最大病历号...');
      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        if (db != null) {
          final result = await db.rawQuery(
            'SELECT MAX(medical_record_number) as max_id FROM patients',
          );
          final maxId = Sqflite.firstIntValue(result) ?? 0;
          print('SQLite数据库中的最大病历号: $maxId');
          return maxId;
        }
      } else if (_dbType == 'mysql') {
        final conn = await _mysqlConnection;
        if (conn != null) {
          final results = await conn.query(
            'SELECT MAX(medical_record_number) as max_id FROM patients',
          );
          if (results.isNotEmpty) {
            final maxId = results.first.fields['max_id'] as int? ?? 0;
            print('MySQL数据库中的最大病历号: $maxId');
            return maxId;
          }
        }
      }

      // 如果无法获取数据，默认返回0，新病历号为1
      print('无法获取最大病历号，使用默认值0');
      return 0;
    } catch (e) {
      print('获取最大病历号错误: $e');
      return 0;
    }
  }

  // 备份整个SQLite数据库文件
  Future<bool> backupDatabase(String destinationPath) async {
    try {
      print('开始备份SQLite数据库到: $destinationPath');

      // 确认当前是SQLite数据库类型
      if (_dbType != 'sqlite') {
        print('错误：只能备份SQLite数据库');
        return false;
      }

      // 获取SQLite数据库文件路径
      final db = await _dbHelper.database;
      await db.close(); // 首先关闭数据库连接以确保所有写入已完成

      final dbPath = _dbHelper.databasePath;
      if (dbPath == null || dbPath.isEmpty) {
        print('错误：无法获取SQLite数据库路径');
        // 尝试获取默认路径
        final defaultPath = await _dbHelper.getDatabasePath();
        if (defaultPath.isEmpty) {
          return false;
        }
        print('使用默认路径: $defaultPath');

        // 复制数据库文件
        final sourceFile = File(defaultPath);
        if (!await sourceFile.exists()) {
          print('错误：源数据库文件不存在');
          return false;
        }

        await sourceFile.copy(destinationPath);
        print('数据库文件已备份到: $destinationPath');
      } else {
        print('源数据库路径: $dbPath');

        // 复制数据库文件
        final sourceFile = File(dbPath);
        if (!await sourceFile.exists()) {
          print('错误：源数据库文件不存在');
          return false;
        }

        await sourceFile.copy(destinationPath);
        print('数据库文件已备份到: $destinationPath');
      }

      // 创建目标目录（如果不存在）
      final dir = File(destinationPath).parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 重新打开数据库
      await _dbHelper.reopenDatabase();

      return true;
    } catch (e) {
      print('备份数据库错误: $e');
      // 确保重新打开数据库
      try {
        // 使用数据库实例来重新打开数据库
        final db = await _dbHelper.database;
        print('数据库已重新打开');
      } catch (reopenError) {
        print('重新打开数据库错误: $reopenError');
      }
      return false;
    }
  }

  // 从备份文件恢复SQLite数据库
  Future<bool> restoreDatabaseFromBackup(String backupPath) async {
    try {
      print('开始从备份恢复SQLite数据库: $backupPath');

      // 确认当前是SQLite数据库类型
      if (_dbType != 'sqlite') {
        print('错误：只能恢复到SQLite数据库');
        return false;
      }

      // 检查备份文件是否存在
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        print('错误：备份文件不存在');
        return false;
      }

      // 获取SQLite数据库文件路径
      final db = await _dbHelper.database;
      await db.close(); // 首先关闭数据库连接

      final dbPath = _dbHelper.databasePath;
      if (dbPath == null || dbPath.isEmpty) {
        print('错误：无法获取SQLite数据库路径');
        // 尝试获取默认路径
        final defaultPath = await _dbHelper.getDatabasePath();
        if (defaultPath.isEmpty) {
          return false;
        }
        print('使用默认路径: $defaultPath');

        // 复制备份文件到数据库位置
        await backupFile.copy(defaultPath);
        print('备份文件已恢复到数据库');
      } else {
        print('目标数据库路径: $dbPath');

        // 复制备份文件到数据库位置
        await backupFile.copy(dbPath);
        print('备份文件已恢复到数据库');
      }

      // 重新打开数据库
      await _dbHelper.reopenDatabase();

      // 清除缓存
      _cachedPatients = null;
      _cachedAppointments = null;
      _cachedDoctors = null;

      // 设置仪表盘需要刷新标志，但不会触发导航
      _dashboardNeedsRefresh = true;

      print('数据库已从备份恢复');
      return true;
    } catch (e) {
      print('恢复数据库错误: $e');
      // 确保重新打开数据库
      try {
        // 使用数据库实例来重新打开数据库
        final db = await _dbHelper.database;
        print('数据库已重新打开');
      } catch (reopenError) {
        print('重新打开数据库错误: $reopenError');
      }
      return false;
    }
  }

  // 仅导出患者表到指定目录
  Future<String> exportPatientsTable(String destinationDir) async {
    try {
      // 检查数据库类型，只允许导出SQLite数据库
      if (_dbType != 'sqlite') {
        throw Exception('目前只支持导出SQLite数据库患者表');
      }

      print('开始导出患者表数据');

      // 获取当前数据库文件路径
      final dbPath = _dbPath;
      if (dbPath.isEmpty) {
        throw Exception('找不到当前数据库路径');
      }

      // 使用数据库工具类导出患者表
      final exportPath = await DatabaseUtils.exportPatientsTable(
        dbPath,
        destinationDir,
      );

      if (exportPath.isEmpty) {
        throw Exception('导出过程中发生错误');
      }

      print('患者表已成功导出到: $exportPath');
      return exportPath;
    } catch (e) {
      print('导出患者表错误: $e');
      throw Exception('患者表导出失败: $e');
    }
  }

  // 使用SAF保存患者数据备份
  Future<String> savePatientBackupWithSaf(
    String jsonData,
    String fileName,
  ) async {
    try {
      // 请求权限
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('需要存储权限才能备份患者数据');
      }

      // 将JSON数据写入临时文件
      final directory = await getTemporaryDirectory();
      final tempFile = File('${directory.path}/$fileName');
      await tempFile.writeAsString(jsonData);

      // 使用SAF让用户选择保存位置
      const mimeType = 'application/json';

      final params = SaveFileDialogParams(
        sourceFilePath: tempFile.path,
        fileName: fileName,
        mimeTypesFilter: [mimeType],
      );

      final filePath = await FlutterFileDialog.saveFile(params: params);

      // 删除临时文件
      await tempFile.delete();

      if (filePath == null) {
        throw Exception('用户取消了备份操作');
      }

      return '患者数据已备份到: $filePath';
    } catch (e) {
      print('SAF备份患者数据错误: $e');
      throw Exception('备份患者数据失败：$e');
    }
  }

  // 恢复出厂设置（重置数据库）
  Future<bool> resetToFactorySettings() async {
    try {
      // 执行重置
      final success = await DatabaseUtils.resetDatabase(_dbPath);

      if (success) {
        // 重新初始化数据库
        await initDatabase();
        notifyListeners();
        return true;
      } else {
        throw Exception('重置失败');
      }
    } catch (e) {
      debugPrint('重置数据库错误: $e');
      rethrow;
    }
  }

  // 添加患者
  Future<int> addPatient(Patient patient) async {
    try {
      final id = await _activeDataSource.addPatient(patient);

      // 清除缓存
      _cachedPatients = null;
      // 设置仪表盘需要刷新标志
      _dashboardNeedsRefresh = true;
      print('患者数据已添加，缓存已清除，仪表盘需要刷新');

      return id;
    } catch (e) {
      print('添加患者错误: $e');
      rethrow;
    }
  }

  // 更新患者
  Future<bool> updatePatient(Patient patient) async {
    try {
      print('开始更新患者数据: ${patient.toMap()}');

      // 生成更新时间
      patient.updatedAt = DateTime.now();

      final success = await _activeDataSource.updatePatient(patient);

      // 清除缓存
      if (success) {
        _cachedPatients = null;
        _dashboardNeedsRefresh = true;
      }

      return success;
    } catch (e) {
      print('更新患者错误: $e');
      return false;
    }
  }

  // 删除患者
  Future<int> deletePatient(int id) async {
    try {
      print('开始删除患者ID $id 及其关联预约');

      // 1. 先获取该患者的所有预约
      final appointments = await getAppointmentsByPatientId(id);
      print('找到患者关联的预约记录: ${appointments.length}条');

      // 2. 删除该患者的所有预约
      int appointmentsDeleted = 0;
      for (var appointment in appointments) {
        if (appointment.id != null) {
          try {
            final result = await deleteAppointment(appointment.id!);
            appointmentsDeleted += result;
            print('已删除预约 ID: ${appointment.id}');
          } catch (e) {
            print('删除患者相关预约时出错 ID: ${appointment.id}, 错误: $e');
            // 继续尝试删除其他预约，不中断流程
          }
        }
      }
      print('成功删除关联预约: $appointmentsDeleted条');

      // 3. 删除患者
      final result = await _activeDataSource.deletePatient(id);

      // 4. 清除缓存
      _cachedPatients = null;
      _cachedAppointments = null;
      _dashboardNeedsRefresh = true;

      return result;
    } catch (e) {
      print('删除患者错误: $e');
      rethrow;
    }
  }

  // 根据ID获取患者
  Future<Patient?> getPatientById(int id) async {
    try {
      return await _activeDataSource.getPatientById(id);
    } catch (e) {
      print('获取患者数据异常: $e');
      return null;
    }
  }

  // 获取患者的所有预约
  Future<List<Appointment>> getPatientAppointments(int patientId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'appointments',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );

    return List.generate(maps.length, (i) {
      return Appointment.fromMap(maps[i]);
    });
  }

  // 根据患者ID获取预约
  Future<List<Appointment>> getAppointmentsByPatientId(int patientId) async {
    try {
      List<Map<String, dynamic>> maps;

      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        maps = await db.query(
          'appointments',
          where: 'patient_id = ?',
          whereArgs: [patientId],
        );
      } else if (_dbType == 'mysql') {
        // 使用MySQL查询
        maps = await _queryMySQLData(
          'appointments',
          where: 'patient_id = ?',
          whereArgs: [patientId],
        );
      } else {
        throw Exception('不支持的数据库类型: $_dbType');
      }

      return List.generate(maps.length, (i) {
        return Appointment.fromMap(maps[i]);
      });
    } catch (e) {
      print('获取患者预约错误: $e');
      return [];
    }
  }

  // 复诊相关操作
  // 获取所有复诊
  Future<List<FollowUpVisit>> getAllFollowUpVisits() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('follow_up_visits');
    return List.generate(maps.length, (i) {
      return FollowUpVisit.fromMap(maps[i]);
    });
  }

  // 添加复诊
  Future<int> addFollowUpVisit(FollowUpVisit followUpVisit) async {
    final db = await _dbHelper.database;
    int id = await db.insert('follow_up_visits', followUpVisit.toMap());
    notifyListeners();
    return id;
  }

  // 更新复诊
  Future<int> updateFollowUpVisit(FollowUpVisit followUpVisit) async {
    final db = await _dbHelper.database;
    int result = await db.update(
      'follow_up_visits',
      followUpVisit.toMap(),
      where: 'id = ?',
      whereArgs: [followUpVisit.id],
    );
    notifyListeners();
    return result;
  }

  // 删除复诊
  Future<int> deleteFollowUpVisit(int id) async {
    final db = await _dbHelper.database;
    int result = await db.delete(
      'follow_up_visits',
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
    return result;
  }

  // 获取患者的所有复诊
  Future<List<FollowUpVisit>> getPatientFollowUpVisits(int patientId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'follow_up_visits',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );

    return List.generate(maps.length, (i) {
      return FollowUpVisit.fromMap(maps[i]);
    });
  }

  // 数据库配置相关操作
  // 导出数据库
  Future<String> exportDatabase() async {
    try {
      final dbPath = await _dbHelper.getDatabasePath();
      final directory = await getApplicationDocumentsDirectory();
      final exportPath = '${directory.path}/dental_clinic_export.db';

      // 复制数据库文件
      File dbFile = File(dbPath);
      await dbFile.copy(exportPath);

      return exportPath;
    } catch (e) {
      print('导出数据库错误: $e');
      return '';
    }
  }

  // 导入数据库
  Future<bool> importDatabase(String path) async {
    try {
      final dbPath = await _dbHelper.getDatabasePath();

      // 复制导入的数据库文件到应用数据库位置
      File importFile = File(path);
      await importFile.copy(dbPath);

      // 重新初始化数据库
      await initDatabase();

      return true;
    } catch (e) {
      print('导入数据库错误: $e');
      return false;
    }
  }

  // 测试MySQL连接，但不切换数据库类型
  Future<bool> testMySQLConnection(
    String host,
    String port,
    String database,
    String username,
    String password,
  ) async {
    try {
      print('测试MySQL连接...');

      // 检查并转换localhost为10.0.2.2（如果在Android平台）
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        print('Android连接检测到localhost参数，自动转换为10.0.2.2');
        effectiveHost = '10.0.2.2';
      }

      // 先测试Socket连接
      print('测试Socket连接到MySQL: $effectiveHost:$port');
      try {
        final socket = await Socket.connect(
          effectiveHost,
          int.parse(port),
          timeout: const Duration(seconds: 15),
          sourceAddress: InternetAddress.anyIPv4, // 指定使用IPv4地址
        );
        print('Socket连接成功，销毁临时Socket');
        socket.destroy();
      } catch (socketError) {
        print('Socket连接测试失败: $socketError');
        throw Exception('无法连接到MySQL服务器: $socketError');
      }

      // 创建临时连接设置
      final settings = mysql.ConnectionSettings(
        host: effectiveHost,
        port: int.parse(port),
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 20), // 增加超时时间，与正式连接保持一致
      );

      // 尝试连接
      print('尝试连接到MySQL: $effectiveHost:$port/$database (用户名: $username)');

      mysql.MySqlConnection? connection;

      // 增加重试机制
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount <= maxRetries) {
        try {
          print('连接尝试 ${retryCount + 1}/$maxRetries');
          connection = await mysql.MySqlConnection.connect(settings);
          break; // 连接成功，跳出循环
        } catch (e) {
          retryCount++;
          print('MySQL连接错误(尝试 $retryCount): $e');

          if (retryCount > maxRetries) {
            // 所有重试都失败
            if (e.toString().contains('SocketException')) {
              throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确，以及网络连接是否稳定');
            } else if (e.toString().contains('Access denied')) {
              throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
            } else if (e.toString().contains('Unknown database')) {
              throw Exception('数据库不存在，请检查数据库名称是否正确');
            } else {
              throw Exception('MySQL连接失败: $e');
            }
          }

          // 等待一段时间后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (connection == null) {
        throw Exception('无法建立MySQL连接，请检查网络连接或服务器状态');
      }

      // 测试连接
      try {
        final results = await connection.query('SELECT 1');
        if (results.isNotEmpty) {
          print('MySQL连接测试成功');
          // 关闭连接
          await connection.close();
          return true;
        } else {
          throw Exception('MySQL连接测试失败: 查询返回空结果');
        }
      } catch (e) {
        print('MySQL查询测试错误: $e');
        // 关闭连接
        if (connection != null) {
          await connection.close();
        }
        throw Exception('MySQL连接成功但查询测试失败: $e');
      }
    } catch (e) {
      print('MySQL连接测试错误: $e');
      return false;
    }
  }

  // 使用参数初始化MySQL连接
  Future<void> _initMySQLConnectionWithParams(
    String host,
    String port,
    String database,
    String username,
    String password,
  ) async {
    try {
      print('使用参数初始化MySQL连接...');

      // 首先关闭已有连接
      if (_mysqlConnection != null) {
        await _mysqlConnection!.close();
        _mysqlConnection = null;
      }

      // 检查参数
      if (host.isEmpty) {
        throw Exception('MySQL主机名为空');
      }

      // 检查并转换localhost为10.0.2.2（如果在Android平台）
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        print('Android连接检测到localhost参数，自动转换为10.0.2.2');
        effectiveHost = '10.0.2.2';
      }

      // 打印所有连接参数，帮助调试
      print(
        'MySQL连接参数: host=$effectiveHost (原始值:$host), port=$port, db=$database, user=$username',
      );

      // 对于Android模拟器，如果使用10.0.2.2，记录下来
      if (effectiveHost == "10.0.2.2") {
        print('使用Android模拟器特殊主机: 10.0.2.2 (模拟器中的localhost)');
      }

      // 先测试Socket连接
      print('测试Socket连接到MySQL: $effectiveHost:$port');
      try {
        final socket = await Socket.connect(
          effectiveHost,
          int.parse(port),
          timeout: const Duration(seconds: 15),
          sourceAddress: InternetAddress.anyIPv4, // 指定使用IPv4地址
        );
        print('Socket连接成功，销毁临时Socket');
        socket.destroy();
      } catch (socketError) {
        print('Socket连接测试失败: $socketError');
        throw Exception('无法连接到MySQL服务器: $socketError');
      }

      // 创建新连接设置
      final settings = mysql.ConnectionSettings(
        host: effectiveHost, // 使用可能转换后的主机名
        port: int.parse(port),
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 20), // 增加超时时间到20秒
      );

      // 尝试连接
      print('准备连接到MySQL: $effectiveHost:$port/$database');

      try {
        _mysqlConnection = await mysql.MySqlConnection.connect(settings);
      } catch (e) {
        print('MySQL连接错误: $e');
        if (e.toString().contains('SocketException')) {
          throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确');
        } else if (e.toString().contains('Access denied')) {
          throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
        } else if (e.toString().contains('Unknown database')) {
          throw Exception('数据库不存在，请检查数据库名称是否正确');
        } else {
          throw Exception('MySQL连接失败: $e');
        }
      }

      // 测试连接
      try {
        final results = await _mysqlConnection!.query('SELECT 1');
        if (results.isNotEmpty) {
          print('MySQL连接测试成功');
        } else {
          throw Exception('MySQL连接测试失败: 查询返回空结果');
        }
      } catch (e) {
        print('MySQL查询测试错误: $e');
        throw Exception('MySQL连接成功但查询测试失败: $e');
      }
    } catch (e) {
      print('MySQL连接错误: $e');
      _mysqlConnection = null;
      throw Exception('MySQL连接失败: $e');
    }
  }

  // 关闭数据库连接
  Future<void> closeDatabase() async {
    print('显式关闭数据库连接');
    try {
      // 关闭SQLite连接
      await _dbHelper.closeDatabase();

      // 关闭MySQL连接
      if (_mysqlConnection != null) {
        print('关闭MySQL连接');
        await _mysqlConnection!.close();
        _mysqlConnection = null;
      }

      // 清除缓存
      _cachedPatients = null;
      _cachedAppointments = null;
      _cachedDoctors = null;

      print('所有数据库连接已关闭');
    } catch (e) {
      print('关闭数据库连接错误: $e');
    }
  }

  // 分页获取患者
  Future<List<Patient>> getPatientsPage(
    int page,
    int pageSize, {
    String? sortField,
    bool? ascending,
  }) async {
    if (!_initialized) await initDatabase();
    return await _activeDataSource.getPatientsPage(
      page,
      pageSize,
      sortField: sortField,
      ascending: ascending,
    );
  }

  // 导出患者信息到Excel文件
  Future<String> exportPatientsToExcel(String filePath) async {
    try {
      print('开始导出患者数据到Excel');

      // 获取所有患者数据
      final patients = await getAllPatients();
      if (patients.isEmpty) {
        throw Exception('没有患者数据可导出');
      }

      // 创建Excel文件
      final excel = Excel.createExcel();
      final sheet = excel['患者信息'];

      // 设置表头
      final headers = [
        '姓名',
        '性别',
        '年龄',
        '主电话号',
        '备用电话号',
        '地址',
        '身份证号',
        '病历号',
        '医生',
        '初诊日期',
        '总费用',
        '牙齿状况',
      ];

      // 设置表头样式
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // 填充数据
      for (var i = 0; i < patients.length; i++) {
        final patient = patients[i];
        final rowIndex = i + 1;

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient.name);
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient.gender);
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = IntCellValue(patient.age);

        // 处理电话号码 - 分为主电话号和备用电话号两列
        String mainPhone = '';
        String backupPhone = '';

        print('处理患者[${patient.name}]的电话: ${patient.phone}');

        try {
          if (patient.phone.contains(",")) {
            // 可能是JSON格式，尝试解析
            if (patient.phone.startsWith('[') && patient.phone.endsWith(']')) {
              List<dynamic> phones = jsonDecode(patient.phone);
              if (phones.isNotEmpty) {
                mainPhone = phones[0].toString();
                if (phones.length > 1) {
                  backupPhone = phones[1].toString();
                }
                print('成功解析JSON电话: 主号=$mainPhone, 备用=$backupPhone');
              }
            } else {
              // 可能是逗号分隔的格式
              List<String> phones = patient.phone.split(',');
              if (phones.isNotEmpty) {
                mainPhone = phones[0].trim();
                if (phones.length > 1) {
                  backupPhone = phones[1].trim();
                }
                print('成功解析逗号分隔电话: 主号=$mainPhone, 备用=$backupPhone');
              }
            }
          } else {
            // 单个电话号码
            mainPhone = patient.phone;
            print('单个电话号码: $mainPhone');
          }
        } catch (e) {
          print('解析电话号码失败: $e, 使用原始值');
          mainPhone = patient.phone; // 如果解析失败，将整个字段作为主电话
        }

        // 主电话号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(mainPhone);

        // 备用电话号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = TextCellValue(backupPhone);

        // 地址
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient.address ?? '');

        // 身份证号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient.identificationNumber ?? '');

        // 病历号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            )
            .value = patient.medicalRecordNumber != null
                ? IntCellValue(patient.medicalRecordNumber!)
                : TextCellValue('');

        // 医生
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient.doctor ?? '');

        // 初诊日期
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          DateFormat('yyyy-MM-dd').format(patient.firstVisitDate),
        );

        // 总费用
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(patient.totalCost);

        // 牙齿状况
        String dentalData = '';
        if (patient.dentalCondition != null &&
            patient.dentalCondition!.isNotEmpty) {
          try {
            if (patient.dentalCondition!.startsWith('{') ||
                patient.dentalCondition!.startsWith('[')) {
              // 尝试解析JSON格式
              Map<String, dynamic> dentalJson = jsonDecode(
                patient.dentalCondition!,
              );
              dentalData = convertDentalJsonToText(dentalJson);
              print('解析JSON牙齿状况数据成功');
            } else {
              // 使用普通格式化
              dentalData = formatDentalCondition(patient.dentalCondition!);
              print('使用普通格式化处理牙齿状况数据');
            }
          } catch (e) {
            print('处理牙齿状况失败: $e, 使用原始数据');
            dentalData = patient.dentalCondition!;
          }
        }

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex),
            )
            .value = TextCellValue(dentalData);
      }

      // 自动调整列宽
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnAutoFit(i);
      }

      // 保存Excel文件
      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        print('Excel文件已保存到: $filePath');
        return filePath;
      } else {
        throw Exception('Excel编码失败');
      }
    } catch (e) {
      print('导出Excel文件错误: $e');
      throw Exception('导出Excel文件错误: $e');
    }
  }

  // 将牙齿状况JSON转换为易读文本
  String convertDentalJsonToText(Map<String, dynamic> jsonData) {
    StringBuffer buffer = StringBuffer();

    // 处理日期
    if (jsonData.containsKey('date-0')) {
      buffer.writeln('检查日期: ${jsonData['date-0']}');
    }

    // 处理图表1
    buffer.writeln('\n图表1');
    if (jsonData.containsKey('chart1-top-left-0')) {
      buffer.writeln('左上: ${jsonData['chart1-top-left-0']}');
    }
    if (jsonData.containsKey('chart1-top-right-0')) {
      buffer.writeln('右上: ${jsonData['chart1-top-right-0']}');
    }
    if (jsonData.containsKey('chart1-bottom-left-0')) {
      buffer.writeln('左下: ${jsonData['chart1-bottom-left-0']}');
    }
    if (jsonData.containsKey('chart1-bottom-right-0')) {
      buffer.writeln('右下: ${jsonData['chart1-bottom-right-0']}');
    }

    // 处理图表2
    buffer.writeln('\n图表2');
    if (jsonData.containsKey('chart2-top-left-0')) {
      buffer.writeln('左上: ${jsonData['chart2-top-left-0']}');
    }
    if (jsonData.containsKey('chart2-top-right-0')) {
      buffer.writeln('右上: ${jsonData['chart2-top-right-0']}');
    }
    if (jsonData.containsKey('chart2-bottom-left-0')) {
      buffer.writeln('左下: ${jsonData['chart2-bottom-left-0']}');
    }
    if (jsonData.containsKey('chart2-bottom-right-0')) {
      buffer.writeln('右下: ${jsonData['chart2-bottom-right-0']}');
    }

    return buffer.toString();
  }

  // 格式化牙齿状况信息，使其更易读
  String formatDentalCondition(String dentalCondition) {
    if (dentalCondition.isEmpty) return '';

    try {
      // 分行处理
      List<String> lines = dentalCondition.split('\n');
      List<String> formattedLines = [];

      // 日期行处理
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();

        // 提取日期
        if (line.startsWith('日期:')) {
          String date = line.substring(3).trim();
          formattedLines.add('检查日期: $date');
          continue;
        }

        // 处理图表行
        if (line.startsWith('图表')) {
          String chartName = line.substring(0, line.length - 1); // 去掉末尾冒号
          formattedLines.add('\n$chartName');

          // 收集该图表下的所有数据
          List<String> chartData = [];
          int j = i + 1;
          while (j < lines.length &&
              lines[j].trim().isNotEmpty &&
              !lines[j].trim().startsWith('图表')) {
            String dataLine = lines[j].trim();

            // 格式化每个位置的数据
            if (dataLine.startsWith('左上:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('左上: $value');
            } else if (dataLine.startsWith('右上:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('右上: $value');
            } else if (dataLine.startsWith('左下:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('左下: $value');
            } else if (dataLine.startsWith('右下:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('右下: $value');
            } else {
              chartData.add(dataLine);
            }
            j++;
          }

          // 将图表数据添加到格式化行中
          formattedLines.addAll(chartData);
          i = j - 1; // 更新循环索引
        } else if (line.isNotEmpty) {
          // 其他内容直接添加
          formattedLines.add(line);
        }
      }

      // 合并所有行
      return formattedLines.join('\n');
    } catch (e) {
      print('格式化牙齿状况失败: $e');
      return dentalCondition; // 如果格式化失败，返回原始字符串
    }
  }

  // 强制刷新患者数据缓存
  Future<void> forceRefreshPatients() async {
    print('强制刷新患者数据缓存');
    _cachedPatients = null;

    // 清除数据源缓存
    try {
      if (_dbType == 'sqlite') {
        // 测试SQLite连接
        try {
          print('确保SQLite连接正常');
          final db = await _dbHelper.database;
          final dbIsOk = await db.rawQuery('SELECT 1');
          print('SQLite连接测试结果: $dbIsOk');
        } catch (e) {
          print('SQLite连接测试失败: $e');
        }
      } else if (_dbType == 'mysql') {
        // 刷新MySQL连接
        try {
          if (_mysqlConnection != null) {
            // 如果当前连接可能已经关闭或超时，尝试关闭并重新连接
            await _mysqlConnection!.close();
            _mysqlConnection = null;
          }
          await _initMySQLConnection();
          print('已刷新MySQL连接');
        } catch (e) {
          print('刷新MySQL连接失败: $e');
        }
      }
    } catch (e) {
      print('刷新患者数据缓存错误: $e');
    }
  }

  // 预约相关操作
  // 获取所有预约
  Future<List<Appointment>> getAllAppointments() async {
    try {
      // 如果有缓存，直接返回
      if (_cachedAppointments != null) {
        return _cachedAppointments!;
      }

      // 根据数据源类型获取数据
      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        final maps = await db.query('appointments');
        _cachedAppointments = List.generate(maps.length, (i) {
          return Appointment.fromMap(maps[i]);
        });
      } else if (_dbType == 'mysql') {
        // 确保MySQL连接可用
        if (_mysqlConnection == null) {
          await _initMySQLConnection();
          if (_mysqlConnection == null) {
            throw Exception('MySQL连接不可用');
          }
        }

        final results = await _mysqlConnection!.query(
          'SELECT * FROM appointments',
        );

        // 将MySQL结果转换为Appointment对象
        _cachedAppointments = [];
        for (var row in results) {
          try {
            final map = <String, dynamic>{};
            for (var field in row.fields.keys) {
              // 特殊处理日期字段，确保它们被正确处理
              if (field == 'appointment_date' ||
                  field == 'created_at' ||
                  field == 'updated_at') {
                // 如果是日期类型，先转换为字符串格式
                if (row[field] is DateTime) {
                  // 转换为ISO 8601格式字符串
                  map[field] = (row[field] as DateTime).toIso8601String();
                } else {
                  map[field] = row[field]?.toString();
                }
              } else {
                map[field] = row[field];
              }
            }
            print('处理预约记录: $map');
            _cachedAppointments!.add(Appointment.fromMap(map));
          } catch (e) {
            print('转换MySQL预约数据错误: $e');
            print('错误数据: ${row.fields}');
          }
        }
      }

      return _cachedAppointments!;
    } catch (e) {
      print('获取预约数据错误: $e');
      return [];
    }
  }

  // 获取预约总数
  Future<int> getAppointmentCount() async {
    try {
      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        final count =
            Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM appointments'),
            ) ??
            0;
        print('SQLite预约计数查询结果: $count');
        return count;
      } else if (_dbType == 'mysql') {
        print('使用MySQL查询预约总数');
        // 确保MySQL连接可用
        if (_mysqlConnection == null) {
          await _initMySQLConnection();
          if (_mysqlConnection == null) {
            throw Exception('MySQL连接不可用');
          }
        }

        final results = await _mysqlConnection!.query(
          'SELECT COUNT(*) AS count FROM appointments',
        );
        if (results.isEmpty) {
          print('警告：MySQL预约计数查询返回空结果');
          return 0;
        }

        final count = results.first['count'] as int;
        print('MySQL预约计数查询结果: $count');
        return count;
      } else {
        throw Exception('不支持的数据库类型: $_dbType');
      }
    } catch (e) {
      print('获取预约数量错误: $e');
      return 0;
    }
  }

  // 获取今日预约
  Future<List<Appointment>> getTodayAppointments() async {
    try {
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      List<Map<String, dynamic>> maps;

      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        maps = await db.rawQuery(
          "SELECT * FROM appointments WHERE appointment_date LIKE '$today%'",
        );
      } else if (_dbType == 'mysql') {
        // MySQL的日期比较语法有所不同
        maps = await _queryMySQLData(
          'appointments',
          where: "DATE(appointment_date) = ?",
          whereArgs: [today],
        );
      } else {
        throw Exception('不支持的数据库类型: $_dbType');
      }

      return List.generate(maps.length, (i) {
        return Appointment.fromMap(maps[i]);
      });
    } catch (e) {
      print('获取今日预约错误: $e');
      return [];
    }
  }

  // 添加预约
  Future<int> addAppointment(Appointment appointment) async {
    int id = 0;

    try {
      if (_dbType == 'sqlite') {
        // SQLite方式添加预约
        final db = await _dbHelper.database;
        id = await db.insert('appointments', appointment.toMap());
        print('SQLite添加预约成功，ID: $id');
      } else if (_dbType == 'mysql') {
        // MySQL方式添加预约
        print('使用MySQL添加预约...');

        // 确保MySQL连接可用
        if (_mysqlConnection == null) {
          await _initMySQLConnection();
          if (_mysqlConnection == null) {
            throw Exception('MySQL连接不可用');
          }
        }

        // 准备数据并排除id字段（让MySQL自动生成）
        final data = appointment.toMap();
        if (data['id'] == null) {
          data.remove('id');
        }

        // 打印SQL语句和数据（调试用）
        print('准备插入MySQL预约数据: $data');

        // 转换日期字段
        String appointmentDate = _formatDateForMySQL(data['appointment_date']);
        String createdAt = _formatDateForMySQL(data['created_at']);
        String updatedAt = _formatDateForMySQL(data['updated_at']);

        print(
          '转换后的日期：appointment_date=$appointmentDate, created_at=$createdAt, updated_at=$updatedAt',
        );

        // 执行MySQL插入
        var result = await _mysqlConnection!.query(
          'INSERT INTO appointments (patient_id, appointment_date, status, treatment_type, notes, cost, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            data['patient_id'],
            appointmentDate, // 使用转换后的日期格式
            data['status'],
            data['treatment_type'],
            data['notes'],
            data['cost'],
            createdAt, // 使用转换后的日期格式
            updatedAt, // 使用转换后的日期格式
          ],
        );

        // 获取插入的ID
        try {
          if (result.insertId != null) {
            // 尝试将insertId转换为int
            id = int.parse(result.insertId.toString());
          }
        } catch (e) {
          print('获取MySQL插入ID错误: $e，使用默认ID 0');
        }

        print('MySQL添加预约成功，ID: $id');
      } else {
        throw Exception('不支持的数据库类型: $_dbType');
      }

      // 清除预约缓存
      _cachedAppointments = null;
      // 设置仪表盘需要刷新标志
      _dashboardNeedsRefresh = true;
      print('预约数据已添加，缓存已清除，仪表盘需要刷新');

      return id;
    } catch (e) {
      print('添加预约错误: $e');
      rethrow; // 重新抛出异常让调用者知道发生了错误
    }
  }

  // 更新预约
  Future<int> updateAppointment(Appointment appointment) async {
    if (appointment.id == null) {
      throw Exception('更新预约需要有效的ID');
    }

    int result = 0;

    try {
      if (_dbType == 'sqlite') {
        // SQLite方式更新预约
        final db = await _dbHelper.database;
        result = await db.update(
          'appointments',
          appointment.toMap(),
          where: 'id = ?',
          whereArgs: [appointment.id],
        );
        print('SQLite更新预约成功，ID: ${appointment.id}, 影响行数: $result');
      } else if (_dbType == 'mysql') {
        // MySQL方式更新预约
        print('使用MySQL更新预约...');

        // 确保MySQL连接可用
        if (_mysqlConnection == null) {
          await _initMySQLConnection();
          if (_mysqlConnection == null) {
            throw Exception('MySQL连接不可用');
          }
        }

        // 准备数据
        final data = appointment.toMap();

        // 打印SQL参数（调试用）
        print('准备更新MySQL预约，ID: ${appointment.id}, 数据: $data');

        // 转换日期字段
        String appointmentDate = _formatDateForMySQL(data['appointment_date']);
        String updatedAt = _formatDateForMySQL(data['updated_at']);

        print(
          '转换后的日期：appointment_date=$appointmentDate, updated_at=$updatedAt',
        );

        // 执行MySQL更新
        var response = await _mysqlConnection!.query(
          'UPDATE appointments SET patient_id = ?, appointment_date = ?, status = ?, treatment_type = ?, notes = ?, cost = ?, updated_at = ? WHERE id = ?',
          [
            data['patient_id'],
            appointmentDate, // 使用转换后的日期格式
            data['status'],
            data['treatment_type'],
            data['notes'],
            data['cost'],
            updatedAt, // 使用转换后的日期格式
            appointment.id,
          ],
        );

        try {
          result = response.affectedRows ?? 0;
        } catch (e) {
          print('获取MySQL影响行数错误: $e，假设成功更新1行');
          result = 1; // 假设成功更新了一行
        }

        print('MySQL更新预约成功，ID: ${appointment.id}, 影响行数: $result');
      } else {
        throw Exception('不支持的数据库类型: $_dbType');
      }

      // 清除预约缓存
      _cachedAppointments = null;
      // 设置仪表盘需要刷新标志
      _dashboardNeedsRefresh = true;
      print('预约数据已更新，缓存已清除，仪表盘需要刷新');

      return result;
    } catch (e) {
      print('更新预约错误: $e');
      rethrow; // 重新抛出异常让调用者知道发生了错误
    }
  }

  // 删除预约
  Future<int> deleteAppointment(int id) async {
    int result = 0;

    try {
      if (_dbType == 'sqlite') {
        // SQLite方式删除预约
        final db = await _dbHelper.database;
        result = await db.delete(
          'appointments',
          where: 'id = ?',
          whereArgs: [id],
        );
        print('SQLite删除预约成功，ID: $id, 影响行数: $result');
      } else if (_dbType == 'mysql') {
        // MySQL方式删除预约
        print('使用MySQL删除预约，ID: $id...');

        // 确保MySQL连接可用
        if (_mysqlConnection == null) {
          await _initMySQLConnection();
          if (_mysqlConnection == null) {
            throw Exception('MySQL连接不可用');
          }
        }

        // 执行MySQL删除
        var response = await _mysqlConnection!.query(
          'DELETE FROM appointments WHERE id = ?',
          [id],
        );

        try {
          result = response.affectedRows ?? 0;
        } catch (e) {
          print('获取MySQL影响行数错误: $e，假设成功删除1行');
          result = 1; // 假设成功删除了一行
        }

        print('MySQL删除预约成功，ID: $id, 影响行数: $result');
      } else {
        throw Exception('不支持的数据库类型: $_dbType');
      }

      // 清除预约缓存
      _cachedAppointments = null;
      // 设置仪表盘需要刷新标志
      _dashboardNeedsRefresh = true;
      print('预约数据已删除，缓存已清除，仪表盘需要刷新');

      return result;
    } catch (e) {
      print('删除预约错误: $e');
      rethrow; // 重新抛出异常让调用者知道发生了错误
    }
  }

  // 根据查询条件搜索患者
  Future<List<Patient>> searchPatients(String query) async {
    if (!_initialized) await initDatabase();
    return await _activeDataSource.searchPatients(query);
  }

  // 获取某个患者不在页面中显示的其他预约列表
  Future<List<Appointment>> getOtherAppointmentsForPatient(
    int patientId,
  ) async {
    try {
      List<Map<String, dynamic>> maps;

      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        maps = await db.query(
          'appointments',
          where: 'patient_id != ?',
          whereArgs: [patientId],
        );
      } else if (_dbType == 'mysql') {
        // 使用MySQL查询
        maps = await _queryMySQLData(
          'appointments',
          where: 'patient_id != ?',
          whereArgs: [patientId],
        );
      } else {
        throw Exception('不支持的数据库类型: $_dbType');
      }

      return List.generate(maps.length, (i) {
        return Appointment.fromMap(maps[i]);
      });
    } catch (e) {
      print('获取患者预约错误: $e');
      return [];
    }
  }

  // 获取最后一位患者
  Future<Patient?> getLastPatient() async {
    try {
      if (_dbType == 'sqlite') {
        final db = await _dbHelper.database;
        if (db != null) {
          final List<Map<String, dynamic>> maps = await db.query(
            'patients',
            orderBy: 'medical_record_number DESC',
            limit: 1,
          );
          if (maps.isNotEmpty) {
            return Patient.fromMap(maps.first);
          }
        }
      } else if (_dbType == 'mysql') {
        final conn = await _mysqlConnection;
        if (conn != null) {
          final results = await conn.query(
            'SELECT * FROM patients ORDER BY medical_record_number DESC LIMIT 1',
          );
          if (results.isNotEmpty) {
            return Patient.fromMap(results.first.fields);
          }
        }
      }
      return null;
    } catch (e) {
      print('获取最后一位患者错误: $e');
      return null;
    }
  }
}

// 抽象数据源接口
abstract class DataSource {
  Future<int> addPatient(Patient patient);
  Future<bool> updatePatient(Patient patient);
  Future<int> deletePatient(int id);
  Future<Patient?> getPatientById(int id);
  Future<List<Patient>> getAllPatients();
  Future<List<Patient>> getPatientsPage(
    int page,
    int pageSize, {
    String? sortField,
    bool? ascending,
  });
  Future<List<Patient>> searchPatients(String query);
  Future<int> getPatientCount();
  // 其他数据库操作方法...
}

// SQLite实现
class SqliteDataSource implements DataSource {
  final DatabaseProvider _provider;

  SqliteDataSource(this._provider);

  Future<Database> get _database async => await _provider._dbHelper.database;

  @override
  Future<int> addPatient(Patient patient) async {
    final db = await _database;

    // 自动生成拼音
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    // 确保更新时间是最新的
    patient.updatedAt = DateTime.now();

    print('添加患者 - 名称拼音: ${patient.namePinyin}');
    print('添加患者 - 姓名首字母: ${patient.nameInitials}');
    print('添加患者 - 地址拼音: ${patient.addressPinyin}');

    return await db.insert('patients', patient.toMap());
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    final db = await _database;

    // 自动更新拼音
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    // 更新修改时间
    patient.updatedAt = DateTime.now();

    print('更新患者 - 名称拼音: ${patient.namePinyin}');
    print('更新患者 - 姓名首字母: ${patient.nameInitials}');
    print('更新患者 - 地址拼音: ${patient.addressPinyin}');

    final rowsAffected = await db.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
    print('SQLite更新患者结果: 影响了 $rowsAffected 行');
    return rowsAffected > 0;
  }

  @override
  Future<int> deletePatient(int id) async {
    final db = await _database;
    try {
      // 使用事务确保原子性
      return await db.transaction((txn) async {
        // 删除患者 - 此时调用此方法时，关联预约已经在DatabaseProvider中被删除
        final result = await txn.delete(
          'patients',
          where: 'id = ?',
          whereArgs: [id],
        );
        print('SQLite删除患者结果: 影响了 $result 行');
        return result;
      });
    } catch (e) {
      print('SQLite删除患者错误: $e');
      rethrow;
    }
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    final db = await _database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Patient.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<Patient>> getAllPatients() async {
    final db = await _database;
    final maps = await db.query('patients', orderBy: 'name');
    return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
  }

  @override
  Future<List<Patient>> getPatientsPage(
    int page,
    int pageSize, {
    String? sortField,
    bool? ascending,
  }) async {
    final db = await _database;
    final offset = (page - 1) * pageSize;

    String orderBy = 'updated_at DESC';

    // 基于排序字段和排序方向设置orderBy
    if (sortField != null) {
      switch (sortField) {
        case 'age':
          orderBy = 'age ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'medical_record':
          orderBy =
              'medical_record_number ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'updated':
          orderBy = 'updated_at ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'name':
          orderBy = 'name ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        default:
          orderBy = 'updated_at DESC';
      }
    }

    final maps = await db.query(
      'patients',
      limit: pageSize,
      offset: offset,
      orderBy: orderBy,
    );
    print('SQLite分页查询获取到 ${maps.length} 条患者数据，排序: $orderBy');

    List<Patient> patients = [];
    for (var map in maps) {
      try {
        Patient patient = Patient.fromMap(map);
        patients.add(patient);
      } catch (e) {
        print('转换患者对象错误: $e, 数据: $map');
      }
    }

    return patients;
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    if (query.isEmpty) {
      return await getAllPatients();
    }

    final db = await _database;
    final lowercaseQuery = query.toLowerCase();

    // 为拼音搜索创建另一个不带空格的查询条件
    final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');

    // 构建搜索SQL - 增加对拼音搜索的支持，包括无空格的情况和首字母搜索
    final where = '''
      name LIKE ? OR 
      phone LIKE ? OR
      address LIKE ? OR
      identification_number LIKE ? OR
      (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR name_pinyin LIKE ? OR replace(name_pinyin, ' ', '') LIKE ?)) OR
      (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR address_pinyin LIKE ? OR replace(address_pinyin, ' ', '') LIKE ?)) OR
      (name_initials IS NOT NULL AND name_initials LIKE ?) OR
      (cast(medical_record_number as TEXT) LIKE ?)
    ''';

    // 为每个搜索条件添加模糊匹配参数
    final whereArgs = [
      '%$lowercaseQuery%', // name
      '%$lowercaseQuery%', // phone
      '%$lowercaseQuery%', // address
      '%$lowercaseQuery%', // identification_number
      '%$lowercaseQuery%', // name_pinyin
      '%$noSpaceQuery%', // name_pinyin (无空格)
      '%$lowercaseQuery%', // name_pinyin 中移除空格后匹配
      '%$lowercaseQuery%', // address_pinyin
      '%$noSpaceQuery%', // address_pinyin (无空格)
      '%$lowercaseQuery%', // address_pinyin 中移除空格后匹配
      '%$lowercaseQuery%', // name_initials
      '%$lowercaseQuery%', // medical_record_number
    ];

    final maps = await db.query('patients', where: where, whereArgs: whereArgs);
    print('SQLite搜索查询获取到 ${maps.length} 条患者数据');

    List<Patient> patients = [];
    for (var map in maps) {
      try {
        Patient patient = Patient.fromMap(map);
        patients.add(patient);
      } catch (e) {
        print('转换患者对象错误: $e, 数据: $map');
      }
    }

    // 添加结果去重逻辑
    Map<int?, Patient> uniquePatients = {};
    for (var patient in patients) {
      if (patient.id != null) {
        uniquePatients[patient.id] = patient;
      }
    }

    return uniquePatients.values.toList();
  }

  @override
  Future<int> getPatientCount() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM patients');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

// MySQL实现
class MySqlDataSource implements DataSource {
  final DatabaseProvider _provider;

  MySqlDataSource(this._provider);

  mysql.MySqlConnection? get _connection => _provider._mysqlConnection;

  Future<mysql.MySqlConnection> get _ensuredConnection async {
    if (_connection == null) {
      await _provider._initMySQLConnection();
      if (_provider._mysqlConnection == null) {
        throw Exception('MySQL连接不可用');
      }
    }
    return _provider._mysqlConnection!;
  }

  // MySQL专用方法 - 格式化日期
  String _formatDateForMySQL(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
    } catch (e) {
      print('日期格式化错误: $e');
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    }
  }

  // 安全获取MySQL结果中的字段值
  dynamic _getSafeValue(dynamic row, String fieldName) {
    try {
      return row[fieldName];
    } catch (e) {
      print('获取MySQL字段 $fieldName 错误: $e');
      return null;
    }
  }

  // 处理电话号码字段，确保正确的JSON格式
  String _processPhoneField(String phoneValue, {int maxLength = 100}) {
    print('处理MySQL电话号码: $phoneValue');

    // 检查是否为空
    if (phoneValue.isEmpty) {
      return phoneValue;
    }

    // 如果不包含特殊字符，可能是单个电话号码，直接返回
    if (!phoneValue.contains('[') &&
        !phoneValue.contains('"') &&
        !phoneValue.contains('\\') &&
        !phoneValue.contains(',')) {
      print('检测到单个电话号码，直接使用: $phoneValue');
      return phoneValue;
    }

    // 特殊模式检测 - 捕获特定的错误模式 ["[\"999\"","\"000\"]"]
    if (phoneValue.contains(r'[\"') && phoneValue.contains(r'\"]')) {
      try {
        print('检测到特殊错误格式: $phoneValue');
        List<String> extractedPhones = [];

        // 尝试先解码外层JSON
        try {
          List<dynamic> outerList = jsonDecode(phoneValue);
          for (var item in outerList) {
            String str = item.toString();
            // 提取实际电话号码 (去除所有引号、括号和转义符)
            str =
                str
                    .replaceAll(r'\"', '')
                    .replaceAll(r'\\', '')
                    .replaceAll(r'[', '')
                    .replaceAll(r']', '')
                    .replaceAll('"', '')
                    .trim();
            if (str.isNotEmpty) {
              extractedPhones.add(str);
            }
          }
        } catch (jsonError) {
          print('解析外层JSON失败，尝试直接提取数字: $jsonError');
          // 使用正则表达式直接提取电话号码
          RegExp digitPattern = RegExp(r'\d+');
          Iterable<Match> matches = digitPattern.allMatches(phoneValue);
          for (Match match in matches) {
            String phone = match.group(0) ?? '';
            if (phone.length >= 3) {
              // 确保它是电话号码，而不是随机数字
              extractedPhones.add(phone);
            }
          }
        }

        // 如果只提取出一个电话号码，直接返回该号码
        if (extractedPhones.length == 1) {
          print('从特殊格式中提取出单个电话号码: ${extractedPhones[0]}');
          return extractedPhones[0];
        }

        // 如果成功提取了多个电话，重新编码为JSON并返回
        if (extractedPhones.isNotEmpty) {
          String result = jsonEncode(extractedPhones);
          print('修复特殊错误格式后: $result');
          return result;
        }
      } catch (e) {
        print('修复特殊错误格式失败: $e');
        // 继续使用其他方法处理
      }
    }

    // 处理特殊情况：["[\"999\"","\"000\"]"]格式，这是典型的双重JSON编码问题
    if (phoneValue.contains(r'\"') && phoneValue.contains(r'[\"')) {
      try {
        // 首先解码外层JSON
        List<dynamic> outerList = jsonDecode(phoneValue);
        List<String> cleanPhones = [];

        // 处理每一项
        for (var item in outerList) {
          String str = item.toString();
          // 去除引号和转义符号
          str = str.replaceAll(r'\"', '').replaceAll(r'\\', '');
          if (str.isNotEmpty) {
            cleanPhones.add(str);
          }
        }

        // 如果只有一个电话号码，直接返回
        if (cleanPhones.length == 1) {
          print('从双重编码中提取出单个电话号码: ${cleanPhones[0]}');
          return cleanPhones[0];
        }

        // 有多个电话号码，重新编码为JSON格式
        String result = jsonEncode(cleanPhones);
        print('修复双重编码后的多个电话号码: $result');
        return result;
      } catch (e) {
        print('修复双重编码失败: $e');
        // 继续尝试其他方法处理
      }
    }

    // 处理普通的JSON格式
    if (phoneValue.startsWith('[') && phoneValue.endsWith(']')) {
      try {
        // 尝试解析JSON
        List<dynamic> phoneList = jsonDecode(phoneValue);

        // 如果只有一个电话号码，直接返回该电话号码字符串，不使用JSON格式
        if (phoneList.length == 1) {
          String singlePhone = phoneList[0].toString();
          print('JSON中只有一个电话号码，直接返回: $singlePhone');
          return singlePhone;
        }

        // 有多个电话号码，确保格式正确
        List<String> cleanPhones = phoneList.map((p) => p.toString()).toList();
        String result = jsonEncode(cleanPhones);

        // 检查长度限制
        if (result.length > maxLength) {
          // 如果太长，尝试只保留第一个电话号码
          print('JSON格式电话号码过长，截断为第一个号码');
          return cleanPhones[0];
        }

        print('处理后的多个电话号码: $result');
        return result;
      } catch (e) {
        print('处理JSON电话号码错误: $e');

        // 解析错误时，尝试提取数字
        try {
          // 去除JSON格式符号
          String content = phoneValue
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .replaceAll('\\', '');

          // 按逗号分割
          List<String> parts =
              content
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .toList();

          if (parts.length == 1) {
            // 只有一个电话号码
            print('解析后获得单个电话号码: ${parts[0]}');
            return parts[0];
          } else if (parts.length > 1) {
            // 多个电话号码
            String result = jsonEncode(parts);
            print('解析后获得多个电话号码: $result');
            return result;
          }
        } catch (parseError) {
          print('提取电话号码失败: $parseError');
        }

        // 如果其他处理都失败，尝试直接返回原始值
        if (phoneValue.length > maxLength) {
          return phoneValue.substring(0, maxLength);
        }
        return phoneValue;
      }
    }

    // 处理逗号分隔的电话号码
    if (phoneValue.contains(',')) {
      List<String> phones =
          phoneValue
              .split(',')
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();

      if (phones.length == 1) {
        // 只有一个有效的电话号码
        print('从逗号分隔格式中提取出单个电话号码: ${phones[0]}');
        return phones[0];
      } else if (phones.length > 1) {
        // 有多个电话号码
        String result = jsonEncode(phones);
        print('从逗号分隔格式中获得多个电话号码: $result');
        return result;
      }
    }

    // 如果所有处理都失败，返回原始值
    return phoneValue;
  }

  // 准备MySQL患者数据
  Map<String, dynamic> _prepareMySQLPatientData(Patient patient) {
    final map = patient.toMap();

    // 移除id字段，MySQL会自动生成
    if (map['id'] == null) {
      map.remove('id');
    }

    // 处理性别字段 - 直接使用中文格式存储，不再转换为英文
    if (map['gender'] != '男' && map['gender'] != '女') {
      // 如果不是标准的"男"或"女"，尝试规范化
      String gender = map['gender']?.toString().toLowerCase() ?? '';
      if (gender == 'male' || gender == '1' || gender == 'm') {
        map['gender'] = '男';
      } else if (gender == 'female' || gender == '0' || gender == 'f') {
        map['gender'] = '女';
      } else {
        // 默认设置为男
        map['gender'] = '男';
      }
    }

    // 处理日期字段
    map['first_visit_date'] = _formatDateForMySQL(map['first_visit_date']);
    map['created_at'] = _formatDateForMySQL(map['created_at']);
    map['updated_at'] = _formatDateForMySQL(map['updated_at']);

    // 处理电话号码字段 - 确保不会发生双重编码
    if (map.containsKey('phone') && map['phone'] != null) {
      // 警告：此处跟踪一下phone的状态用于调试
      print('原始phone字段数据: ${map['phone']}');

      String rawPhone = map['phone'].toString();

      // 如果不包含特殊字符，可能是单个电话号码，直接使用
      if (!rawPhone.contains('[') &&
          !rawPhone.contains('"') &&
          !rawPhone.contains('\\') &&
          !rawPhone.contains(',')) {
        print('单个电话号码，直接使用: $rawPhone');
        map['phone'] = rawPhone;
      }
      // 检查是否已经是JSON字符串
      else if (rawPhone.startsWith('[') && rawPhone.endsWith(']')) {
        try {
          // 尝试解析，确保是有效的JSON
          List<dynamic> phoneList = jsonDecode(rawPhone);

          // 如果只有一个电话号码，直接使用该电话号码
          if (phoneList.length == 1) {
            map['phone'] = phoneList[0].toString();
            print('JSON中只有一个电话号码，提取为字符串: ${map['phone']}');
          } else {
            // 多个电话号码，重新编码为JSON
            map['phone'] = jsonEncode(phoneList);
            print('多个电话号码，使用JSON格式: ${map['phone']}');
          }
        } catch (e) {
          // 如果解析失败，说明可能不是有效的JSON，使用_processPhoneField处理
          map['phone'] = _processPhoneField(rawPhone);
          print('处理无效JSON或普通电话字符串: ${map['phone']}');
        }
      } else {
        // 不是JSON格式，可能是单个电话号码或逗号分隔的多个电话号码
        map['phone'] = _processPhoneField(rawPhone);
        print('处理非JSON格式的电话号码: ${map['phone']}');
      }
    }

    return map;
  }

  @override
  Future<int> addPatient(Patient patient) async {
    // 自动生成拼音
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    // 确保更新时间是最新的
    patient.updatedAt = DateTime.now();

    print('添加患者 - 名称拼音: ${patient.namePinyin}');
    print('添加患者 - 姓名首字母: ${patient.nameInitials}');
    print('添加患者 - 地址拼音: ${patient.addressPinyin}');

    // 确保连接可用
    final conn = await _ensuredConnection;

    // 准备数据
    final data = _prepareMySQLPatientData(patient);
    print('准备MySQL患者数据: $data');

    // 构建插入语句
    final fields = data.keys.join(', ');
    final placeholders = List.filled(data.keys.length, '?').join(', ');
    final values = data.values.toList();

    // 执行插入
    final result = await conn.query(
      'INSERT INTO patients ($fields) VALUES ($placeholders)',
      values,
    );

    // 获取插入ID
    try {
      if (result.insertId != null) {
        return int.parse(result.insertId.toString());
      }
    } catch (e) {
      print('解析MySQL插入ID错误: $e');
    }

    return 0;
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    // 自动更新拼音
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    patient.updatedAt = DateTime.now();

    print('更新患者 - 名称拼音: ${patient.namePinyin}');
    print('更新患者 - 姓名首字母: ${patient.nameInitials}');
    print('更新患者 - 地址拼音: ${patient.addressPinyin}');

    // 确保连接可用
    final conn = await _ensuredConnection;

    // 准备数据
    final data = _prepareMySQLPatientData(patient);
    final id = patient.id;
    data.remove('id'); // 从更新数据中移除ID

    print('准备MySQL更新数据: $data');

    try {
      // 构建SET子句
      final setClause = data.keys.map((key) => '$key = ?').join(', ');
      final params = [...data.values, id];

      // 执行更新
      final result = await conn.query(
        'UPDATE patients SET $setClause WHERE id = ?',
        params,
      );

      print('MySQL更新患者结果: 影响了 ${result.affectedRows} 行');
      return result.affectedRows! > 0;
    } catch (e) {
      print('MySQL更新错误: $e，尝试使用基本字段');

      // 备用方案：使用最基本字段
      try {
        final basicResult = await conn.query(
          'UPDATE patients SET name = ?, age = ?, gender = ?, phone = ?, '
          'address = ?, doctor = ?, name_pinyin = ?, address_pinyin = ?, updated_at = ? WHERE id = ?',
          [
            data['name'],
            data['age'],
            data['gender'],
            data['phone'],
            data['address'],
            data['doctor'],
            data['name_pinyin'],
            data['address_pinyin'],
            data['updated_at'],
            id,
          ],
        );

        print('MySQL基本字段更新: 影响了 ${basicResult.affectedRows} 行');
        return basicResult.affectedRows! > 0;
      } catch (basicError) {
        print('MySQL基本更新也失败: $basicError');
        return false;
      }
    }
  }

  @override
  Future<int> deletePatient(int id) async {
    try {
      // 确保连接可用
      final conn = await _ensuredConnection;

      // 执行删除 - 此时调用此方法时，关联预约已经在DatabaseProvider中被删除
      final result = await conn.query('DELETE FROM patients WHERE id = ?', [
        id,
      ]);
      print('MySQL删除患者结果: 影响了 ${result.affectedRows} 行');

      return result.affectedRows ?? 0;
    } catch (e) {
      print('MySQL删除患者错误: $e');
      rethrow;
    }
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    // 确保连接可用
    final conn = await _ensuredConnection;

    // 执行查询
    final results = await conn.query('SELECT * FROM patients WHERE id = ?', [
      id,
    ]);

    if (results.isEmpty) {
      return null;
    }

    try {
      // 将结果转换为Map
      final row = results.first;
      final map = <String, dynamic>{};

      // 处理所有字段
      for (var field in row.fields.keys) {
        map[field] = _getSafeValue(row, field);
      }

      // 特殊处理性别 - 转换为中文格式
      if (map.containsKey('gender')) {
        String genderValue = map['gender'].toString().toLowerCase();
        if (genderValue == 'male') {
          map['gender'] = '男';
        } else if (genderValue == 'female') {
          map['gender'] = '女';
        }
      }

      // 创建患者对象
      return Patient.fromMap(map);
    } catch (e) {
      print('转换MySQL患者数据错误: $e');
      return null;
    }
  }

  @override
  Future<List<Patient>> getAllPatients() async {
    // 确保连接可用
    final conn = await _ensuredConnection;

    // 执行查询
    final results = await conn.query('SELECT * FROM patients ORDER BY name');

    return _convertMySQLResultsToPatients(results);
  }

  @override
  Future<List<Patient>> getPatientsPage(
    int page,
    int pageSize, {
    String? sortField,
    bool? ascending,
  }) async {
    // 确保连接可用
    final conn = await _ensuredConnection;
    final offset = (page - 1) * pageSize;

    // 根据排序字段和方向构建排序SQL
    String orderBy = 'updated_at DESC';

    if (sortField != null) {
      switch (sortField) {
        case 'age':
          orderBy = 'age ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'medical_record':
          orderBy =
              'medical_record_number ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'updated':
          orderBy = 'updated_at ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'name':
          orderBy = 'name ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        default:
          orderBy = 'updated_at DESC';
      }
    }

    // 执行查询
    try {
      final results = await conn.query(
        'SELECT * FROM patients ORDER BY $orderBy LIMIT ? OFFSET ?',
        [pageSize, offset],
      );
      print('MySQL分页查询获取到 ${results.length} 条患者数据，排序: $orderBy');

      List<Patient> patients = [];
      for (var row in results) {
        try {
          // 构建Map
          final map = <String, dynamic>{};

          for (var field in row.fields.keys) {
            map[field] = _getSafeValue(row, field);

            // 记录主要字段
            if (['id', 'name', 'age', 'gender', 'phone'].contains(field)) {
              print('  $field = ${map[field]}');
            }
          }

          // 特殊处理性别 - 转换为中文格式
          if (map.containsKey('gender')) {
            String genderValue = map['gender'].toString().toLowerCase();
            if (genderValue == 'male') {
              map['gender'] = '男';
            } else if (genderValue == 'female') {
              map['gender'] = '女';
            }
          }

          // 创建患者对象
          final patient = Patient.fromMap(map);
          patients.add(patient);
        } catch (e) {
          print('转换MySQL行数据错误: $e');
        }
      }

      return patients;
    } catch (e) {
      print('MySQL分页查询错误: $e');
      rethrow;
    }
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    if (query.isEmpty) {
      return await getAllPatients();
    }

    // 确保连接可用
    final conn = await _ensuredConnection;

    // 构建模糊搜索参数
    final searchPattern = '%$query%';

    // 为拼音搜索创建无空格版本
    final noSpaceQuery = query.replaceAll(' ', '');
    final noSpacePattern = '%$noSpaceQuery%';

    // 执行查询 - 添加对拼音字段的支持并优化查询，支持无空格拼音
    final results = await conn.query(
      '''
      SELECT * FROM patients 
      WHERE name LIKE ? 
      OR phone LIKE ? 
      OR (address IS NOT NULL AND address LIKE ?) 
      OR (identification_number IS NOT NULL AND identification_number LIKE ?) 
      OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?)) 
      OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
      OR (name_initials IS NOT NULL AND name_initials LIKE ?)
      OR (medical_record_number IS NOT NULL AND CAST(medical_record_number AS CHAR) LIKE ?)
      
      -- 添加精确匹配的结果（会排在前面）
      UNION ALL
      
      SELECT * FROM patients 
      WHERE name = ? 
      OR phone = ? 
      OR address = ? 
      OR identification_number = ? 
      OR name_pinyin = ? 
      OR address_pinyin = ?
      OR name_initials = ?
      OR CAST(medical_record_number AS CHAR) = ?
      
      ORDER BY
      CASE 
        WHEN name = ? THEN 0
        WHEN phone = ? THEN 1
        WHEN medical_record_number = ? THEN 2
        ELSE 10
      END
      ''',
      [
        // 模糊匹配参数
        searchPattern, // name
        searchPattern, // phone
        searchPattern, // address
        searchPattern, // identification_number
        searchPattern, // name_pinyin
        noSpacePattern, // name_pinyin 无空格
        searchPattern, // name_pinyin 中的空格替换为空字符串后匹配
        searchPattern, // address_pinyin
        noSpacePattern, // address_pinyin 无空格
        searchPattern, // address_pinyin 中的空格替换为空字符串后匹配
        searchPattern, // name_initials
        searchPattern, // medical_record_number
        // 精确匹配参数
        query, // name
        query, // phone
        query, // address
        query, // identification_number
        query, // name_pinyin
        query, // address_pinyin
        query, // name_initials
        query, // medical_record_number
        // 排序优先级参数
        query, // name (优先级0)
        query, // phone (优先级1)
        query, // medical_record_number (优先级2)
      ],
    );

    // 转换并去重患者数据
    List<Patient> patients = _convertMySQLResultsToPatients(results);

    // 添加结果去重逻辑
    Map<int?, Patient> uniquePatients = {};
    for (var patient in patients) {
      if (patient.id != null) {
        uniquePatients[patient.id] = patient;
      }
    }

    return uniquePatients.values.toList();
  }

  @override
  Future<int> getPatientCount() async {
    // 确保连接可用
    final conn = await _ensuredConnection;

    // 执行查询
    final results = await conn.query('SELECT COUNT(*) AS count FROM patients');

    if (results.isNotEmpty) {
      final row = results.first;
      try {
        return int.parse(row['count'].toString());
      } catch (e) {
        print('解析MySQL患者计数错误: $e');
      }
    }

    return 0;
  }

  // 辅助方法：转换MySQL结果为患者列表
  List<Patient> _convertMySQLResultsToPatients(mysql.Results results) {
    final patients = <Patient>[];

    for (var row in results) {
      try {
        // 构建Map
        final map = <String, dynamic>{};

        for (var field in row.fields.keys) {
          map[field] = _getSafeValue(row, field);

          // 记录主要字段
          if (['id', 'name', 'age', 'gender', 'phone'].contains(field)) {
            print('  $field = ${map[field]}');
          }
        }

        // 特殊处理性别 - 转换为中文格式
        if (map.containsKey('gender')) {
          String genderValue = map['gender'].toString().toLowerCase();
          if (genderValue == 'male') {
            map['gender'] = '男';
          } else if (genderValue == 'female') {
            map['gender'] = '女';
          }
        }

        // 创建患者对象
        final patient = Patient.fromMap(map);
        patients.add(patient);
      } catch (e) {
        print('转换MySQL行数据错误: $e');
      }
    }

    return patients;
  }
}
