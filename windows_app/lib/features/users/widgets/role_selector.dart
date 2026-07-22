import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/widgets/compact_dropdown_form_field.dart';
import '../../../models/user_role.dart';

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
          child: CompactDropdownFormField<String>(
            value: selectedRole,
            itemHeight: 44,
            menuMaxHeight: 220,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onRoleChanged,
            selectedItemBuilder: (context, role) {
              final info = UserRole.fromValue(role);
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
                          info?.displayName ?? role,
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
            },
            items: availableRoles.map((role) {
              final info = UserRole.fromValue(role);
              final color =
                  info?.color(context.tokens) ?? context.tokens.textMuted;
              return CompactDropdownItem<String>(
                value: role,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: selectedRole == role
                        ? color.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          info?.icon ?? Icons.person,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        info?.displayName ?? role,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selectedRole == role
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selectedRole == role
                              ? color
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
