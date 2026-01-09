import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/user.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:line_icons/line_icons.dart'; // 暂时注释掉，使用FontAwesome替代

class DentalIcons {
  // 基础图标 - 使用Material Icons作为后备
  static const IconData tooth = FontAwesomeIcons.tooth;
  static const IconData teeth = Icons.medical_services;
  static const IconData teethOpen = Icons.medical_services;
  static const IconData stethoscope = Icons.medical_services;
  static const IconData heartPulse = Icons.favorite;
  static const IconData userDoctor = Icons.person;
  static const IconData userNurse = Icons.person;
  static const IconData hospitalUser = Icons.person;
  static const IconData hospital = Icons.local_hospital;
  static const IconData kitMedical = Icons.medical_services;
  static const IconData pills = Icons.medical_services;
  static const IconData syringe = Icons.medical_services;
  static const IconData thermometer = Icons.thermostat;
  static const IconData bandage = Icons.medical_services;
  static const IconData microscope = Icons.biotech;
  static const IconData xRay = Icons.medical_services;
  static const IconData clipboard = Icons.assignment;
  static const IconData clipboardUser = Icons.assignment_ind;
  static const IconData calendarCheck = Icons.event_available;
  static const IconData calendarPlus = Icons.add_box;
  static const IconData clockRotateLeft = Icons.history;
  static const IconData fileInvoiceDollar = Icons.receipt;
  static const IconData chartLine = Icons.show_chart;
  static const IconData chartPie = Icons.pie_chart;
  static const IconData shoppingCart = Icons.shopping_cart;
  
  // 替代图标（使用Material Icons）
  static const IconData userMd = Icons.person;
  static const IconData userPlus = Icons.person_add;
  static const IconData medkit = Icons.medical_services;
  static const IconData heartbeat = Icons.favorite;
  static const IconData ambulance = Icons.local_shipping;
  static const IconData wheelchair = Icons.accessible;
  static const IconData bed = Icons.bed;
  static const IconData procedures = Icons.healing;
  static const IconData prescriptionBottle = Icons.medical_services;
  
  // 牙科治疗相关图标（使用Material Icons）
  static const IconData cleaning = Icons.cleaning_services; // 洁治
  static const IconData filling = Icons.build; // 充填
  static const IconData crown = Icons.star; // 冠修复
  static const IconData bridge = Icons.link; // 桥修复
  static const IconData extraction = Icons.content_cut; // 拔牙
  static const IconData orthodontics = Icons.straighten; // 正畸
  static const IconData implant = Icons.construction; // 种植
  static const IconData rootCanal = Icons.linear_scale; // 根管治疗
  static const IconData dentures = Icons.medical_services; // 义齿
  static const IconData whitening = Icons.star_border; // 美白
  static const IconData periodontics = Icons.nature; // 牙周治疗
  static const IconData surgery = Icons.medical_services; // 手术
  
  // 状态图标（使用Material Icons）
  static const IconData completed = Icons.check_circle;
  static const IconData pending = Icons.schedule;
  static const IconData cancelled = Icons.cancel;
  static const IconData warning = Icons.warning;
  static const IconData emergency = Icons.error;
  
  // 性别图标（使用Material Icons）
  static const IconData male = Icons.male;
  static const IconData female = Icons.female;
  static const IconData child = Icons.child_care;
  
  // 获取治疗类型对应的图标
  static IconData getTreatmentIcon(String treatmentType) {
    switch (treatmentType.toLowerCase()) {
      case '洁治':
      case '洗牙':
        return cleaning;
      case '充填':
      case '补牙':
        return filling;
      case '冠修复':
      case '牙冠':
        return crown;
      case '桥修复':
        return bridge;
      case '拔牙':
      case '拔除':
        return extraction;
      case '正畸':
      case '矫正':
        return orthodontics;
      case '种植':
      case '植牙':
        return implant;
      case '根管治疗':
      case '根管':
        return rootCanal;
      case '义齿':
      case '假牙':
        return dentures;
      case '美白':
        return whitening;
      case '牙周治疗':
      case '牙周':
        return periodontics;
      case '手术':
        return surgery;
      default:
        return tooth;
    }
  }
  
  // 获取状态对应的图标
  static IconData getStatusIcon(String status) {
    switch (status) {
      case '已完成':
        return completed;
      case '已预约':
        return pending;
      case '已取消':
        return cancelled;
      case '未到诊':
        return warning;
      case '紧急':
        return emergency;
      default:
        return pending;
    }
  }
  
  // 获取性别对应的图标
  static IconData getGenderIcon(String gender) {
    switch (gender) {
      case '男':
        return male;
      case '女':
        return female;
      default:
        return child;
    }
  }
}

// 牙科主题颜色
class DentalColors {
  // 主色调 - 现代医疗蓝绿渐变
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color tertiary = Color(0xFF00BCD4);
  static const Color accent = Color(0xFF4FC3F7);
  
  // 功能颜色
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Gender specific colors
  static const Color femalePink = Color(0xFFE91E63);
  static const Color maleBlue = Color(0xFF2196F3);
  
  // 状态颜色
  static const Color completed = Color(0xFF66BB6A);
  static const Color pending = Color(0xFFFFB74D);
  static const Color cancelled = Color(0xFFEF5350);
  static const Color urgent = Color(0xFFFF7043);
  
  // 中性颜色
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FCFF);
  static const Color backgroundDark = Color(0xFFF0F9FF);
  static const Color onSurface = Color(0xFF263238);
  static const Color onSurfaceVariant = Color(0xFF546E7A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  

  
  // 卡片颜色
  static const Color cardPrimary = Color(0xFFE3F2FD);
  static const Color cardSecondary = Color(0xFFE0F2F1);
  static const Color cardSuccess = Color(0xFFE8F5E8);
  static const Color cardWarning = Color(0xFFFFF3E0);
  static const Color cardError = Color(0xFFFFEBEE);
  
  // 牙科专业颜色
  static const Color dentalBlue = Color(0xFF0D47A1);
  static const Color dentalTeal = Color(0xFF00695C);
  static const Color dentalGreen = Color(0xFF2E7D32);
  static const Color toothWhite = Color(0xFFFFFDE7);
  static const Color gumPink = Color(0xFFE1BEE7);
  
  // 现代医疗渐变
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2196F3), Color(0xFF03DAC6), Color(0xFF00BCD4)],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF03DAC6), Color(0xFF4FC3F7)],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66BB6A), Color(0xFF81C784)],
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB74D), Color(0xFFFFCC02)],
  );
  
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF5350), Color(0xFFFF7043)],
  );
  
  // 背景装饰渐变
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FCFF), Color(0xFFE3F2FD)],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, Color(0xFFF5F7FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // 阴影颜色
  static Color shadowLight = const Color(0xFF2196F3).withOpacity(0.1);
  static Color shadowMedium = const Color(0xFF2196F3).withOpacity(0.2);
  static Color shadowDark = const Color(0xFF2196F3).withOpacity(0.3);
}

// 牙科主题组件
class DentalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? elevation;
  final VoidCallback? onTap;
  
  const DentalCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        gradient: color == null ? DentalColors.cardGradient : null,
        boxShadow: [
          BoxShadow(
            color: DentalColors.shadowLight,
            blurRadius: 10.0,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 1.0,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(20.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.0),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

// 渐变按钮组件
class DentalGradientButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final Gradient? gradient;
  
  const DentalGradientButton({
    Key? key,
    this.text,
    this.child,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.gradient,
  }) : assert(text != null || child != null, 'Either text or child must be provided'),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: DentalColors.primary,
            width: 2.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: child ?? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: DentalColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (icon != null) ...[
                    Icon(icon, color: DentalColors.primary, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text!,
                    style: TextStyle(
                      color: DentalColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? DentalColors.primaryGradient,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: DentalColors.primary.withOpacity(0.3),
            blurRadius: 8.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: child ?? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: DentalColors.onPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(icon, color: DentalColors.onPrimary, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text!,
                  style: const TextStyle(
                    color: DentalColors.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 性别头像组件
class DentalAvatar extends StatelessWidget {
  final String gender;
  final String name;
  final double size;
  
  const DentalAvatar({
    Key? key,
    required this.gender,
    required this.name,
    this.size = 40,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final bool isFemale = gender == '女';
    final Color backgroundColor = isFemale 
        ? DentalColors.femalePink.withOpacity(0.2) 
        : DentalColors.maleBlue.withOpacity(0.2);
    final Color textColor = isFemale 
        ? DentalColors.femalePink 
        : DentalColors.maleBlue;
    final String initial = name.isNotEmpty ? name[0] : '?';
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// 现代化状态指示器
class DentalStatusIndicator extends StatelessWidget {
  final String status;
  final Color? color;
  final IconData? icon;
  
  const DentalStatusIndicator({
    Key? key,
    required this.status,
    this.color,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color statusColor = color ?? _getStatusColor(status);
    IconData statusIcon = icon ?? _getStatusIcon(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.1),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case '已完成':
        return DentalColors.completed;
      case '已预约':
        return DentalColors.info;
      case '已取消':
        return DentalColors.cancelled;
      case '未到诊':
        return DentalColors.warning;
      case '紧急':
        return DentalColors.urgent;
      default:
        return DentalColors.onSurfaceVariant;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case '已完成':
        return Icons.check_circle_rounded;
      case '已预约':
        return Icons.schedule_rounded;
      case '已取消':
        return Icons.cancel_rounded;
      case '未到诊':
        return Icons.warning_rounded;
      case '紧急':
        return Icons.priority_high_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}

// 头像选择器组件
class AvatarSelector extends StatelessWidget {
  final String? selectedAvatar;
  final Function(String) onAvatarSelected;
  final double size;
  
  const AvatarSelector({
    Key? key,
    this.selectedAvatar,
    required this.onAvatarSelected,
    this.size = 60,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // 空组件，内置头像已删除
  }
}

// 用户头像显示组件
class UserAvatar extends StatelessWidget {
  final User user;
  final double size;
  final bool showBorder;
  final bool showStyledBorder; // 是否显示编辑预览样式的边框
  
  const UserAvatar({
    Key? key,
    required this.user,
    this.size = 60,
    this.showBorder = true,
    this.showStyledBorder = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 如果需要显示样式化边框（编辑预览样式）
    if (showStyledBorder) {
      // 计算圆角半径，保持与编辑预览图的比例一致
      final borderRadius = size > 60 ? 12.0 : (size * 0.2);
      final clipRadius = borderRadius - 2;
      
      // 直接返回固定大小的 Container，不使用任何可能被压扁的包装器
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: DentalColors.primary, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(clipRadius),
          child: _buildStyledAvatarContent(user),
        ),
      );
    }
    
    // 普通模式（不显示样式化边框）
    // 如果用户上传了自定义头像图片，显示上传的图片
    if (user.imageData != null && user.imageData!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: AspectRatio(
          aspectRatio: 1.0, // 确保正方形比例
          child: Image.memory(
            Uint8List.fromList(user.imageData!),
            fit: BoxFit.cover, // 覆盖整个区域，保持比例，居中裁剪
            alignment: Alignment.center, // 确保图片居中
            // 添加缓存配置，避免重复加载
            cacheWidth: size.toInt() * 2, // 2倍分辨率用于高清屏
            cacheHeight: size.toInt() * 2,
            gaplessPlayback: true, // 平滑切换，避免闪烁
            errorBuilder: (context, error, stackTrace) {
              print('加载用户上传头像失败: $error');
              // 加载失败时使用默认头像
              return _buildDefaultAvatar(user);
            },
          ),
        ),
      );
    }
    
    // 使用默认头像（基于角色）
    return _buildDefaultAvatar(user);
  }
  
  // 构建样式化头像内容（用于showStyledBorder模式）
  Widget _buildStyledAvatarContent(User user) {
    // 如果用户上传了自定义头像图片，显示上传的图片
    if (user.imageData != null && user.imageData!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.memory(
          Uint8List.fromList(user.imageData!),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          cacheWidth: size.toInt() * 2,
          cacheHeight: size.toInt() * 2,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            print('加载用户上传头像失败: $error');
            return _buildStyledDefaultAvatar(user);
          },
        ),
      );
    }
    
    // 使用默认头像
    return _buildStyledDefaultAvatar(user);
  }
  
  // 构建样式化默认头像（用于showStyledBorder模式）
  Widget _buildStyledDefaultAvatar(User user) {
    String assetPath;
    if (user.role == 'doctor' || user.role == 'admin') {
      assetPath = 'assets/icons/doctor.png';
    } else {
      assetPath = 'assets/icons/nurse.png';
    }
    
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        cacheWidth: size.toInt() * 2,
        cacheHeight: size.toInt() * 2,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          print('加载默认头像失败: $error, 路径: $assetPath');
          return _buildFallbackAvatar(user);
        },
      ),
    );
  }
  
  // 构建默认头像（基于角色，使用assets中的图片）
  Widget _buildDefaultAvatar(User user) {
    // 根据角色选择默认头像图片
    // 医生或管理员使用医生图标，其他角色使用护士图标
    String assetPath;
    if (user.role == 'doctor' || user.role == 'admin') {
      assetPath = 'assets/icons/doctor.png';
    } else {
      assetPath = 'assets/icons/nurse.png';
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: AspectRatio(
        aspectRatio: 1.0, // 确保正方形比例
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover, // 覆盖整个区域，保持比例，居中裁剪
          alignment: Alignment.center, // 确保图片居中
          // 添加缓存配置，避免重复加载
          cacheWidth: size.toInt() * 2,
          cacheHeight: size.toInt() * 2,
          gaplessPlayback: true, // 平滑切换，避免闪烁
          errorBuilder: (context, error, stackTrace) {
            print('加载默认头像失败: $error, 路径: $assetPath');
            // 如果默认头像也加载失败，使用纯色背景+图标
            return _buildFallbackAvatar(user);
          },
        ),
      ),
    );
  }
  
  // 构建降级头像（纯色背景+图标）
  Widget _buildFallbackAvatar(User user) {
    final roleColors = {
      'admin': [Color(0xFFFF9800), Color(0xFFFFB74D)],
      'doctor': [Color(0xFF4CAF50), Color(0xFF66BB6A)],
      'assistant': [Color(0xFF009688), Color(0xFF26A69A)],
      'receptionist': [Color(0xFF607D8B), Color(0xFF78909C)],
    };
    
    final roleIcons = {
      'admin': Icons.admin_panel_settings,
      'doctor': Icons.medical_services,
      'assistant': Icons.assistant,
      'receptionist': Icons.person_outline,
    };
    
    final colors = roleColors[user.role] ?? [Color(0xFF9E9E9E), Color(0xFFBDBDBD)];
    final icon = roleIcons[user.role] ?? Icons.person;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: showBorder ? [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ] : null,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}
