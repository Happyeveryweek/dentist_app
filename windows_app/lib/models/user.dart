import 'package:intl/intl.dart';

class User {
  final int? id;
  final String username;
  final String? email;
  final String password;
  final String role;
  final DateTime created_at;
  final String? doctor;

  User({
    this.id,
    required this.username,
    this.email,
    required this.password,
    required this.role,
    DateTime? created_at,
    this.doctor,
  }) : created_at = created_at ?? DateTime.now();

  // 从Map构造User对象
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      role: map['role'],
      created_at: _parseDateTime(map['created_at']),
      doctor: map['doctor'],
    );
  }

  // 将User对象转换为Map
  Map<String, dynamic> toMap() {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return {
      if (id != null) 'id': id,
      'username': username,
      if (email != null) 'email': email,
      'password': password,
      'role': role,
      'created_at': dateFormat.format(created_at),
      if (doctor != null) 'doctor': doctor,
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
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      created_at: created_at ?? this.created_at,
      doctor: doctor ?? this.doctor,
    );
  }

  // 解析日期时间字符串或处理DateTime对象
  static DateTime _parseDateTime(dynamic dateTime) {
    // 如果已经是DateTime类型，直接返回
    if (dateTime is DateTime) {
      return dateTime;
    }

    // 转换为字符串处理
    String dateTimeStr = dateTime.toString();
    try {
      // 首先尝试解析标准格式
      return DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTimeStr);
    } catch (e) {
      // 尝试解析ISO格式
      try {
        return DateTime.parse(dateTimeStr);
      } catch (e) {
        // 尝试其他常见格式
        try {
          return DateFormat('yyyy-MM-dd').parse(dateTimeStr);
        } catch (e) {
          // 如果无法解析，返回当前时间
          return DateTime.now();
        }
      }
    }
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
}
