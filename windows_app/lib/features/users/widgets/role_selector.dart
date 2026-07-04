import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class RoleSelector extends StatelessWidget {
  final String selectedRole;
  final List<String> availableRoles;
  final Function(String?) onRoleChanged;

  const RoleSelector({
    Key? key,
    required this.selectedRole,
    required this.availableRoles,
    required this.onRoleChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final roleInfo = {
      'admin': {
        'name': '管理员',
        'icon': Icons.admin_panel_settings,
        'color': context.tokens.error
      },
      'doctor': {
        'name': '医生',
        'icon': Icons.medical_services,
        'color': context.tokens.success
      },
      'assistant': {
        'name': '助理',
        'icon': Icons.assistant,
        'color': context.tokens.warning
      },
      'receptionist': {
        'name': '前台',
        'icon': Icons.person_outline,
        'color': context.tokens.info
      },
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.tokens.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.tokens.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedRole,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down,
                color: context.tokens.primaryAccent),
            style: TextStyle(fontSize: 16, color: context.colors.onSurface),
            dropdownColor: context.tokens.cardBackground,
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            onChanged: onRoleChanged,
            selectedItemBuilder: (context) {
              return availableRoles.map<Widget>((role) {
                final info = roleInfo[role] ?? {
                  'name': role,
                  'icon': Icons.person,
                  'color': context.tokens.textMuted,
                };
                return Row(
                  children: [
                    Icon(Icons.work,
                        color: context.tokens.primaryAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '角色',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tokens.iconMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            info['name'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              color: context.colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items: availableRoles.map((role) {
              final info = roleInfo[role] ?? {
                'name': role,
                'icon': Icons.person,
                'color': context.tokens.textMuted,
              };
              return DropdownMenuItem<String>(
                value: role,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: selectedRole == role
                        ? (info['color'] as Color).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (info['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          info['icon'] as IconData,
                          color: info['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        info['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selectedRole == role
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selectedRole == role
                              ? (info['color'] as Color)
                              : context.colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
