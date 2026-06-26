import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/material_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/user_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/medical_record_provider.dart';
import '../providers/settings_provider.dart';

/// MySQL 连接失败警告提示框
/// 用于在 MySQL 依赖的模块中显示统一的连接失败提示
/// 只在 MySQL 连接失败并降级到 SQLite 时显示，主动选择 SQLite 时不显示
///
/// 支持模块化数据源配置：
/// - 只有当前模块配置为MySQL且连接失败时才显示警告
/// - 其他模块的MySQL连接失败不会影响当前模块
class MySQLConnectionWarning extends StatelessWidget {
  /// 模块名称（中文）
  final String moduleName;

  /// 模块标识（英文，用于匹配Provider）
  final String? moduleKey;

  const MySQLConnectionWarning({
    Key? key,
    required this.moduleName,
    this.moduleKey,
  }) : super(key: key);

  /// 模块名称映射（中文 -> 英文）
  static const Map<String, String> _moduleKeyMap = {
    '财务管理': 'financial',
    '材料管理': 'materials',
    '采购管理': 'purchase',
    '用户管理': 'users',
    '预约管理': 'appointments',
    '患者管理': 'patients',
    '病历管理': 'medical',
  };

  @override
  Widget build(BuildContext context) {
    // 获取模块标识
    final key = moduleKey ?? _moduleKeyMap[moduleName];

    // 如果找不到模块标识，不显示警告
    if (key == null) {
      return const SizedBox.shrink();
    }

    // 获取SettingsProvider来检查数据源配置
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    // 判断是否应该显示警告
    bool shouldShowWarning = false;
    String? configuredDataSource;
    String? actualDataSource;

    try {
      // 根据模块类型检查对应的Provider
      switch (key) {
        case 'materials':
          final provider =
              Provider.of<MaterialProvider>(context, listen: false);
          configuredDataSource =
              _getModuleConfiguredDataSource(settingsProvider, 'materials');
          actualDataSource = provider.dataSourceType;
          break;
        case 'purchase':
          final provider =
              Provider.of<PurchaseProvider>(context, listen: false);
          configuredDataSource =
              _getModuleConfiguredDataSource(settingsProvider, 'purchase');
          actualDataSource = provider.dataSourceType;
          break;
        case 'financial':
          final provider =
              Provider.of<FinancialProvider>(context, listen: false);
          configuredDataSource =
              _getModuleConfiguredDataSource(settingsProvider, 'financial');
          actualDataSource = provider.dataSourceType;
          break;
        case 'users':
          final provider = Provider.of<UserProvider>(context, listen: false);
          configuredDataSource =
              _getModuleConfiguredDataSource(settingsProvider, 'users');
          actualDataSource = provider.dataSourceType;
          break;
        case 'appointments':
          final provider =
              Provider.of<AppointmentProvider>(context, listen: false);
          configuredDataSource =
              _getModuleConfiguredDataSource(settingsProvider, 'appointments');
          actualDataSource = provider.dataSourceType;
          break;
        case 'patients':
          final provider = Provider.of<PatientProvider>(context, listen: false);
          configuredDataSource =
              _getModuleConfiguredDataSource(settingsProvider, 'patients');
          actualDataSource = provider.dataSourceType;
          break;
        case 'medical':
          final provider =
              Provider.of<MedicalRecordProvider>(context, listen: false);
          configuredDataSource = _getModuleConfiguredDataSource(
              settingsProvider, 'patients'); // 病历管理跟随患者管理
          actualDataSource = provider.dataSourceType;
          break;
      }

      // 只有在配置为MySQL但实际使用SQLite时才显示警告
      // 这表示MySQL连接失败并降级了
      shouldShowWarning =
          configuredDataSource == 'mysql' && actualDataSource == 'sqlite';
    } catch (e) {
      return const SizedBox.shrink();
    }

    if (!shouldShowWarning) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MySQL连接失败已降级为SQLite数据源显示',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '如需永久使用SQLite，请在系统设置中更改为SQLite数据源并重启应用。',
            style: TextStyle(
              color: Colors.orange.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取模块配置的数据源类型
  String _getModuleConfiguredDataSource(
      SettingsProvider settingsProvider, String moduleKey) {
    // 如果是模块化模式，检查模块配置
    if (settingsProvider.dataSourceMode == 'modular') {
      final moduleDataSources = settingsProvider.moduleDataSources;
      final configured = moduleDataSources[moduleKey];
      if (configured != null) {
        return configured;
      }
    }

    // 否则返回全局配置
    return settingsProvider.dataSourceType;
  }
}
