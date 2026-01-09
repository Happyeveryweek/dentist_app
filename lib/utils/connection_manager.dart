import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import '../providers/database_provider.dart';

/// 连接管理器
/// 监控网络状态变化并管理数据库连接
class ConnectionManager {
  static ConnectionManager? _instance;
  static ConnectionManager get instance => _instance ??= ConnectionManager._();
  
  ConnectionManager._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  DatabaseProvider? _databaseProvider;
  Timer? _reconnectTimer;
  bool _isMonitoring = false;
  bool _connectivityPluginAvailable = true;

  /// 开始监控网络状态
  void startMonitoring(DatabaseProvider databaseProvider) {
    if (_isMonitoring) return;
    
    _databaseProvider = databaseProvider;
    _isMonitoring = true;
    
    print('🔧 连接管理器启动，当前数据库类型: ${databaseProvider.dbType}');
    
    // 检查数据库是否还在初始化中
    if (databaseProvider.dbType == 'initializing') {
      print('⏳ 数据库正在初始化中，等待初始化完成后再启动网络监控');
      // 监听数据库提供者的变化，等待初始化完成
      databaseProvider.addListener(_onDatabaseProviderChanged);
      return;
    }
    
    _startNetworkMonitoringIfNeeded();
  }

  /// 数据库提供者状态变化监听
  void _onDatabaseProviderChanged() {
    if (_databaseProvider == null) return;
    
    // 如果数据库初始化完成且还没有启动网络监控
    if (_databaseProvider!.isInitialized && _connectivitySubscription == null) {
      print('🔧 数据库初始化完成，现在启动网络监控');
      _databaseProvider!.removeListener(_onDatabaseProviderChanged);
      _startNetworkMonitoringIfNeeded();
    }
  }

  /// 根据数据库类型启动网络监控
  void _startNetworkMonitoringIfNeeded() {
    if (_databaseProvider == null) return;
    
    final dbType = _databaseProvider!.dbType;
    print('🔧 根据数据库类型启动网络监控: $dbType');
    
    // 只有在使用 MySQL 时才启动网络监控
    if (dbType == 'mysql') {
      print('🌐 MySQL模式：启动网络连接状态监控');
      
      try {
        _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          _onConnectivityChanged,
          onError: (error) {
            print('❌ 网络状态监听错误: $error');
          },
        );
        
        print('✅ MySQL网络监控已启动');
      } catch (e) {
        _connectivityPluginAvailable = false;
        print('❌ 启动网络监控失败: $e');
        
        if (e is MissingPluginException) {
          print('⚠️ connectivity_plus插件未正确注册，网络监控功能已禁用');
          print('💡 建议执行: flutter clean && flutter pub get && flutter run');
        } else {
          print('⚠️ 网络监控功能不可用，但MySQL连接仍然可以正常工作');
        }
        
        // 不抛出异常，让应用继续运行
      }
    } else if (dbType == 'sqlite') {
      print('📱 SQLite模式：本地数据库无需网络监控');
    } else {
      print('❓ 未知数据库类型: $dbType');
    }
  }

  /// 停止监控网络状态
  void stopMonitoring() {
    print('🌐 停止监控网络连接状态');
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    // 移除数据库提供者监听器
    _databaseProvider?.removeListener(_onDatabaseProviderChanged);
    
    _isMonitoring = false;
    _databaseProvider = null;
  }

  /// 网络状态变化处理
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    print('🌐 网络状态变化: $results');
    
    // 处理多个连接结果，优先处理最好的连接
    ConnectivityResult primaryResult = ConnectivityResult.none;
    
    // 按优先级选择最佳连接：WiFi > 以太网 > 移动网络 > 无连接
    if (results.contains(ConnectivityResult.wifi)) {
      primaryResult = ConnectivityResult.wifi;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      primaryResult = ConnectivityResult.ethernet;
    } else if (results.contains(ConnectivityResult.mobile)) {
      primaryResult = ConnectivityResult.mobile;
    } else if (results.contains(ConnectivityResult.none)) {
      primaryResult = ConnectivityResult.none;
    }
    
    print('🌐 主要网络状态: $primaryResult');
    
    switch (primaryResult) {
      case ConnectivityResult.wifi:
        _handleWifiConnected();
        break;
      case ConnectivityResult.mobile:
        _handleMobileConnected();
        break;
      case ConnectivityResult.none:
        _handleNetworkDisconnected();
        break;
      case ConnectivityResult.ethernet:
        _handleEthernetConnected();
        break;
      default:
        print('🌐 未知网络状态: $primaryResult');
    }
  }

  /// 处理WiFi连接
  void _handleWifiConnected() {
    print('📶 WiFi已连接');
    _scheduleConnectionCheck('WiFi连接');
  }

  /// 处理移动网络连接
  void _handleMobileConnected() {
    print('📱 移动网络已连接');
    _scheduleConnectionCheck('移动网络连接');
  }

  /// 处理以太网连接
  void _handleEthernetConnected() {
    print('🔌 以太网已连接');
    _scheduleConnectionCheck('以太网连接');
  }

  /// 处理网络断开
  void _handleNetworkDisconnected() {
    print('❌ 网络已断开');
    _reconnectTimer?.cancel();
    
    if (_databaseProvider?.dbType == 'mysql') {
      // 标记连接为断开状态，但不立即尝试重连
      print('⚠️ MySQL连接可能受到网络断开影响');
    }
  }

  /// 安排连接检查
  void _scheduleConnectionCheck(String reason) {
    // 只对 MySQL 连接进行检查，SQLite 不需要网络
    if (_databaseProvider?.dbType != 'mysql') {
      print('📱 SQLite模式，跳过网络连接检查');
      return;
    }
    
    // 取消之前的定时器
    _reconnectTimer?.cancel();
    
    // 延迟2秒后检查连接，给网络一些稳定时间
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _performConnectionCheck(reason);
    });
  }

  /// 执行连接检查
  Future<void> _performConnectionCheck(String reason) async {
    if (_databaseProvider == null || _databaseProvider!.dbType != 'mysql') return;
    
    try {
      print('🔍 因为$reason，检查MySQL连接状态...');
      
      final isConnected = await _databaseProvider!.ensureConnection();
      if (isConnected) {
        print('✅ MySQL连接正常');
      } else {
        print('❌ MySQL连接异常，将在下次操作时自动重连');
      }
    } catch (e) {
      print('❌ 连接检查失败: $e');
    }
  }

  /// 手动触发连接检查
  Future<bool> checkConnection() async {
    if (_databaseProvider?.dbType != 'mysql') return true;
    
    try {
      return await _databaseProvider!.ensureConnection();
    } catch (e) {
      print('❌ 手动连接检查失败: $e');
      return false;
    }
  }

  /// 检查网络监控是否可用
  bool get isNetworkMonitoringAvailable => _connectivityPluginAvailable;


}