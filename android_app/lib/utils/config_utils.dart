import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path/path.dart' as path;
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/utils/database_utils.dart';
import './app_logger.dart';
import 'atomic_file_writer.dart';

class ConfigReadException implements Exception {
  final String message;

  const ConfigReadException(this.message);

  @override
  String toString() => 'ConfigReadException: $message';
}

/// 配置工具类，负责加密存储和读取配置
class ConfigUtils {
  static const String keyFileName = 'encryption.key';
  static const String configFileName = 'database_settings.json';
  static const String ivFileName = 'encryption.iv';

  /// 获取配置目录
  static Future<Directory> getConfigDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final configDir = Directory(path.join(appDir.path, 'config'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return configDir;
  }

  /// 获取或创建加密密钥
  static Future<String> getOrCreateKey({Directory? configDirectory}) async {
    try {
      final configDir = configDirectory ?? await getConfigDirectory();
      final keyFile = File(path.join(configDir.path, keyFileName));

      // 如果密钥文件存在，则读取密钥
      if (await keyFile.exists()) {
        return await keyFile.readAsString();
      }

      // 否则创建新密钥
      final key = encrypt.Key.fromSecureRandom(32).base64;
      await AtomicFileWriter.write(keyFile, key);
      return key;
    } catch (e) {
      AppLogger.info('获取或创建密钥错误: $e');
      throw Exception('保存加密密钥失败: $e');
    }
  }

  /// 获取或创建初始化向量(IV)
  static Future<String> getOrCreateIV({Directory? configDirectory}) async {
    try {
      final configDir = configDirectory ?? await getConfigDirectory();
      final ivFile = File(path.join(configDir.path, ivFileName));

      // 如果IV文件存在，则读取IV
      if (await ivFile.exists()) {
        return await ivFile.readAsString();
      }

      // 否则创建新IV
      final iv = encrypt.IV.fromSecureRandom(16).base64;
      await AtomicFileWriter.write(ivFile, iv);
      return iv;
    } catch (e) {
      AppLogger.info('获取或创建IV错误: $e');
      throw Exception('保存初始化向量失败: $e');
    }
  }

  /// 保存数据库配置
  static Future<void> saveConfig(
    DatabaseConfig config, {
    Directory? configDirectory,
  }) async {
    try {
      // 获取加密密钥和IV
      final keyString = await getOrCreateKey(configDirectory: configDirectory);
      final ivString = await getOrCreateIV(configDirectory: configDirectory);
      final key = encrypt.Key.fromBase64(keyString);
      final iv = encrypt.IV.fromBase64(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // 转换配置为JSON
      final jsonString = jsonEncode(config.toJson());

      // 加密配置
      final encrypted = encrypter.encrypt(jsonString, iv: iv).base64;

      // 将加密后的配置保存到文件
      final configDir = configDirectory ?? await getConfigDirectory();
      final configFile = File(path.join(configDir.path, configFileName));
      await AtomicFileWriter.write(configFile, encrypted);

      AppLogger.info('配置已成功保存到: ${configFile.path}');
    } catch (e) {
      AppLogger.info('保存配置错误: $e');
      throw Exception('保存配置失败: $e');
    }
  }

  /// 加载数据库配置
  static Future<DatabaseConfig> loadConfig({Directory? configDirectory}) async {
    final configDir = configDirectory ?? await getConfigDirectory();
    final configFile = File(path.join(configDir.path, configFileName));

    if (await configFile.exists()) {
      try {
        return await _readConfig(configDir, configFile);
      } catch (primaryError) {
        AppLogger.info('主配置读取失败，尝试最近备份: $primaryError');
        final backupFile = File(
          '${configFile.path}${AtomicFileWriter.backupSuffix}',
        );
        if (await backupFile.exists()) {
          try {
            return await _readConfig(configDir, backupFile);
          } catch (backupError) {
            throw ConfigReadException('数据库配置及备份均不可读取: $backupError');
          }
        }
        throw ConfigReadException('数据库配置不可读取: $primaryError');
      }
    }

    // 返回默认配置
    return DatabaseConfig(
      dbType: 'sqlite',
      sqlite: SqliteConfig(path: await DatabaseUtils.getDefaultDatabasePath()),
      mysql: MySqlConfig(),
    );
  }

  static Future<DatabaseConfig> _readConfig(
    Directory configDir,
    File configFile,
  ) async {
    final keyFile = File(path.join(configDir.path, keyFileName));
    final ivFile = File(path.join(configDir.path, ivFileName));
    if (!await keyFile.exists() || !await ivFile.exists()) {
      throw const ConfigReadException('加密密钥或初始化向量缺失');
    }

    final key = encrypt.Key.fromBase64(await keyFile.readAsString());
    final iv = encrypt.IV.fromBase64(await ivFile.readAsString());
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = await configFile.readAsString();
    final decoded = jsonDecode(encrypter.decrypt64(encrypted, iv: iv));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('数据库配置JSON结构无效');
    }
    return DatabaseConfig.fromJson(decoded);
  }
}
