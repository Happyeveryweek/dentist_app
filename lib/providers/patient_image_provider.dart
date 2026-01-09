import 'package:flutter/material.dart';
import 'package:dentist_app/models/patient_material.dart';
import 'package:dentist_app/models/material_image.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/utils/database_operation_wrapper.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // Added for Uint8List

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
  
  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  
  // 缓存患者图片数据
  final Map<int, List<PatientMaterial>> _patientMaterialsCache = {};
  final Map<int, List<MaterialImage>> _materialImagesCache = {};
  
  // 加载状态
  final Map<int, bool> _loadingStates = {};
  
  // 错误状态
  final Map<int, String?> _errorStates = {};
  
  PatientImageProvider(this._databaseProvider) {
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      print('PatientImageProvider: 应用从后台恢复，检查连接状态...');
      _checkConnectionOnResume();
    } else if (state == AppLifecycleState.paused) {
      print('PatientImageProvider: 应用进入后台');
    }
  }

  // 应用恢复时检查连接状态
  Future<void> _checkConnectionOnResume() async {
    if (_dataSourceType == 'mysql' && initialized) {
      try {
        print('PatientImageProvider: 检查MySQL连接状态...');
        final isHealthy = await _ensureConnection();
        
        if (!isHealthy) {
          print('PatientImageProvider: 连接异常，尝试重连...');
          await _autoReconnect();
        } else {
          print('PatientImageProvider: 连接状态正常');
        }
      } catch (e) {
        print('PatientImageProvider: 检查连接状态失败: $e');
      }
    }
  }

  // 处理MySQL查询结果中的Blob字段
  Map<String, dynamic> _processMySQLRow(ResultRow row) {
    final Map<String, dynamic> processedMap = {};
    
    for (var entry in row.fields.entries) {
      var value = entry.value;
      
      // 处理DateTime类型，将其转换为ISO字符串
      if (value is DateTime) {
        try {
          final stringValue = DateTimeFormatter.toDbString(value);
          processedMap[entry.key] = stringValue;
        } catch (e) {
          print('PatientImageProvider: DateTime转换失败: $e');
          processedMap[entry.key] = '';
        }
      }
      // 处理图片数据字段，使用String.fromCharCodes处理Blob类型
      else if (entry.key == 'image_data' || entry.key == 'thumbnail_data') {
        if (value is Blob) {
          try {
            // 使用String.fromCharCodes处理Blob，参考windows_app的实现
            final blobString = String.fromCharCodes(value.toBytes());
            processedMap[entry.key] = blobString;
          } catch (e) {
            print('PatientImageProvider: 图片字段转换失败: $e');
            processedMap[entry.key] = '';
          }
        } else if (value is Uint8List) {
          try {
            // 使用String.fromCharCodes处理Uint8List
            final stringValue = String.fromCharCodes(value);
            processedMap[entry.key] = stringValue;
          } catch (e) {
            print('PatientImageProvider: Uint8List转换失败: $e');
            processedMap[entry.key] = '';
          }
        } else if (value is String) {
          // 如果已经是String类型，直接使用
          processedMap[entry.key] = value;
        } else {
          print('PatientImageProvider: 图片字段 ${entry.key} 类型异常: ${value.runtimeType}');
          processedMap[entry.key] = '';
        }
      }
      // 处理其他Blob类型，将其转换为字符串
      else if (value is Blob) {
        try {
          final bytes = value.toBytes();
          if (bytes.isNotEmpty) {
            // 尝试UTF-8解码
            final stringValue = utf8.decode(bytes, allowMalformed: true);
            processedMap[entry.key] = stringValue;
          } else {
            processedMap[entry.key] = '';
          }
        } catch (e) {
          print('PatientImageProvider: Blob转换失败: $e');
          processedMap[entry.key] = '';
        }
      } else if (value is Uint8List) {
        // 处理Uint8List类型（某些MySQL驱动可能返回这种类型）
        try {
          if (value.isNotEmpty) {
            final stringValue = utf8.decode(value, allowMalformed: true);
            processedMap[entry.key] = stringValue;
          } else {
            processedMap[entry.key] = '';
          }
        } catch (e) {
          print('PatientImageProvider: Uint8List转换失败: $e');
          processedMap[entry.key] = '';
        }
      } else if (value is String) {
        // 对于字符串字段，也尝试UTF-8解码修复编码问题
        try {
          final bytes = value.codeUnits;
          final decodedString = utf8.decode(bytes, allowMalformed: true);
          processedMap[entry.key] = decodedString;
        } catch (e) {
          print('PatientImageProvider: 字符串解码失败: $e');
          processedMap[entry.key] = value;
        }
      } else {
        processedMap[entry.key] = value;
      }
    }
    
    return processedMap;
  }

  // 初始化数据源
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (initialized) {
      print('PatientImageProvider: 已初始化，跳过重复初始化');
      return;
    }
    
    try {
      print('PatientImageProvider开始初始化...');
      
      // 兼容处理，支持DatabaseProvider的不同接口
      String dbType = 'sqlite';
      if (dbProvider.dbType != null) {
        dbType = dbProvider.dbType;
      } else if (dbProvider.dataSourceType != null) {
        dbType = dbProvider.dataSourceType;
      }
      
      print('检测到数据源类型: $dbType');
      
      if (dbType == 'mysql') {
        _dataSourceType = 'mysql';
        _mysqlConnection = dbProvider.mysqlConnection;
        print('PatientImageProvider MySQL数据源设置成功: ${_mysqlConnection != null ? "成功" : "失败"}');
      } else {
        _dataSourceType = 'sqlite';
        print('使用SQLite连接...');
        // 获取 SQLite 数据库实例
        try {
          _sqliteDatabase = await dbProvider.sqliteDatabase;
          print('获取到的SQLite数据库实例: $_sqliteDatabase');
        } catch (e) {
          print('获取SQLite数据库失败: $e');
          // 尝试通过其他方式获取
          if (dbProvider.database != null) {
            _sqliteDatabase = dbProvider.database;
            print('通过备用方式获取SQLite数据库: $_sqliteDatabase');
          }
        }
        _dataSourceType = 'sqlite';
      }
      
      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);
      
      // 验证数据库连接
      await _validateDatabaseConnection();
      
      initialized = true;
      print('PatientImageProvider: 初始化完成: initialized = $initialized, _dataSourceType = $_dataSourceType');
      // 延迟通知以避免在build阶段调用setState
      Future.microtask(() => notifyListeners());
    } catch (e) {
      print('PatientImageProvider初始化失败: $e');
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
        if (_sqliteDatabase == null) {
          print('PatientImageProvider: SQLite数据库为null，跳过连接验证');
          return; // 不抛出异常，允许继续初始化
        }
        
        // 测试数据库连接
        await _sqliteDatabase!.rawQuery('SELECT 1');
        print('PatientImageProvider: SQLite连接验证成功');
      } else if (_dataSourceType == 'mysql') {
        if (_mysqlConnection == null) {
          print('PatientImageProvider: MySQL连接为null，跳过连接验证');
          return; // 不抛出异常，允许继续初始化
        }
        
        // 测试MySQL连接
        await _mysqlConnection!.query('SELECT 1');
        print('PatientImageProvider: MySQL连接验证成功');
      }
    } catch (e) {
      print('PatientImageProvider: 数据库连接验证失败: $e');
      // 不抛出异常，允许继续初始化
      print('PatientImageProvider: 连接验证失败，但允许继续初始化');
    }
  }

  // 获取当前数据库类型
  String get _currentDbType {
    return _dataSourceType;
  }

  // 检查数据库是否已初始化
  bool get _isDatabaseInitialized {
    return initialized;
  }

  // 获取患者材料列表
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    // 检查缓存
    if (_patientMaterialsCache.containsKey(patientId)) {
      print('PatientImageProvider: 使用缓存的患者材料数据: ${_patientMaterialsCache[patientId]!.length} 条');
      return _patientMaterialsCache[patientId]!;
    }

    if (_loadingStates[patientId] ?? false) {
      return _patientMaterialsCache[patientId] ?? [];
    }
    
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getPatientMaterials', () async {
      try {
      _setLoadingState(patientId, true);
      _clearError(patientId);
      
      // 检查是否已初始化
      if (!initialized) {
        print('PatientImageProvider: 尚未初始化，尝试自动初始化...');
        // 尝试自动初始化
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          print('PatientImageProvider: 自动初始化失败: $e');
          // 如果自动初始化失败，返回空列表而不是抛出异常
          return [];
        }
      }
      
      List<PatientMaterial> materials = [];
      
      if (_currentDbType == 'sqlite') {
        print('PatientImageProvider: 使用SQLite数据源');
        materials = await _getPatientMaterialsFromSQLite(patientId);
      } else if (_currentDbType == 'mysql') {
        print('PatientImageProvider: 使用MySQL数据源');
        materials = await _getPatientMaterialsFromMySQL(patientId);
      } else {
        throw Exception('未知的数据库类型: $_currentDbType');
      }
      
      print('PatientImageProvider: 成功获取患者材料: ${materials.length} 条');
      
      // 更新缓存
      _patientMaterialsCache[patientId] = materials;
      
      // 异步预加载图片数据，不阻塞主流程
      for (final material in materials) {
        if (material.id != null) {
          getMaterialImages(material.id!).catchError((e) {
            print('获取材料图片失败: $e');
          });
        }
      }
      
      _setLoadingState(patientId, false);
      return materials;
      } catch (e) {
        String errorMsg = '获取患者材料失败: $e';
        print('PatientImageProvider: $errorMsg');
        _setError(patientId, errorMsg);
        _setLoadingState(patientId, false);
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 获取材料图片列表
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    // 检查缓存
    if (_materialImagesCache.containsKey(materialId)) {
      print('PatientImageProvider: 使用缓存的材料图片数据: ${_materialImagesCache[materialId]!.length} 张');
      return _materialImagesCache[materialId]!;
    }
    
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getMaterialImages', () async {
      try {
      // 检查是否已初始化
      if (!initialized) {
        print('PatientImageProvider: 获取图片时未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          print('PatientImageProvider: 自动初始化失败: $e');
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
      
      print('PatientImageProvider: 成功获取材料图片: ${images.length} 张');
      
      // 更新缓存
      _materialImagesCache[materialId] = images;
      
      return images;
      } catch (e) {
        print('PatientImageProvider: 获取材料图片失败: $e');
        _materialImagesCache[materialId] = []; // 缓存空结果避免重复查询
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 获取患者所有图片（优化版本，避免重复查询）
  Future<List<MaterialImage>> getPatientImages(int patientId) async {
    try {
      // 检查是否有缓存的图片数据
      if (_patientMaterialsCache.containsKey(patientId)) {
        print('PatientImageProvider: 使用缓存的图片数据');
        return getCachedImages(patientId);
      }
      
      // 设置加载状态（只设置一次）
      _setLoadingState(patientId, true);
      _clearError(patientId);
      
      // 检查是否已初始化
      if (!initialized) {
        print('PatientImageProvider: 获取图片时未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          print('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }
      
      // 获取患者材料
      List<PatientMaterial> materials = [];
      if (_currentDbType == 'sqlite') {
        print('PatientImageProvider: 使用SQLite数据源获取患者材料');
        materials = await _getPatientMaterialsFromSQLite(patientId);
      } else if (_currentDbType == 'mysql') {
        print('PatientImageProvider: 使用MySQL数据源获取患者材料');
        materials = await _getPatientMaterialsFromMySQL(patientId);
      } else {
        throw Exception('未知的数据库类型: $_currentDbType');
      }
      
      // 更新材料缓存
      _patientMaterialsCache[patientId] = materials;
      
      // 获取所有图片（批量获取，避免多次notifyListeners）
      List<MaterialImage> allImages = [];
      for (final material in materials) {
        if (material.id != null) {
          try {
            List<MaterialImage> images = [];
            if (_currentDbType == 'sqlite') {
              images = await _getMaterialImagesFromSQLite(material.id!);
            } else if (_currentDbType == 'mysql') {
              images = await _getMaterialImagesFromMySQL(material.id!);
            }
            
            // 更新图片缓存
            _materialImagesCache[material.id!] = images;
            allImages.addAll(images);
          } catch (e) {
            print('PatientImageProvider: 获取材料 ${material.id} 的图片失败: $e');
          }
        }
      }
      
      print('PatientImageProvider: 获取患者所有图片完成: ${allImages.length} 张');
      
      // 清除加载状态（只清除一次）
      _setLoadingState(patientId, false);
      
      return allImages;
    } catch (e) {
      print('PatientImageProvider: 获取患者所有图片失败: $e');
      // 如果是连接错误，尝试重新初始化
      if (e.toString().contains('database') || e.toString().contains('连接')) {
        initialized = false; // 重置初始化状态
      }
      _setError(patientId, '获取患者图片失败: $e');
      _setLoadingState(patientId, false);
      return [];
    }
  }

  // 从SQLite获取患者材料
  Future<List<PatientMaterial>> _getPatientMaterialsFromSQLite(int patientId) async {
    try {
      print('PatientImageProvider: 开始获取SQLite数据库...');
      
      if (!initialized) {
        print('PatientImageProvider: SQLite数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          print('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }
      
      final db = _sqliteDatabase;
      print('PatientImageProvider: SQLite数据库状态: $db');
      
      if (db == null) {
        throw Exception('SQLite数据库不可用 - 数据库对象为null');
      }
      
      print('PatientImageProvider: 开始执行SQLite查询，患者ID: $patientId');
      
      try {
        final maps = await db.query(
          'patient_materials',
          where: 'patient_id = ?',
          whereArgs: [patientId],
          orderBy: 'created_at DESC',
        );
        
        print('PatientImageProvider: SQLite查询成功，结果行数: ${maps.length}');
        
        return maps.map((map) => PatientMaterial.fromMap(map)).toList();
      } catch (tableError) {
        print('PatientImageProvider: SQLite查询表不存在，尝试创建表: $tableError');
        // 如果表不存在，返回空列表而不是抛出异常
        return [];
      }
    } catch (e) {
      print('PatientImageProvider: SQLite查询患者材料失败: $e');
      return []; // 返回空列表而不是抛出异常
    }
  }

  // 从MySQL获取患者材料
  Future<List<PatientMaterial>> _getPatientMaterialsFromMySQL(int patientId) async {
    try {
      print('PatientImageProvider: 开始获取MySQL连接...');
      
      if (!initialized) {
        print('PatientImageProvider: MySQL数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          print('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }
      
      // 检查MySQL连接状态
      final connectionOk = await _ensureConnection();
      if (!connectionOk) {
        // 尝试自动重连
        final reconnected = await _autoReconnect();
        if (!reconnected) {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }
      
      final conn = _mysqlConnection;
      print('PatientImageProvider: MySQL连接状态: $conn');
      
      if (conn == null) {
        throw Exception('MySQL连接不可用 - 连接对象为null');
      }
      
      print('PatientImageProvider: 开始执行MySQL查询，患者ID: $patientId');
      
      final results = await conn.query(
        'SELECT * FROM patient_materials WHERE patient_id = ? ORDER BY created_at DESC',
        [patientId],
      );
      
      print('PatientImageProvider: MySQL查询成功，结果行数: ${results.length}');
      
      return results.map((row) => PatientMaterial.fromMap(_processMySQLRow(row))).toList();
    } catch (e) {
      // 检查是否是连接错误
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Cannot write to socket') ||
          e.toString().contains('Connection reset')) {
        print('PatientImageProvider: 检测到连接错误，尝试重连: $e');
        
        // 尝试重连
        final reconnected = await _autoReconnect();
        if (reconnected) {
          // 重连成功，重新执行查询
          return await _getPatientMaterialsFromMySQL(patientId);
        } else {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }
      
      print('PatientImageProvider: MySQL查询患者材料失败: $e');
      rethrow;
    }
  }

  // 从SQLite获取材料图片
  Future<List<MaterialImage>> _getMaterialImagesFromSQLite(int materialId) async {
    try {
      print('PatientImageProvider: 开始获取SQLite数据库...');
      
      if (!initialized) {
        print('PatientImageProvider: SQLite数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          print('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }
      
      final db = _sqliteDatabase;
      print('PatientImageProvider: SQLite数据库状态: $db');
      
      if (db == null) {
        throw Exception('SQLite数据库不可用 - 数据库对象为null');
      }
      
      print('PatientImageProvider: 开始执行SQLite查询，材料ID: $materialId');
      
      try {
        final maps = await db.query(
          'material_images',
          where: 'material_id = ?',
          whereArgs: [materialId],
          orderBy: 'created_at DESC',
        );
        
        print('PatientImageProvider: SQLite查询成功，结果行数: ${maps.length}');
        
        return maps.map((map) => MaterialImage.fromMap(map)).toList();
      } catch (tableError) {
        print('PatientImageProvider: SQLite查询表不存在: $tableError');
        return []; // 表不存在时返回空列表
      }
    } catch (e) {
      print('PatientImageProvider: SQLite查询材料图片失败: $e');
      return []; // 返回空列表而不是抛出异常
    }
  }

  // 从MySQL获取材料图片
  Future<List<MaterialImage>> _getMaterialImagesFromMySQL(int materialId) async {
    try {
      print('PatientImageProvider: 开始获取MySQL连接...');
      
      if (!initialized) {
        print('PatientImageProvider: MySQL数据库尚未初始化，尝试自动初始化...');
        try {
          await initializeFromDatabase(_databaseProvider);
        } catch (e) {
          print('PatientImageProvider: 自动初始化失败: $e');
          return [];
        }
      }
      
      // 检查MySQL连接状态
      final connectionOk = await _ensureConnection();
      if (!connectionOk) {
        // 尝试自动重连
        final reconnected = await _autoReconnect();
        if (!reconnected) {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }
      
      final conn = _mysqlConnection;
      print('PatientImageProvider: MySQL连接状态: $conn');
      
      if (conn == null) {
        throw Exception('MySQL连接不可用 - 连接对象为null');
      }
      
      print('PatientImageProvider: 开始执行MySQL查询，材料ID: $materialId');
      
      final results = await conn.query(
        'SELECT * FROM material_images WHERE material_id = ? ORDER BY created_at DESC',
        [materialId],
      );
      
      print('PatientImageProvider: MySQL查询成功，结果行数: ${results.length}');
      
      return results.map((row) => MaterialImage.fromMap(_processMySQLRow(row))).toList();
    } catch (e) {
      // 检查是否是连接错误
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Cannot write to socket') ||
          e.toString().contains('Connection reset')) {
        print('PatientImageProvider: 检测到连接错误，尝试重连: $e');
        
        // 尝试重连
        final reconnected = await _autoReconnect();
        if (reconnected) {
          // 重连成功，重新执行查询
          return await _getMaterialImagesFromMySQL(materialId);
        } else {
          throw Exception('MySQL连接失败，请检查网络连接');
        }
      }
      
      print('PatientImageProvider: MySQL查询材料图片失败: $e');
      rethrow;
    }
  }

  // 清除患者缓存
  void clearPatientCache(int patientId) {
    _patientMaterialsCache.remove(patientId);
    _loadingStates.remove(patientId);
    _errorStates.remove(patientId);
    
    // 清除相关的材料图片缓存
    final materials = _patientMaterialsCache[patientId];
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          _materialImagesCache.remove(material.id);
        }
      }
    }
    
    _safeNotifyListeners();
  }

  // 清除所有缓存
  void clearAllCache() {
    _patientMaterialsCache.clear();
    _materialImagesCache.clear();
    _loadingStates.clear();
    _errorStates.clear();
    _safeNotifyListeners();
  }

  // 设置加载状态
  void _setLoadingState(int patientId, bool isLoading) {
    _loadingStates[patientId] = isLoading;
    _safeNotifyListeners();
  }

  // 设置错误状态
  void _setError(int patientId, String error) {
    _errorStates[patientId] = error;
    _safeNotifyListeners();
  }

  // 清除错误状态
  void _clearError(int patientId) {
    _errorStates.remove(patientId);
    _safeNotifyListeners();
  }

  // 安全地通知监听器，避免在build过程中调用
  Timer? _notifyTimer;
  void _safeNotifyListeners() {
    // 取消之前的定时器
    _notifyTimer?.cancel();
    
    // 使用防抖机制，延迟50ms后通知，避免频繁触发
    _notifyTimer = Timer(const Duration(milliseconds: 50), () {
      notifyListeners();
    });
  }

  // 获取加载状态
  bool isLoading(int patientId) {
    return _loadingStates[patientId] ?? false;
  }

  // 获取错误状态
  String? getError(int patientId) {
    return _errorStates[patientId];
  }

  // 检查是否有缓存数据
  bool hasCachedData(int patientId) {
    return _patientMaterialsCache.containsKey(patientId);
  }

  // 获取缓存的患者材料数量
  int getCachedMaterialCount(int patientId) {
    return _patientMaterialsCache[patientId]?.length ?? 0;
  }

  // 获取缓存的图片数量
  int getCachedImageCount(int patientId) {
    int count = 0;
    final materials = _patientMaterialsCache[patientId];
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          count += _materialImagesCache[material.id]?.length ?? 0;
        }
      }
    }
    return count;
  }

  // 同步获取缓存的图片数据
  List<MaterialImage> getCachedImages(int patientId) {
    List<MaterialImage> allImages = [];
    final materials = _patientMaterialsCache[patientId];
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          final images = _materialImagesCache[material.id];
          if (images != null) {
            allImages.addAll(images);
          }
        }
      }
    }
    return allImages;
  }

  // 同步获取缓存的材料数据
  List<PatientMaterial> getCachedMaterials(int patientId) {
    return _patientMaterialsCache[patientId] ?? [];
  }

  // 强制刷新患者数据
  Future<void> refreshPatientData(int patientId) async {
    // 清除缓存
    _patientMaterialsCache.remove(patientId);
    _materialImagesCache.remove(patientId);
    
    // 重新获取数据
    await getPatientMaterials(patientId);
  }

  // 检查并确保连接可用
  Future<bool> _ensureConnection() async {
    if (_dataSourceType != 'mysql') return true;
    
    if (_mysqlConnection == null) {
      print('PatientImageProvider: MySQL连接对象为null');
      return false;
    }
    
    try {
      // 测试连接
      await _mysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      print('PatientImageProvider: MySQL连接检查成功');
      return true;
    } catch (e) {
      print('PatientImageProvider: 连接检查失败: $e');
      return false;
    }
  }

  // 自动重连
  Future<bool> _autoReconnect() async {
    try {
      print('PatientImageProvider: 尝试自动重连MySQL...');
      
      // 等待一段时间后重试
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 重新获取连接
      _mysqlConnection = _databaseProvider.mysqlConnection;
      
      if (_mysqlConnection == null) {
        print('PatientImageProvider: 无法自动重连，DatabaseProvider返回null');
        return false;
      }
      
      // 重新检查连接
      final success = await _ensureConnection();
      
      if (success) {
        print('PatientImageProvider: 自动重连成功');
        return true;
      } else {
        throw Exception('重连失败');
      }
    } catch (e) {
      print('PatientImageProvider: 自动重连失败: $e');
      return false;
    }
  }

  // 检查SQLite数据库状态
  Future<bool> _checkSQLiteConnection() async {
    try {
      if (_sqliteDatabase == null) {
        print('PatientImageProvider: SQLite数据库对象为null');
        return false;
      }
      
      await _sqliteDatabase!.rawQuery('SELECT 1');
      print('PatientImageProvider: SQLite连接检查成功');
      return true;
    } catch (e) {
      print('PatientImageProvider: SQLite连接检查失败: $e');
      return false;
    }
  }
}
