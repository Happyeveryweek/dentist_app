import 'dart:convert';
import '../utils/datetime_formatter.dart';
import '../utils/app_logger.dart';

class User {
  final int? id;
  final String username;
  final String? email;
  final String password;
  final String role;
  final DateTime createdAt;
  final String? doctor;
  final String? avatar;
  final String? modulePermissions;
  final List<int>? imageData; // 头像图片数据（BLOB）

  User({
    this.id,
    required this.username,
    this.email,
    required this.password,
    required this.role,
    DateTime? createdAt,
    this.doctor,
    this.avatar,
    this.modulePermissions,
    this.imageData, // 头像图片数据参数
  }) : createdAt = createdAt ?? DateTime.now();

  factory User.fromMap(
    Map<String, dynamic> map, {
    String dataSource = 'sqlite',
  }) {
    return User(
      id: map['id'] as int?,
      username: map['username']?.toString() ?? '',
      email: map['email']?.toString(),
      password: map['password']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      createdAt: _parseDateTime(map['created_at'], dataSource),
      doctor: map['doctor']?.toString(), // 医生姓名直接使用原始值，不转换
      avatar: map['avatar']?.toString(),
      modulePermissions: map['module_permissions']?.toString(),
      imageData: _safeBlobData(map['image_data']), // 头像图片数据映射
    );
  }

  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        if (id != null) 'id': id,
        'username': username,
        if (email != null) 'email': email,
        'password': password,
        'role': role,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        if (doctor != null) 'doctor': doctor,
        if (avatar != null) 'avatar': avatar,
        if (modulePermissions != null) 'module_permissions': modulePermissions,
        if (imageData != null) 'image_data': imageData, // 头像图片数据映射
      };
    } else {
      // SQLite数据源
      return {
        if (id != null) 'id': id,
        'username': username,
        if (email != null) 'email': email,
        'password': password,
        'role': role,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        if (doctor != null) 'doctor': doctor,
        if (avatar != null) 'avatar': avatar,
        if (modulePermissions != null) 'module_permissions': modulePermissions,
        if (imageData != null) 'image_data': imageData, // 头像图片数据映射
      };
    }
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? password,
    String? role,
    DateTime? createdAt,
    String? doctor,
    String? avatar,
    String? modulePermissions,
    List<int>? imageData, // 头像图片数据参数
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      doctor: doctor ?? this.doctor,
      avatar: avatar ?? this.avatar,
      modulePermissions: modulePermissions ?? this.modulePermissions,
      imageData: imageData ?? this.imageData, // 头像图片数据复制
    );
  }

  // 安全地处理BLOB数据
  static List<int>? _safeBlobData(dynamic value) {
    if (value == null) return null;

    // 如果已经是List<int>类型，直接返回
    if (value is List<int>) return value;

    // 如果是Uint8List类型，转换为List<int>
    if (value is List) {
      try {
        return List<int>.from(value);
      } catch (e) {
        AppLogger.info('转换BLOB数据失败: $e');
        return null;
      }
    }

    return null;
  }

  // 权限相关的辅助方法

  /// 获取用户允许访问的模块列表
  List<String> get allowedModules {
    if (role == 'admin') {
      // 管理员拥有所有权限
      return [
        'dashboard',
        'patients',
        'appointments',
        'financial',
        'materials',
        'purchase',
        'users',
        'settings',
      ];
    }

    if (modulePermissions == null || modulePermissions!.isEmpty) {
      // 如果没有权限配置，返回默认的基础权限
      return ['dashboard'];
    }

    try {
      final permissions =
          jsonDecode(modulePermissions!) as Map<String, dynamic>;
      return permissions.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      AppLogger.info('解析权限配置失败: $e');
      return ['dashboard']; // 默认只有仪表盘权限
    }
  }

  /// 检查用户是否有特定模块的权限
  bool hasModulePermission(String module) {
    if (role == 'admin') {
      return true; // 管理员拥有所有权限
    }

    if (module == 'dashboard') {
      return true; // 仪表盘对所有用户可见
    }

    return allowedModules.contains(module);
  }

  /// 获取权限映射
  Map<String, bool> get permissionMap {
    if (role == 'admin') {
      // 管理员拥有所有权限
      return {
        'dashboard': true,
        'patients': true,
        'appointments': true,
        'financial': true,
        'materials': true,
        'purchase': true,
        'users': true,
        'settings': true,
      };
    }

    if (modulePermissions == null || modulePermissions!.isEmpty) {
      // 如果没有权限配置，返回默认权限
      return {
        'dashboard': true,
        'patients': false,
        'appointments': false,
        'financial': false,
        'materials': false,
        'purchase': false,
        'users': false,
        'settings': false,
      };
    }

    try {
      final permissions =
          jsonDecode(modulePermissions!) as Map<String, dynamic>;
      return {
        'dashboard': true, // 仪表盘始终可访问
        'patients': permissions['patients'] == true,
        'appointments': permissions['appointments'] == true,
        'financial': permissions['financial'] == true,
        'materials': permissions['materials'] == true,
        'purchase': permissions['purchase'] == true,
        'users': permissions['users'] == true,
        'settings': permissions['settings'] == true,
      };
    } catch (e) {
      AppLogger.info('解析权限配置失败: $e');
      return {
        'dashboard': true,
        'patients': false,
        'appointments': false,
        'financial': false,
        'materials': false,
        'purchase': false,
        'users': false,
        'settings': false,
      };
    }
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, role: $role, doctor: $doctor, avatar: $avatar, modulePermissions: $modulePermissions, imageData: ${imageData != null ? '${imageData!.length} bytes' : 'null'})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // 解析日期时间字符串或处理DateTime对象 - 使用统一格式
  static DateTime _parseDateTime(dynamic dateTime, String dataSource) {
    // 如果已经是DateTime类型，直接返回
    if (dateTime is DateTime) {
      return dateTime;
    }

    // 如果是字符串，使用统一的时间格式工具解析
    if (dateTime is String) {
      return DateTimeFormatter.fromDbString(dateTime);
    }

    // 如果无法解析，返回当前时间
    AppLogger.info('无法解析日期时间: $dateTime，使用当前时间');
    return DateTime.now();
  }
}
