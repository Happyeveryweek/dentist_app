import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';
import 'app_module.dart';

class UserRole {
  const UserRole({
    required this.value,
    required this.displayName,
    required this.icon,
    required this.modulePermissions,
    required this.operationPermissions,
    required this.color,
  });

  final String value;
  final String displayName;
  final IconData icon;
  final Map<String, bool> modulePermissions;
  final Set<String> operationPermissions;
  final Color Function(AppThemeTokens tokens) color;

  static final List<String> moduleIds =
      AppModule.values.map((module) => module.id).toList();

  static final Map<String, bool> defaultModulePermissions = {
    for (final module in moduleIds) module: module == 'dashboard',
  };

  static final admin = UserRole(
    value: 'admin',
    displayName: '管理员',
    icon: Icons.admin_panel_settings,
    modulePermissions: {for (final module in moduleIds) module: true},
    operationPermissions: const {
      'manage_patients',
      'manage_appointments',
      'manage_financials',
      'manage_materials',
      'manage_users',
    },
    color: (tokens) => tokens.error,
  );

  static final doctor = UserRole(
    value: 'doctor',
    displayName: '医生',
    icon: Icons.medical_services,
    modulePermissions: defaultModulePermissions,
    operationPermissions: const {'manage_patients', 'manage_appointments'},
    color: (tokens) => tokens.success,
  );

  static final assistant = UserRole(
    value: 'assistant',
    displayName: '助理',
    icon: Icons.assistant,
    modulePermissions: defaultModulePermissions,
    operationPermissions: const {},
    color: (tokens) => tokens.warning,
  );

  static final receptionist = UserRole(
    value: 'receptionist',
    displayName: '前台',
    icon: Icons.person_outline,
    modulePermissions: defaultModulePermissions,
    operationPermissions: const {'manage_appointments'},
    color: (tokens) => tokens.info,
  );

  static final List<UserRole> values = [admin, doctor, assistant, receptionist];

  static UserRole? fromValue(String value) {
    for (final role in values) {
      if (role.value == value) return role;
    }
    return null;
  }
}
