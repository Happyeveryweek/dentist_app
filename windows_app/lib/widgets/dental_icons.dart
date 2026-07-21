import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../models/appointment_status.dart';
import 'package:dentist_app_windows/theme/medical_semantic_colors.dart';
// import 'package:line_icons/line_icons.dart'; // 暂时注释掉，使用FontAwesome替代

class DentalIcons {
  // 基础图标 - 使用Material Icons作为后备
  static const IconData tooth = IconData(
    0xf5c9,
    fontFamily: 'FontAwesomeSolid',
    fontPackage: 'font_awesome_flutter',
  );
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
        gradient: color == null
            ? LinearGradient(colors: [
                context.tokens.cardBackground,
                context.tokens.mutedBackground
              ])
            : null,
        boxShadow: [
          BoxShadow(
            color: context.tokens.shadow,
            blurRadius: 10.0,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: context.tokens.cardBackground.withValues(alpha: 0.8),
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
          mouseCursor: SystemMouseCursors.click,
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
  })  : assert(text != null || child != null,
            'Either text or child must be provided'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: context.tokens.primaryAccent,
            width: 2.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: child ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading) ...[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: context.tokens.primaryAccent,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (icon != null) ...[
                        Icon(icon,
                            color: context.tokens.primaryAccent, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text ?? '',
                        style: TextStyle(
                          color: context.tokens.primaryAccent,
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
        gradient: gradient ?? context.tokens.primaryHeaderGradient,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: context.tokens.primaryAccent.withValues(alpha: 0.3),
            blurRadius: 8.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: child ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading) ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (icon != null) ...[
                      Icon(icon,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text ?? '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
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
    final Color baseColor = isFemale
        ? MedicalSemanticColors.femaleGender
        : MedicalSemanticColors.maleGender;
    final Color backgroundColor = baseColor.withValues(alpha: 0.14);
    final Color textColor = baseColor;
    final String initial = name.isNotEmpty ? name[0] : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: textColor.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: textColor.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
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
    Color statusColor = color ?? _getStatusColor(context, status);
    IconData statusIcon = icon ?? _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.1),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
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

  Color _getStatusColor(BuildContext context, String status) {
    switch (AppointmentStatus.tryParse(status)) {
      case AppointmentStatus.completed:
        return context.tokens.success;
      case AppointmentStatus.scheduled:
        return context.tokens.info;
      case AppointmentStatus.cancelled:
        return context.tokens.error;
      case AppointmentStatus.missed:
        return context.tokens.warning;
      default:
        return status == '紧急' ? context.tokens.error : context.tokens.textMuted;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (AppointmentStatus.tryParse(status)) {
      case AppointmentStatus.completed:
        return Icons.check_circle_rounded;
      case AppointmentStatus.scheduled:
        return Icons.schedule_rounded;
      case AppointmentStatus.cancelled:
        return Icons.cancel_rounded;
      case AppointmentStatus.missed:
        return Icons.warning_rounded;
      default:
        return status == '紧急'
            ? Icons.priority_high_rounded
            : Icons.info_rounded;
    }
  }
}
