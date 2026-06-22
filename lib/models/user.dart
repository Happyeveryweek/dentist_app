import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';

class User {
  final int? id;
  final String username;
  final String? email;
  final String password;
  final String role;
  final DateTime created_at;
  final String? doctor;
  final String? avatar; // 头像名称字段
  final String? modulePermissions; // 权限配置JSON字符串
  final List<int>? imageData; // 头像图片数据（BLOB）

  User({
    this.id,
    required this.username,
    this.email,
    required this.password,
    required this.role,
    DateTime? created_at,
    this.doctor,
    this.avatar, // 头像名称参数
    this.modulePermissions, // 权限配置参数
    this.imageData, // 头像图片数据参数
  }) : created_at = created_at ?? DateTime.now();

  // 从Map构造User对象
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: _safeString(map['username']),
      email: _safeString(map['email']),
      password: _safeString(map['password']),
      role: _safeString(map['role']),
      created_at: _parseDateTime(map['created_at']),
      doctor: _safeString(map['doctor']),
      avatar: _safeString(map['avatar']), // 头像名称映射
      modulePermissions: _safeString(map['module_permissions']), // 权限配置映射
      imageData: _safeBlobData(map['image_data']), // 头像图片数据映射
    );
  }

  // 将User对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      if (email != null) 'email': email,
      'password': password,
      'role': role,
      'created_at': DateTimeFormatter.toDbString(created_at),
      if (doctor != null) 'doctor': doctor,
      if (avatar != null) 'avatar': avatar, // 头像名称映射
      if (modulePermissions != null) 'module_permissions': modulePermissions, // 权限配置映射
      if (imageData != null) 'image_data': imageData, // 头像图片数据映射
    };
  }

  // 复制User对象，但可以修改部分属性
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? password,
    String? role,
    DateTime? created_at,
    String? doctor,
    String? avatar, // 头像名称参数
    String? modulePermissions, // 权限配置参数
    List<int>? imageData, // 头像图片数据参数
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      created_at: created_at ?? this.created_at,
      doctor: doctor ?? this.doctor,
      avatar: avatar ?? this.avatar, // 头像名称复制
      modulePermissions: modulePermissions ?? this.modulePermissions, // 权限配置复制
      imageData: imageData ?? this.imageData, // 头像图片数据复制
    );
  }

  // 安全地处理字符串字段，避免Blob类型错误
  static String _safeString(dynamic value) {
    if (value == null) return '';
    
    // 如果是字符串类型，直接返回
    if (value is String) return value;
    
    // 如果是Blob类型或其他二进制类型，尝试转换为字符串
    if (value is List<int>) {
      try {
        return String.fromCharCodes(value);
      } catch (e) {
        return '';
      }
    }
    
    // 其他类型直接转换为字符串
    return value.toString();
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
        print('转换BLOB数据失败: $e');
        return null;
      }
    }
    
    return null;
  }

  // 解析日期时间字符串或处理DateTime对象
  static DateTime _parseDateTime(dynamic dateTime) {
    // 如果已经是DateTime类型，直接返回
    if (dateTime is DateTime) {
      return dateTime;
    }

    // 转换为字符串处理
    String dateTimeStr = dateTime.toString();
    return DateTimeFormatter.fromDbString(dateTimeStr);
  }

  // 获取角色的显示名称
  String get roleDisplay {
    switch (role) {
      case 'admin':
        return '管理员';
      case 'doctor':
        return '医生';
      case 'assistant':
        return '助理';
      case 'receptionist':
        return '前台';
      default:
        return role;
    }
  }

  // 判断是否为管理员
  bool get isAdmin => role == 'admin';

  // 获取允许访问的模块列表
  List<String> get allowedModules {
    if (isAdmin) {
      // 管理员拥有所有模块权限
      return ['dashboard', 'patients', 'appointments', 'financial', 'materials', 'purchase', 'users', 'settings'];
    }
    
    if (modulePermissions == null || modulePermissions!.isEmpty) {
      // 默认权限：仪表盘
      return ['dashboard'];
    }
    
    try {
      final Map<String, dynamic> permissions = jsonDecode(modulePermissions!);
      final List<String> allowed = [];
      
      // 仪表盘对所有用户可见
      allowed.add('dashboard');
      
      // 添加其他有权限的模块
      permissions.forEach((module, hasPermission) {
        if (hasPermission == true && module != 'dashboard') {
          allowed.add(module);
        }
      });
      
      return allowed;
    } catch (e) {
      // JSON解析失败时返回默认权限
      return ['dashboard'];
    }
  }

  // 检查是否有特定模块的权限
  bool hasModulePermission(String module) {
    if (isAdmin) {
      // 管理员拥有所有权限
      return true;
    }
    
    if (module == 'dashboard') {
      // 仪表盘对所有用户可见
      return true;
    }
    
    if (modulePermissions == null || modulePermissions!.isEmpty) {
      return false;
    }
    
    try {
      final Map<String, dynamic> permissions = jsonDecode(modulePermissions!);
      return permissions[module] == true;
    } catch (e) {
      return false;
    }
  }

  // 获取权限映射
  Map<String, bool> get permissionMap {
    if (isAdmin) {
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
      // 默认权限配置
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
      final Map<String, dynamic> permissions = jsonDecode(modulePermissions!);
      final Map<String, bool> result = {
        'dashboard': true, // 仪表盘始终可见
        'patients': false,
        'appointments': false,
        'financial': false,
        'materials': false,
        'purchase': false,
        'users': false,
        'settings': false,
      };
      
      // 更新实际权限
      permissions.forEach((module, hasPermission) {
        if (result.containsKey(module)) {
          result[module] = hasPermission == true;
        }
      });
      
      return result;
    } catch (e) {
      // JSON解析失败时返回默认权限
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
}
