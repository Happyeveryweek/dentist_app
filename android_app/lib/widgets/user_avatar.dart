import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 用户头像组件
///
/// 根据用户头像数据、角色和用户名显示对应的头像，显示优先级：
/// 1. 用户上传的头像（imageData）
/// 2. 角色对应的默认头像图片（doctor.png / nurse.png）
/// 3. 用户名首字母
class UserAvatar extends StatelessWidget {
  /// 用户头像二进制数据（BLOB）
  final List<int>? imageData;

  /// 用户名（用于首字母兜底显示）
  final String username;

  /// 用户角色（admin / doctor / user）
  final String role;

  /// 头像半径
  final double radius;

  const UserAvatar({
    super.key,
    this.imageData,
    required this.username,
    required this.role,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageData != null && imageData!.isNotEmpty;
    final defaultImage = _getDefaultAvatarImage(role);

    return CircleAvatar(
      radius: radius,
      backgroundColor: _getRoleColor(role),
      backgroundImage:
          hasImage ? MemoryImage(Uint8List.fromList(imageData!)) : defaultImage,
      child:
          (hasImage || defaultImage != null)
              ? null
              : Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
    );
  }

  /// 获取角色对应的背景色
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'doctor':
        return Colors.green;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// 获取角色对应的默认头像图片
  ImageProvider<Object>? _getDefaultAvatarImage(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'doctor':
        return const AssetImage('assets/icons/doctor.png');
      case 'user':
        return const AssetImage('assets/icons/nurse.png');
      default:
        return null;
    }
  }
}
