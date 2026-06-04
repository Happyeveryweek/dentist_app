import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class PermissionPanel extends StatelessWidget {
  final Map<String, bool> permissions;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Function(String, bool) onPermissionChanged;

  const PermissionPanel({
    Key? key,
    required this.permissions,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onPermissionChanged,
  }) : super(key: key);

  String _getModuleName(String moduleKey) {
    final moduleNames = {
      'patients': '患者管理',
      'appointments': '预约管理',
      'financial': '财务管理',
      'materials': '材料管理',
      'purchase': '采购管理',
      'medical_records': '病历管理',
    };
    return moduleNames[moduleKey] ?? moduleKey;
  }

  @override
  Widget build(BuildContext context) {
    // 计算已选择的权限
    final selectedPermissions = permissions.entries
        .where((entry) => entry.value == true && entry.key != 'dashboard')
        .map((entry) => _getModuleName(entry.key))
        .toList();
    
    final permissionSummary = selectedPermissions.isEmpty 
        ? '未选择任何模块' 
        : selectedPermissions.join('、');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // 头部 - 可点击展开/折叠
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.security, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    '模块权限配置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      permissionSummary,
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedPermissions.isEmpty 
                            ? Colors.grey.shade500 
                            : AppTheme.primaryColor,
                        fontWeight: selectedPermissions.isEmpty 
                            ? FontWeight.normal 
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          // 展开的内容
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: _buildPermissionConfigPanel(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionConfigPanel() {
    final moduleInfo = {
      'patients': {'name': '患者管理', 'icon': Icons.people, 'color': AppTheme.successColor},
      'appointments': {'name': '预约管理', 'icon': Icons.calendar_today, 'color': AppTheme.infoColor},
      'financial': {'name': '财务管理', 'icon': Icons.account_balance_wallet, 'color': AppTheme.warningColor},
      'materials': {'name': '材料管理', 'icon': Icons.inventory, 'color': AppTheme.primaryColor},
      'purchase': {'name': '采购管理', 'icon': Icons.shopping_cart, 'color': AppTheme.errorColor},
      'medical_records': {'name': '病历管理', 'icon': Icons.medical_services, 'color': Colors.teal},
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择用户可以访问的功能模块（仪表盘默认对所有用户可见）',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        
        // 权限复选框列表
        ...moduleInfo.entries.map((entry) {
          final module = entry.key;
          final info = entry.value;
          final hasPermission = permissions[module] ?? false;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: hasPermission 
                  ? (info['color'] as Color).withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasPermission 
                    ? (info['color'] as Color).withOpacity(0.3)
                    : Colors.grey.shade200,
              ),
            ),
            child: InkWell(
              onTap: () => onPermissionChanged(module, !hasPermission),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: hasPermission,
                      onChanged: (value) => onPermissionChanged(module, value ?? false),
                      activeColor: info['color'] as Color,
                      checkColor: Colors.white,
                    ),
                    Icon(
                      info['icon'] as IconData,
                      color: hasPermission
                          ? (info['color'] as Color)
                          : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info['name'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              hasPermission ? FontWeight.w600 : FontWeight.normal,
                          color: hasPermission
                              ? (info['color'] as Color)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
