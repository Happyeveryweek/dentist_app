import '../../../providers/purchase_provider.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/material_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/log_manager.dart';

/// 数据源Provider同步服务
/// 负责更新所有Provider的模块数据源配置
class DataSourceProviderSyncService {
  final BuildContext context;

  DataSourceProviderSyncService({required this.context});

  /// 更新所有Provider的模块数据源配置
  ///
  /// [moduleDataSources] 模块数据源配置映射
  void updateAllProvidersModuleDataSources(
      Map<String, String> moduleDataSources) {
    try {
      // 更新PurchaseProvider的模块数据源配置
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);
      purchaseProvider.updateModuleDataSources(moduleDataSources);
      LogManager.w(
          'DataSourceProviderSyncService', '已更新PurchaseProvider的模块数据源配置');

      // 更新FinancialProvider的模块数据源配置
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);
      financialProvider.updateModuleDataSources(moduleDataSources);
      LogManager.w(
          'DataSourceProviderSyncService', '已更新FinancialProvider的模块数据源配置');

      // 更新MaterialProvider的模块数据源配置
      final materialProvider =
          Provider.of<MaterialProvider>(context, listen: false);
      materialProvider.updateModuleDataSources(moduleDataSources);
      LogManager.w(
          'DataSourceProviderSyncService', '已更新MaterialProvider的模块数据源配置');

      // 可以在这里添加其他Provider的更新
      // 例如：PatientProvider, AppointmentProvider等
    } catch (e) {
      LogManager.e('DataSourceProviderSyncService', '更新Provider模块数据源配置失败',
          error: e);
      rethrow;
    }
  }
}
