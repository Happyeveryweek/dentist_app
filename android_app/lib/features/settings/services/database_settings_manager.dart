import 'package:flutter/material.dart';

import '../../../models/database_config.dart';

/// 数据库设置管理器 - 负责管理数据库配置状态
/// 业务逻辑已迁移到 Service 层
class DatabaseSettingsManager extends ChangeNotifier {
  DatabaseConfig? _dbConfig;
  String _dbType = 'sqlite';
  String _dbPath = '';

  String get dbType => _dbType;
  String get dbPath => _dbPath;
  DatabaseConfig? get dbConfig => _dbConfig;

  void setDbConfig(DatabaseConfig config) {
    _dbConfig = config;
    _dbType = config.dbType;
    _dbPath =
        config.dbType == 'sqlite'
            ? config.sqlite.path
            : '${config.mysql.host}:${config.mysql.port}/${config.mysql.database}';
    notifyListeners();
  }

  void setDbType(String type) {
    _dbType = type;
    notifyListeners();
  }

  void setDbPath(String path) {
    _dbPath = path;
    notifyListeners();
  }
}
