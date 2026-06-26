import 'package:flutter/material.dart';
import 'package:dentist_app/models/patient_material.dart';
import 'package:dentist_app/models/material_image.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/utils/database_operation_wrapper.dart';
import 'package:dentist_app/utils/mysql_row_processor.dart';
import 'package:dentist_app/features/patients/services/patient_image_connection_service.dart';
import 'package:dentist_app/features/patients/services/patient_image_cache_service.dart';
import 'package:dentist_app/features/patients/services/patient_image_initialization_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:async';
import '../utils/app_logger.dart';

class PatientImageProvider extends ChangeNotifier with WidgetsBindingObserver {
  final DatabaseProvider _databaseProvider;

  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;

  // 数据源类型和连接
  String _dataSourceType = 'sqlite';
  Database? _sqliteDatabase;
  MySqlConnection? _mysqlConnection;

  // 初始化标志
  bool initialized = false;

  // 服务实例
  final PatientImageConnectionService _connectionService;
  PatientImageCacheService? _cacheServiceInstance;
  final PatientImageInitializationService _initializationService;

  PatientImageProvider(this._databaseProvider)
      : _connectionService = PatientImageConnectionService(_databaseProvider),
        _initializationService = PatientImageInitializationService() {
    _cacheServiceInstance = PatientImageCacheService(() => notifyListeners());
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
  }

  PatientImageCacheService get _cacheService {
    final service = _cacheServiceInstance;
    if (service == null) {
      throw StateError('PatientImageCacheService 尚未初始化');
    }
    return service;
  }

  @override
  void dispose() {
    _cacheService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      AppLogger.info('PatientImageProvider: 应用从后台恢复，检查连接状态...');
      _checkConnectionOnResume();
    } else if (state == AppLifecycleState.paused) {
      AppLogger.info('PatientImageProvider: 应用进入后台');
    }
  }

  // 应用恢复时检查连接状态
  Future<void> _checkConnectionOnResume() async {
    if (_dataSourceType == 'mysql' && initialized) {
      await _connectionService.checkConnectionOnResume();
    }
  }

  // 初始化数据源
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (initialized) {
      AppLogger.info('PatientImageProvider: 已初始化，跳过重复初始化');
      return;
    }

    try {
      final result = await _initializationService.initialize(dbProvider);

      _dataSourceType = result.dataSourceType;
      _sqliteDatabase = result.sqliteDatabase;
      _mysqlConnection = result.mysqlConnection;
      _connectionService.setMysqlConnection(_mysqlConnection);

      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);

      // 验证数据库连接
      await _validateDatabaseConnection();

      initialized = result.initialized;
      if (!initialized) {
        initialized = true; // 保持原有容错行为，避免反复重试
      }
      AppLogger.info(
        'PatientImageProvider: 初始化完成: initialized = $initialized, _dataSourceType = $_dataSourceType',
      );
      // 延迟通知以避免在build阶段调用setState
      Future.microtask(() => notifyListeners());
    } catch (e) {
      AppLogger.info('PatientImageProvider初始化失败: $e');
      // 设置默认值，避免重复尝试
      _dataSourceType = 'sqlite';
      initialized = true; // 标记为已初始化，避免重复尝试
      // 延迟通知以避免在build阶段调用setState
      Future.microtask(() => notifyListeners());
    }
  }

  // 验证数据库连接
  Future<void> _validateDatabaseConnection() async {
    try {
      if (_dataSourceType == 'sqlite') {
        final db = _sqliteDatabase;
        if (db == null) {
          AppLogger.info('PatientImageProvider: SQLite数据库为null，跳过连接验证');
          return; // 不抛出异常，允许继续初始化
        }

        // 测试数据库连接
        await db.rawQuery('SELECT 1');
        AppLogger.info('PatientImageProvider: SQLite连接验证成功');
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) {
          AppLogger.info('PatientImageProvider: MySQL连接为null，跳过连接验证');
          return; // 不抛出异常，允许继续初始化
        }

        // 测试MySQL连接
        await conn.query('SELECT 1');
        AppLogger.info('PatientImageProvider: MySQL连接验证成功');
      }
    } catch (e) {
      AppLogger.info('PatientImageProvider: 数据库连接验证失败: $e');
      // 不抛出异常，允许继续初始化
      AppLogger.info('PatientImageProvider: 连接验证失败，但允许继续初始化');
    }
  }

  // 获取当前数据库类型
  String get _currentDbType {
    return _dataSourceType;
  }

  MySqlConnection? get _currentMysqlConnection {
    final latest = _connectionService.currentMysqlConnection;
    if (latest != null) {
      _mysqlConnection = latest;
      return latest;
    }
    return _mysqlConnection;
  }

  // 获取患者材料列表
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    // 检查缓存
    final cachedMaterials = _cacheService.getPatientMaterialsCache(patientId);
    if (cachedMaterials != null) {
      AppLogger.info(
        'PatientImageProvider: 使用缓存的患者材料数据: ${cachedMaterials.length} 条',
      );
      return cachedMaterials;
    }

    if (_cacheService.isLoading(patientId)) {
      return [];
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getPatientMaterials', () async {
      try {
        _cacheService.setLoadingState(patientId, true);
        _cacheService.clearError(patientId);

        // 检查是否已初始化
        if (!initialized) {
          AppLogger.info('PatientImageProvider: 尚未初始化，尝试自动初始化...');
          // 尝试自动初始化
          try {
            await initializeFromDatabase(_databaseProvider);
          } catch (e) {
            AppLogger.info('PatientImageProvider: 自动初始化失败: $e');
            // 如果自动初始化失败，返回空列表而不是抛出异常
            return [];
          }
        }

        List<PatientMaterial> materials = [];

        if (_currentDbType == 'sqlite') {
          AppLogger.info('PatientImageProvider: 使用SQLite数据源');
          materials = await _getPatientMaterialsFromSQLite(patientId);
        } else if (_currentDbType == 'mysql') {
          AppLogger.info('PatientImageProvider: 使用MySQL数据源');
          materials = await _getPatientMaterialsFromMySQL(patientId);
        } else {
          throw Exception('未知的数据库类型: $_currentDbType');
        }

        AppLogger.info('PatientImageProvider: 成功获取患者材料: ${materials.length} 条');

        // 更新缓存
        _cacheService.updatePatientMaterialsCache(patientId, materials);

        // 异步预加载图片数据，不阻塞主流程
        for (final material in materials) {
          final materialId = material.id;
          if (materialId != null) {
            getMaterialImages(materialId).catchError((e) {
              AppLogger.info('获取材料图片失败: $e');
              return <MaterialImage>[];
            });
          }
        }

        _cacheService.setLoadingState(patientId, false);
        return materials;
      } catch (e) {
        String errorMsg = '获取患者材料失败: $e';
        AppLogger.info('PatientImageProvider: $errorMsg');
        _cacheService.setError(patientId, errorMsg);
        _cacheService.setLoadingState(patientId, false);
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 获取材料图片列表
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    // 检查缓存
    final cachedImages = _cacheService.getMaterialImagesCache(materialId);
    if (cachedImages != null) {
      AppLogger.info(
        'PatientImageProvider: 使用缓存的材料图片数据: ${cachedImages.length} 张',
      );
      return cachedImages;
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getMaterialImages', () async {
      try {
        // 检查是否已初始化
        if (!initialized) {
          AppLogger.info('PatientImageProvider: 获取图片时未初始化，尝试自动初始化...');
          try {
            await initializeFromDatabase(_databaseProvider);
          } catch (e) {
            AppLogger.info('PatientImageProvider: 自动初始化失败: $e');
            return [];
          }
        }

        List<MaterialImage> images = [];

        if (_currentDbType == 'sqlite') {
          images = await _getMaterialImagesFromSQLite(materialId);
        } else if (_currentDbType == 'mysql') {
          images = await _getMaterialImagesFromMySQL(materialId);
        } else {
          throw Exception('未知的数据库类型: $_currentDbType');
        }

        AppLogger.info('PatientImageProvider: 成功获取材料图片: ${images.length} 张');

        // 更新缓存
        _cacheService.updateMaterialImagesCache(materialId, images);

        return images;
      } catch (e) {
        AppLogger.info('PatientImageProvider: 获取材料图片失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        _cacheService.updateMaterialImagesCache(materialId, []); // 缓存空结果避免重复查询
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 获取患者所有图片（优化版本，避免重复查询）
  Future<List<MaterialImage>> getPatientImages(int patientId) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getPatientImages', () async {
      try {
        // 检查是否有缓存的图片数据
        if (_cacheService.hasCachedData(patientId)) {
          AppLogger.info('PatientImageProvider: 使用缓存的图片数据');
          return _cacheService.getCachedImages(patientId);
        }

        // 设置加载状态（只设置一次）
        _cacheService.setLoadingState(patientId, true);
        _cacheService.clearError(patientId);

        // 检查是否已初始化
        if (!initialized) {
          AppLogger.info('PatientImageProvider: 获取图片时未初始化，尝试自动初始化...');
          try {
            await initializeFromDatabase(_databaseProvider);
          } catch (e) {
            AppLogger.info('PatientImageProvider: 自动初始化失败: $e');
            return [];
          }
        }

        // 获取患者材料
        List<PatientMaterial> materials = [];
        if (_currentDbType == 'sqlite') {
          AppLogger.info('PatientImageProvider: 使用SQLite数据源获取患者材料');
          materials = await _getPatientMaterialsFromSQLite(patientId);
        } else if (_currentDbType == 'mysql') {
          AppLogger.info('PatientImageProvider: 使用MySQL数据源获取患者材料');
          materials = await _getPatientMaterialsFromMySQL(patientId);
        } else {
          throw Exception('未知的数据库类型: $_currentDbType');
        }

        // 更新材料缓存
        _cacheService.updatePatientMaterialsCache(patientId, materials);

        // 获取所有图片（批量获取，避免多次notifyListeners）
        List<MaterialImage> allImages = [];
        for (final material in materials) {
          final materialId = material.id;
          if (materialId != null) {
            try {
              List<MaterialImage> images = [];
              if (_currentDbType == 'sqlite') {
                images = await _getMaterialImagesFromSQLite(materialId);
              } else if (_currentDbType == 'mysql') {
                images = await _getMaterialImagesFromMySQL(materialId);
              }

              // 更新图片缓存
              _cacheService.updateMaterialImagesCache(materialId, images);
              allImages.addAll(images);
            } catch (e) {
              AppLogger.info('PatientImageProvider: 获取材料 $materialId 的图片失败: $e');
            }
          }
        }

        AppLogger.info('PatientImageProvider: 获取患者所有图片完成: ${allImages.length} 张');

        // 清除加载状态（只清除一次）
        _cacheService.setLoadingState(patientId, false);

        return allImages;
      } catch (e) {
        AppLogger.info('PatientImageProvider: 获取患者所有图片失败: $e');
        // 如果是连接错误，尝试重新初始化
        if (e.toString().contains('database') || e.toString().contains('连接')) {
          initialized = false; // 重置初始化状态
        }
        _cacheService.setError(patientId, '获取患者图片失败: $e');
        _cacheService.setLoadingState(patientId, false);
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      }
    });
  }

  // 从SQLite获取患者材料
  Future<List<PatientMaterial>> _getPatientMaterialsFromSQLite(
    int patientId,
  ) async {
    try {
      AppLogger.info('PatientImageProvider: 开始获取SQLite数据库...');

      if (!initialized) {
        AppLogger.info('PatientImageProvider: SQLite数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          AppLogger.info('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }

      final db = _sqliteDatabase;
      AppLogger.info('PatientImageProvider: SQLite数据库状态: $db');

      if (db == null) {
        throw Exception('SQLite数据库不可用 - 数据库对象为null');
      }

      AppLogger.info('PatientImageProvider: 开始执行SQLite查询，患者ID: $patientId');

      try {
        final maps = await db.query(
          'patient_materials',
          where: 'patient_id = ?',
          whereArgs: [patientId],
          orderBy: 'created_at DESC',
        );

        AppLogger.info('PatientImageProvider: SQLite查询成功，结果行数: ${maps.length}');

        return maps.map((map) => PatientMaterial.fromMap(map)).toList();
      } catch (tableError) {
        AppLogger.info('PatientImageProvider: SQLite查询表不存在，尝试创建表: $tableError');
        // 如果表不存在，返回空列表而不是抛出异常
        return [];
      }
    } catch (e) {
      AppLogger.info('PatientImageProvider: SQLite查询患者材料失败: $e');
      return []; // 返回空列表而不是抛出异常
    }
  }

  // 从MySQL获取患者材料
  Future<List<PatientMaterial>> _getPatientMaterialsFromMySQL(
    int patientId,
  ) async {
    try {
      AppLogger.info('PatientImageProvider: 开始获取MySQL连接...');

      if (!initialized) {
        AppLogger.info('PatientImageProvider: MySQL数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          AppLogger.info('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }

      // 检查MySQL连接状态
      final connectionOk = await _connectionService.ensureConnection();
      if (!connectionOk) {
        // 尝试自动重连
        final reconnected = await _connectionService.autoReconnect();
        if (!reconnected) {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }

      final conn = _currentMysqlConnection;
      AppLogger.info('PatientImageProvider: MySQL连接状态: $conn');

      if (conn == null) {
        throw Exception('MySQL连接不可用 - 连接对象为null');
      }

      AppLogger.info('PatientImageProvider: 开始执行MySQL查询，患者ID: $patientId');

      final results = await conn.query(
        'SELECT * FROM patient_materials WHERE patient_id = ? ORDER BY created_at DESC',
        [patientId],
      );

      AppLogger.info('PatientImageProvider: MySQL查询成功，结果行数: ${results.length}');

      return results
          .map(
            (row) => PatientMaterial.fromMap(MysqlRowProcessor.processRow(row)),
          )
          .toList();
    } catch (e) {
      // 检查是否是连接错误
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Cannot write to socket') ||
          e.toString().contains('Connection reset')) {
        AppLogger.info('PatientImageProvider: 检测到连接错误，尝试重连: $e');

        // 尝试重连
        final reconnected = await _connectionService.autoReconnect();
        if (reconnected) {
          // 重连成功，重新执行查询
          return await _getPatientMaterialsFromMySQL(patientId);
        } else {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }

      AppLogger.info('PatientImageProvider: MySQL查询患者材料失败: $e');
      rethrow;
    }
  }

  // 从SQLite获取材料图片
  Future<List<MaterialImage>> _getMaterialImagesFromSQLite(
    int materialId,
  ) async {
    try {
      AppLogger.info('PatientImageProvider: 开始获取SQLite数据库...');

      if (!initialized) {
        AppLogger.info('PatientImageProvider: SQLite数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          AppLogger.info('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }

      final db = _sqliteDatabase;
      AppLogger.info('PatientImageProvider: SQLite数据库状态: $db');

      if (db == null) {
        throw Exception('SQLite数据库不可用 - 数据库对象为null');
      }

      AppLogger.info('PatientImageProvider: 开始执行SQLite查询，材料ID: $materialId');

      try {
        final maps = await db.query(
          'material_images',
          where: 'material_id = ?',
          whereArgs: [materialId],
          orderBy: 'created_at DESC',
        );

        AppLogger.info('PatientImageProvider: SQLite查询成功，结果行数: ${maps.length}');

        return maps.map((map) => MaterialImage.fromMap(map)).toList();
      } catch (tableError) {
        AppLogger.info('PatientImageProvider: SQLite查询表不存在: $tableError');
        return []; // 表不存在时返回空列表
      }
    } catch (e) {
      AppLogger.info('PatientImageProvider: SQLite查询材料图片失败: $e');
      return []; // 返回空列表而不是抛出异常
    }
  }

  // 从MySQL获取材料图片
  Future<List<MaterialImage>> _getMaterialImagesFromMySQL(
    int materialId,
  ) async {
    try {
      AppLogger.info('PatientImageProvider: 开始获取MySQL连接...');

      if (!initialized) {
        AppLogger.info('PatientImageProvider: MySQL数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          AppLogger.info('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }

      // 检查MySQL连接状态
      final connectionOk = await _connectionService.ensureConnection();
      if (!connectionOk) {
        // 尝试自动重连
        final reconnected = await _connectionService.autoReconnect();
        if (!reconnected) {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }

      final conn = _currentMysqlConnection;
      AppLogger.info('PatientImageProvider: MySQL连接状态: $conn');

      if (conn == null) {
        throw Exception('MySQL连接不可用 - 连接对象为null');
      }

      AppLogger.info('PatientImageProvider: 开始执行MySQL查询，材料ID: $materialId');

      final results = await conn.query(
        'SELECT * FROM material_images WHERE material_id = ? ORDER BY created_at DESC',
        [materialId],
      );

      AppLogger.info('PatientImageProvider: MySQL查询成功，结果行数: ${results.length}');

      return results
          .map(
            (row) => MaterialImage.fromMap(MysqlRowProcessor.processRow(row)),
          )
          .toList();
    } catch (e) {
      // 检查是否是连接错误
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Cannot write to socket') ||
          e.toString().contains('Connection reset')) {
        AppLogger.info('PatientImageProvider: 检测到连接错误，尝试重连: $e');

        // 尝试重连
        final reconnected = await _connectionService.autoReconnect();
        if (reconnected) {
          // 重连成功，重新执行查询
          return await _getMaterialImagesFromMySQL(materialId);
        } else {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }

      AppLogger.info('PatientImageProvider: MySQL查询材料图片失败: $e');
      rethrow;
    }
  }

  // 清除患者缓存
  void clearPatientCache(int patientId) {
    _cacheService.clearPatientCache(patientId);
  }

  // 清除所有缓存
  void clearAllCache() {
    _cacheService.clearAllCache();
  }

  // 获取加载状态
  bool isLoading(int patientId) {
    return _cacheService.isLoading(patientId);
  }

  // 获取错误状态
  String? getError(int patientId) {
    return _cacheService.getError(patientId);
  }

  // 检查是否有缓存数据
  bool hasCachedData(int patientId) {
    return _cacheService.hasCachedData(patientId);
  }

  // 获取缓存的患者材料数量
  int getCachedMaterialCount(int patientId) {
    return _cacheService.getCachedMaterialCount(patientId);
  }

  // 获取缓存的图片数量
  int getCachedImageCount(int patientId) {
    return _cacheService.getCachedImageCount(patientId);
  }

  // 同步获取缓存的图片数据
  List<MaterialImage> getCachedImages(int patientId) {
    return _cacheService.getCachedImages(patientId);
  }

  // 同步获取缓存的材料数据
  List<PatientMaterial> getCachedMaterials(int patientId) {
    return _cacheService.getCachedMaterials(patientId);
  }

  // 强制刷新患者数据
  Future<void> refreshPatientData(int patientId) async {
    // 清除缓存
    _cacheService.clearPatientCache(patientId);

    // 重新获取数据
    await getPatientMaterials(patientId);
  }
}
