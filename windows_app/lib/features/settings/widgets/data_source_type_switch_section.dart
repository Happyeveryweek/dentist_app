import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 数据源类型切换区域组件
/// 包含全局/模块化模式选择和数据源配置
class DataSourceTypeSwitchSection extends StatelessWidget {
  final String dataSourceMode;
  final String selectedDataSource;
  final Map<String, String> moduleDataSources;
  final bool isDataSourceTypeEditing;
  final VoidCallback onSetDataSourceTypeEditing;
  final VoidCallback onCancelDataSourceTypeChanges;
  final VoidCallback onSaveDataSourceTypeSettings;
  final Function(String) onSetDataSourceMode;
  final Function(String) onSetSelectedDataSource;
  final Function(String, String) onSetModuleDataSource;
  final VoidCallback onReloadModuleDataSources;
  final String Function(String) getModuleDisplayName;

  const DataSourceTypeSwitchSection({
    Key? key,
    required this.dataSourceMode,
    required this.selectedDataSource,
    required this.moduleDataSources,
    required this.isDataSourceTypeEditing,
    required this.onSetDataSourceTypeEditing,
    required this.onCancelDataSourceTypeChanges,
    required this.onSaveDataSourceTypeSettings,
    required this.onSetDataSourceMode,
    required this.onSetSelectedDataSource,
    required this.onSetModuleDataSource,
    required this.onReloadModuleDataSources,
    required this.getModuleDisplayName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            '数据源类型切换', Icons.swap_horiz_rounded, AppTheme.secondaryColor),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDataSourceTypeSwitchHeader(),
                const SizedBox(height: 20),
                _buildDataSourceModeSelection(),
                const SizedBox(height: 20),
                if (dataSourceMode == 'global') ...[
                  _buildGlobalDataSourceSwitch(context),
                ] else ...[
                  _buildModularDataSourceSwitch(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceTypeSwitchHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.swap_horiz_rounded,
            color: AppTheme.secondaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          '数据源切换配置',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        if (!isDataSourceTypeEditing) ...[
          ElevatedButton.icon(
            onPressed: onSetDataSourceTypeEditing,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('编辑'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ] else ...[
          TextButton.icon(
            onPressed: onCancelDataSourceTypeChanges,
            icon: const Icon(Icons.close_rounded),
            label: const Text('取消'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onSaveDataSourceTypeSettings,
            icon: const Icon(Icons.save_rounded),
            label: const Text('保存'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDataSourceModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppTheme.secondaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '选择数据源切换模式',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildCompactModeOption(
                'global',
                '全局数据源切换',
                '所有模块使用相同的数据源类型',
                Icons.public_rounded,
                Colors.blue,
                dataSourceMode == 'global',
                isDataSourceTypeEditing
                    ? () {
                        onSetDataSourceMode('global');
                        // 当切换到全局模式时，所有模块使用相同的数据源
                        for (String key in moduleDataSources.keys) {
                          moduleDataSources[key] = selectedDataSource;
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactModeOption(
                'modular',
                '模块化数据源切换',
                '为不同模块设置不同的数据源',
                Icons.grid_view_rounded,
                Colors.green,
                dataSourceMode == 'modular',
                isDataSourceTypeEditing
                    ? () {
                        onSetDataSourceMode('modular');
                        // 切换到模块化模式时，重新加载保存的模块配置
                        onReloadModuleDataSources();
                      }
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactModeOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? color.withValues(alpha: 0.8)
                    : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (isSelected)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '已选择',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalDataSourceSwitch(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.public_rounded,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '全局数据源选择',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RadioGroup<String>(
          groupValue: selectedDataSource,
          onChanged: isDataSourceTypeEditing
              ? (value) {
                  if (value == null) return;
                  onSetSelectedDataSource(value);
                  if (dataSourceMode == 'global') {
                    for (String key in moduleDataSources.keys) {
                      moduleDataSources[key] = value;
                    }
                  }
                }
              : (_) {},
          child: Row(
            children: [
              Expanded(
                child: _buildCompactDataSourceOption(
                  context,
                  'sqlite',
                  'SQLite (本地数据库)',
                  '数据存储在本地设备上，无需网络连接，适合单机使用',
                  '快速、轻量、无需配置服务器',
                  Icons.storage_rounded,
                  Colors.blue,
                  selectedDataSource == 'sqlite',
                  isDataSourceTypeEditing,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactDataSourceOption(
                  context,
                  'mysql',
                  'MySQL (远程数据库)',
                  '数据存储在远程服务器上，可多设备共享数据',
                  '支持多用户、数据同步、备份恢复',
                  Icons.cloud_done_rounded,
                  Colors.green,
                  selectedDataSource == 'mysql',
                  isDataSourceTypeEditing,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '全局切换将影响所有模块的数据源类型。当前已选择 $dataSourceMode 模式。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDataSourceOption(
    BuildContext context,
    String value,
    String title,
    String subtitle,
    String description,
    IconData icon,
    Color color,
    bool isSelected,
    bool enabled,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSelected ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          unselectedWidgetColor: AppTheme.secondaryText,
        ),
        child: RadioListTile<String>(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          value: value,
          enabled: enabled,
          activeColor: color,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildModularDataSourceSwitch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '模块数据源配置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModuleDataSourceCard(
                'patients',
                '患者管理',
                Icons.people_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'appointments',
                '预约管理',
                Icons.calendar_today_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'financial',
                '财务管理',
                Icons.account_balance_wallet_rounded,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'materials',
                '材料管理',
                Icons.inventory_2_rounded,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'purchase',
                '采购管理',
                Icons.shopping_cart_rounded,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'users',
                '用户管理',
                Icons.manage_accounts_rounded,
                Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text: '说明：',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '病历管理模块的数据源'),
                      TextSpan(
                        text: '自动跟随患者管理',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const TextSpan(
                          text:
                              '模块的配置，无需单独设置。这样可以确保患者数据和病历数据使用相同的数据源，保持数据一致性。'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '提示：模块化配置允许您为不同的功能模块选择最适合的数据源。例如：患者数据使用SQLite本地存储，财务数据使用MySQL远程存储。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModuleDataSourceCard(
      String moduleKey, String moduleName, IconData icon, Color color) {
    final currentDataSource = dataSourceMode == 'global'
        ? selectedDataSource
        : (moduleDataSources[moduleKey] ?? 'sqlite');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  moduleName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: currentDataSource == 'sqlite'
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentDataSource == 'sqlite'
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  currentDataSource == 'sqlite'
                      ? Icons.storage_rounded
                      : Icons.cloud_done_rounded,
                  size: 10,
                  color: currentDataSource == 'sqlite'
                      ? Colors.blue
                      : Colors.green,
                ),
                const SizedBox(width: 3),
                Text(
                  currentDataSource == 'sqlite' ? 'SQLite' : 'MySQL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: currentDataSource == 'sqlite'
                        ? Colors.blue
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildModuleDataSourceToggleButton(
                  moduleKey,
                  'sqlite',
                  'SQLite',
                  Icons.storage_rounded,
                  Colors.blue,
                  currentDataSource == 'sqlite',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildModuleDataSourceToggleButton(
                  moduleKey,
                  'mysql',
                  'MySQL',
                  Icons.cloud_done_rounded,
                  Colors.green,
                  currentDataSource == 'mysql',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleDataSourceToggleButton(
    String moduleKey,
    String dataSource,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    final isEnabled = isDataSourceTypeEditing && dataSourceMode == 'modular';
    final shouldShowAsSelected = dataSourceMode == 'global'
        ? (selectedDataSource == dataSource)
        : isSelected;

    return GestureDetector(
      onTap: isEnabled
          ? () {
              onSetModuleDataSource(moduleKey, dataSource);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: shouldShowAsSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: shouldShowAsSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: shouldShowAsSelected
                  ? Colors.white
                  : (isEnabled ? color : Colors.grey.shade400),
              size: 12,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: shouldShowAsSelected
                    ? Colors.white
                    : (isEnabled ? color : Colors.grey.shade400),
                fontSize: 8,
                fontWeight:
                    shouldShowAsSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
