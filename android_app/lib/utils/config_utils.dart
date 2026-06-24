import 'dart:io';
import 'dart:convert';
import 'datetime_formatter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/utils/database_utils.dart';
import './app_logger.dart';

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
  static Future<String> getOrCreateKey() async {
    try {
      final configDir = await getConfigDirectory();
      final keyFile = File(path.join(configDir.path, keyFileName));

      // 如果密钥文件存在，则读取密钥
      if (await keyFile.exists()) {
        return await keyFile.readAsString();
      }

      // 否则创建新密钥
      final key = encrypt.Key.fromSecureRandom(32).base64;
      await keyFile.writeAsString(key);
      return key;
    } catch (e) {
      AppLogger.info('获取或创建密钥错误: $e');
      // 如果出错，生成一个临时密钥（不会保存）
      final bytes = utf8.encode(DateTimeFormatter.nowDbString());
      return base64.encode(sha256.convert(bytes).bytes);
    }
  }

  /// 获取或创建初始化向量(IV)
  static Future<String> getOrCreateIV() async {
    try {
      final configDir = await getConfigDirectory();
      final ivFile = File(path.join(configDir.path, ivFileName));

      // 如果IV文件存在，则读取IV
      if (await ivFile.exists()) {
        return await ivFile.readAsString();
      }

      // 否则创建新IV
      final iv = encrypt.IV.fromSecureRandom(16).base64;
      await ivFile.writeAsString(iv);
      return iv;
    } catch (e) {
      AppLogger.info('获取或创建IV错误: $e');
      // 如果出错，返回一个固定IV（不理想但可以工作）
      return base64.encode(List<int>.filled(16, 0));
    }
  }

  /// 保存数据库配置
  static Future<void> saveConfig(DatabaseConfig config) async {
    try {
      // 获取加密密钥和IV
      final keyString = await getOrCreateKey();
      final ivString = await getOrCreateIV();
      final key = encrypt.Key.fromBase64(keyString);
      final iv = encrypt.IV.fromBase64(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // 转换配置为JSON
      final jsonString = jsonEncode(config.toJson());

      // 加密配置
      final encrypted = encrypter.encrypt(jsonString, iv: iv).base64;

      // 将加密后的配置保存到文件
      final configDir = await getConfigDirectory();
      final configFile = File(path.join(configDir.path, configFileName));
      await configFile.writeAsString(encrypted);

      AppLogger.info('配置已成功保存到: ${configFile.path}');
    } catch (e) {
      AppLogger.info('保存配置错误: $e');
      throw Exception('保存配置失败: $e');
    }
  }

  /// 加载数据库配置
  static Future<DatabaseConfig> loadConfig() async {
    try {
      final configDir = await getConfigDirectory();
      final configFile = File(path.join(configDir.path, configFileName));

      // 检查配置文件是否存在
      if (await configFile.exists()) {
        try {
          // 获取加密密钥
          final keyString = await getOrCreateKey();
          final ivString = await getOrCreateIV();
          final key = encrypt.Key.fromBase64(keyString);
          final iv = encrypt.IV.fromBase64(ivString);
          final encrypter = encrypt.Encrypter(encrypt.AES(key));

          // 读取加密的配置
          final encrypted = await configFile.readAsString();

          // 解密配置
          final decrypted = encrypter.decrypt64(encrypted, iv: iv);

          // 解析JSON
          final json = jsonDecode(decrypted);
          return DatabaseConfig.fromJson(json);
        } catch (e) {
          AppLogger.info('加载配置错误: $e');
          // 如果解密失败，删除可能损坏的配置文件
          await configFile.delete();
          rethrow;
        }
      }
    } catch (e) {
      AppLogger.info('加载配置错误: $e');
    }

    // 返回默认配置
    return DatabaseConfig(
      dbType: 'sqlite',
      sqlite: SqliteConfig(path: await DatabaseUtils.getDefaultDatabasePath()),
      mysql: MySqlConfig(),
    );
  }
}
