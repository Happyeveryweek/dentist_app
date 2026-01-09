import 'package:flutter/material.dart';
import '../utils/settings_manager.dart';
import '../models/database_config.dart';
import '../utils/database_utils.dart';
import '../utils/datetime_formatter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

/// 设置提供者 - 用于在应用程序中共享设置状态
class SettingsProvider extends ChangeNotifier {
  late SettingsManager _settingsManager;

  // 通知设置
  bool _appointmentReminder = true;
  bool _systemNotification = true;

  // 语言与区域设置
  String _language = '中文';
  String _timeFormat = '24小时制';

  // 系统设置
  ThemeMode _themeMode = ThemeMode.light;
  String _fontSize = '中';

  // 获取器
  bool get appointmentReminder => _appointmentReminder;
  bool get systemNotification => _systemNotification;
  String get language => _language;
  String get timeFormat => _timeFormat;
  ThemeMode get themeMode => _themeMode;
  String get fontSize => _fontSize;

  // 初始化设置
  Future<void> init() async {
    // 获取单例
    _settingsManager = await SettingsManager.getInstance();

    // 加载所有设置
    _appointmentReminder = _settingsManager.getAppointmentReminder();
    _systemNotification = _settingsManager.getSystemNotification();
    _language = _settingsManager.getLanguage();
    _timeFormat = _settingsManager.getTimeFormat();
    _themeMode = _settingsManager.getThemeMode();
    _fontSize = _settingsManager.getFontSize();

    // 通知监听器
    notifyListeners();
  }

  // 更新预约提醒设置
  Future<void> updateAppointmentReminder(bool value) async {
    if (await _settingsManager.setAppointmentReminder(value)) {
      _appointmentReminder = value;
      notifyListeners();
    }
  }

  // 更新系统通知设置
  Future<void> updateSystemNotification(bool value) async {
    if (await _settingsManager.setSystemNotification(value)) {
      _systemNotification = value;
      notifyListeners();
    }
  }

  // 更新语言设置
  Future<void> updateLanguage(String value) async {
    if (await _settingsManager.setLanguage(value)) {
      _language = value;
      notifyListeners();
    }
  }

  // 更新时间格式设置
  Future<void> updateTimeFormat(String value) async {
    if (await _settingsManager.setTimeFormat(value)) {
      _timeFormat = value;
      notifyListeners();
    }
  }

  // 更新主题模式
  Future<void> updateThemeMode(ThemeMode value) async {
    if (await _settingsManager.setThemeMode(value)) {
      _themeMode = value;
      notifyListeners();
    }
  }

  // 更新字体大小
  Future<void> updateFontSize(String value) async {
    if (await _settingsManager.setFontSize(value)) {
      _fontSize = value;
      notifyListeners();
    }
  }
}

/// 数据库设置管理器 - 负责管理数据库配置、切换、备份恢复等操作
class DatabaseSettingsManager extends ChangeNotifier {
  late DatabaseConfig _dbConfig;
  String _dbType = 'sqlite';
  String _dbPath = '';

  // 获取器
  String get dbType => _dbType;
  String get dbPath => _dbPath;
  DatabaseConfig get dbConfig => _dbConfig;

  // 初始化数据库配置
  Future<void> initDatabaseConfig() async {
    try {
      _dbConfig = await DatabaseConfig.loadConfig();
      _dbType = _dbConfig.dbType;
      
      if (_dbType == 'sqlite') {
        if (_dbConfig.sqlite.path.isNotEmpty) {
          _dbPath = _dbConfig.sqlite.path;
        } else {
          // 如果配置中没有路径，使用默认路径
          _dbPath = await DatabaseUtils.getDefaultDatabasePath();
          _dbConfig.sqlite.path = _dbPath;
          await _dbConfig.saveConfig();
        }
        print('SQLite数据库路径初始化为: $_dbPath');
      } else if (_dbType == 'mysql') {
        _dbPath = '${_dbConfig.mysql.host}:${_dbConfig.mysql.port}/${_dbConfig.mysql.database}';
        print('MySQL连接信息初始化为: $_dbPath');
      }
      
      notifyListeners();
    } catch (e) {
      print('初始化数据库配置错误: $e');
      rethrow;
    }
  }

  // 切换数据库类型
  Future<void> switchDatabaseType(
    String type, {
    String? path, // 可选的SQLite路径
  }) async {
    final oldType = _dbType;
    final oldPath = _dbPath;
    print('切换数据库类型到 $type，当前类型: $oldType');

    try {
      _dbType = type;
      _dbConfig.dbType = type; // 确保配置也更新

      if (type == 'sqlite') {
        if (path != null && path.isNotEmpty) {
          // 使用提供的路径
          _dbConfig.sqlite.path = path;
          _dbPath = path;
        } else if (_dbConfig.sqlite.path.isNotEmpty) {
          // 使用配置中的路径
          _dbPath = _dbConfig.sqlite.path;
        } else {
          // 使用默认路径
          _dbPath = await DatabaseUtils.getDefaultDatabasePath();
          _dbConfig.sqlite.path = _dbPath;
        }
        await _dbConfig.saveConfig();
        print('SQLite路径已设置为: $_dbPath');
      } else if (type == 'mysql') {
        // 确保配置已保存
        await _dbConfig.saveConfig();
        _dbPath = '${_dbConfig.mysql.host}:${_dbConfig.mysql.port}/${_dbConfig.mysql.database}';
        print('MySQL连接信息已设置为: $_dbPath');
      }

      notifyListeners();
      print('数据库类型切换完成: $_dbType, 路径: $_dbPath');
    } catch (e) {
      print('切换数据库类型错误: $e');
      // 回退到原类型和路径
      _dbType = oldType;
      _dbPath = oldPath;
      _dbConfig.dbType = oldType;
      rethrow;
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
      final settings = ConnectionSettings(
        host: effectiveHost,
        port: int.parse(port),
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 20), // 增加超时时间，与正式连接保持一致
      );

      // 尝试连接
      print('尝试连接到MySQL: $effectiveHost:$port/$database (用户名: $username)');

      MySqlConnection? connection;

      // 增加重试机制
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount <= maxRetries) {
        try {
          print('连接尝试 ${retryCount + 1}/$maxRetries');
          connection = await MySqlConnection.connect(settings);
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

  // 备份整个SQLite数据库文件
  Future<bool> backupDatabase(String destinationPath, String currentDbPath) async {
    try {
      print('开始备份SQLite数据库到: $destinationPath');

      // 确认当前是SQLite数据库类型
      if (_dbType != 'sqlite') {
        print('错误：只能备份SQLite数据库');
        return false;
      }

      // 获取SQLite数据库文件路径
      final dbPath = currentDbPath.isNotEmpty ? currentDbPath : _dbPath;
      if (dbPath.isEmpty) {
        print('错误：无法获取SQLite数据库路径');
        return false;
      }

      // 复制数据库文件
      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        print('错误：源数据库文件不存在');
        return false;
      }

      await sourceFile.copy(destinationPath);
      print('数据库文件已备份到: $destinationPath');

      // 创建目标目录（如果不存在）
      final dir = File(destinationPath).parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      return true;
    } catch (e) {
      print('备份数据库错误: $e');
      return false;
    }
  }

  // 从备份文件恢复SQLite数据库
  Future<bool> restoreDatabaseFromBackup(String backupPath, String currentDbPath) async {
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
      final dbPath = currentDbPath.isNotEmpty ? currentDbPath : _dbPath;
      if (dbPath.isEmpty) {
        print('错误：无法获取SQLite数据库路径');
        return false;
      }

      // 复制备份文件到数据库位置
      await backupFile.copy(dbPath);
      print('备份文件已恢复到数据库');

      return true;
    } catch (e) {
      print('恢复数据库错误: $e');
      return false;
    }
  }

  // 导出数据库
  Future<String> exportDatabase(String currentDbPath) async {
    try {
      final dbPath = currentDbPath.isNotEmpty ? currentDbPath : _dbPath;
      if (dbPath.isEmpty) {
        throw Exception('无法获取数据库路径');
      }

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
  Future<bool> importDatabase(String path, String currentDbPath) async {
    try {
      final dbPath = currentDbPath.isNotEmpty ? currentDbPath : _dbPath;
      if (dbPath.isEmpty) {
        throw Exception('无法获取数据库路径');
      }

      // 复制导入的数据库文件到应用数据库位置
      File importFile = File(path);
      await importFile.copy(dbPath);

      return true;
    } catch (e) {
      print('导入数据库错误: $e');
      return false;
    }
  }

  // 恢复出厂设置（重置数据库）
  Future<bool> resetToFactorySettings(String currentDbPath) async {
    try {
      final dbPath = currentDbPath.isNotEmpty ? currentDbPath : _dbPath;
      if (dbPath.isEmpty) {
        throw Exception('无法获取数据库路径');
      }

      // 执行重置
      final success = await DatabaseUtils.resetDatabase(dbPath);
      return success;
    } catch (e) {
      print('重置数据库错误: $e');
      rethrow;
    }
  }

  // 导出患者信息到Excel文件
  Future<String> exportPatientsToExcel(String filePath, List<Map<String, dynamic>> patients) async {
    try {
      print('开始导出患者数据到Excel');

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
            .value = TextCellValue(patient['name'] ?? '');
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['gender'] ?? '');
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = IntCellValue(patient['age'] ?? 0);

        // 处理电话号码 - 分为主电话号和备用电话号两列
        String mainPhone = '';
        String backupPhone = '';

        try {
          final phone = patient['phone'] ?? '';
          if (phone.contains(",")) {
            // 可能是JSON格式，尝试解析
            if (phone.startsWith('[') && phone.endsWith(']')) {
              List<dynamic> phones = jsonDecode(phone);
              if (phones.isNotEmpty) {
                mainPhone = phones[0].toString();
                if (phones.length > 1) {
                  backupPhone = phones[1].toString();
                }
              }
            } else {
              // 可能是逗号分隔的格式
              List<String> phones = phone.split(',');
              if (phones.isNotEmpty) {
                mainPhone = phones[0].trim();
                if (phones.length > 1) {
                  backupPhone = phones[1].trim();
                }
              }
            }
          } else {
            // 单个电话号码
            mainPhone = phone;
          }
        } catch (e) {
          print('解析电话号码失败: $e, 使用原始值');
          mainPhone = patient['phone'] ?? '';
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
            .value = TextCellValue(patient['address'] ?? '');

        // 身份证号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['identification_number'] ?? '');

        // 病历号
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            )
            .value = patient['medical_record_number'] != null
                ? IntCellValue(patient['medical_record_number'])
                : TextCellValue('');

        // 医生
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
            )
            .value = TextCellValue(patient['doctor'] ?? '');

        // 初诊日期
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          DateFormat('yyyy-MM-dd').format(DateTimeFormatter.fromDbString(patient['first_visit_date'] ?? DateTimeFormatter.nowDbString())),
        );

        // 总费用
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(patient['total_cost'] ?? 0.0);

        // 牙齿状况
        String dentalData = '';
        if (patient['dental_condition'] != null &&
            patient['dental_condition'].isNotEmpty) {
          try {
            if (patient['dental_condition'].startsWith('{') ||
                patient['dental_condition'].startsWith('[')) {
              // 尝试解析JSON格式
              Map<String, dynamic> dentalJson = jsonDecode(
                patient['dental_condition'],
              );
              dentalData = _convertDentalJsonToText(dentalJson);
            } else {
              // 使用普通格式化
              dentalData = _formatDentalCondition(patient['dental_condition']);
            }
          } catch (e) {
            print('处理牙齿状况失败: $e, 使用原始数据');
            dentalData = patient['dental_condition'];
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
  String _convertDentalJsonToText(Map<String, dynamic> jsonData) {
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
  String _formatDentalCondition(String dentalCondition) {
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
}
