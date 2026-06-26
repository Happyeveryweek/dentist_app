import '../../../providers/material_provider.dart';
import '../../../utils/dental_materials_init.dart';
import '../../../utils/log_manager.dart';

/// 材料初始化服务
///
/// 负责材料数据的初始化逻辑，包括：
/// - 清空现有材料数据
/// - 批量添加默认材料
/// - 验证初始化结果
/// - 标记需要刷新材料列表
class MaterialInitializationService {
  final MaterialProvider materialProvider;

  MaterialInitializationService({required this.materialProvider});

  /// 初始化默认材料数据
  Future<InitializationResult> initializeDefaultMaterials() async {
    try {
      // 获取默认材料列表
      final defaultMaterials = DentalMaterialsInit.getDefaultMaterials();

      // 检查是否已经有材料数据
      final existingMaterials = await materialProvider.getAllMaterials(
        forceRefresh: true,
      );

      if (existingMaterials.isNotEmpty) {
        // 安全清空现有材料（不影响患者材料）
        final clearSuccess = await materialProvider.clearAllDentalMaterials();
        if (!clearSuccess) {
          LogManager.e('MaterialInitializationService', '清空现有材料失败，但继续执行初始化...');
          // 继续执行，不中断流程
        } else {}
      }

      int successCount = 0;
      int failCount = 0;

      // 批量添加材料，使用事务处理
      for (int i = 0; i < defaultMaterials.length; i++) {
        final material = defaultMaterials[i];
        try {
          await materialProvider.addMaterial(material);
          successCount++;

          // 每添加50个材料打印一次进度
          if ((i + 1) % 50 == 0) {}
        } catch (e, stackTrace) {
          LogManager.e('MaterialInitializationService',
              '添加材料 ${material.materialName} 失败',
              error: e);
          LogManager.e('MaterialInitializationService', '错误堆栈',
              error: stackTrace);
          failCount++;
          // 继续添加下一个材料，不中断整个流程
        }
      }

      LogManager.e('MaterialInitializationService',
          '默认材料初始化完成: 成功 $successCount 个，失败 $failCount 个');

      // 验证最终添加结果
      final finalMaterials = await materialProvider.getAllMaterials(
        forceRefresh: true,
      );

      // 检查MySQL模式下ID是否从1开始
      bool isIdContinuous = false;
      if (finalMaterials.isNotEmpty) {
        // 验证ID连续性
        final ids = finalMaterials.map((m) => m.id).toList()..sort();
        isIdContinuous = true;
        for (int i = 0; i < ids.length; i++) {
          if (ids[i] != i + 1) {
            isIdContinuous = false;
            break;
          }
        }
      }

      // 标记需要刷新材料列表
      materialProvider.markMaterialsNeedRefresh();

      return InitializationResult(
        success: true,
        successCount: successCount,
        failCount: failCount,
        totalCount: defaultMaterials.length,
        finalCount: finalMaterials.length,
        isIdContinuous: isIdContinuous,
      );
    } catch (e, stackTrace) {
      LogManager.e('MaterialInitializationService', '初始化默认材料过程中出现异常', error: e);
      LogManager.e('MaterialInitializationService', '错误堆栈', error: stackTrace);
      return InitializationResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}

/// 初始化结果
class InitializationResult {
  final bool success;
  final int successCount;
  final int failCount;
  final int totalCount;
  final int finalCount;
  final bool isIdContinuous;
  final String? error;

  InitializationResult({
    required this.success,
    this.successCount = 0,
    this.failCount = 0,
    this.totalCount = 0,
    this.finalCount = 0,
    this.isIdContinuous = false,
    this.error,
  });
}
