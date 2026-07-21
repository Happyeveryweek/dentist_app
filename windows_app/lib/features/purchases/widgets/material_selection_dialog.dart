import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'dart:ui' as ui;

import '../../../models/material.dart' as material_models;
import '../../../providers/material_provider.dart';
import '../../../providers/purchase_provider.dart';
import '../../../widgets/dental_icons.dart';
import '../../../utils/log_manager.dart';

/// 材料选择对话框
class MaterialSelectionDialog {
  /// 显示材料选择对话框
  static Future<material_models.MaterialInfo?> show(
      BuildContext context) async {
    final materialProvider =
        Provider.of<MaterialProvider>(context, listen: false);
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    List<material_models.MaterialInfo> materials = [];
    final materialSearchController = TextEditingController();

    try {
      materials = await materialProvider.getAllMaterialsInDataSource(
        purchaseProvider.dataSourceType,
      );
    } catch (e) {
      LogManager.e('MaterialSelectionDialog', '加载材料数据失败', error: e);
    }

    if (!context.mounted) return null;
    final result = await showDialog<material_models.MaterialInfo>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tokens = context.tokens;
          final colors = context.colors;
          void listener() {
            setDialogState(() {});
          }

          materialSearchController.addListener(listener);

          final filteredMaterials = materials.where((material) {
            final query = materialSearchController.text.toLowerCase();
            if (query.isEmpty) return true;
            return material.materialName.toLowerCase().contains(query) ||
                (material.materialCode?.toLowerCase().contains(query) ?? false);
          }).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                width: 500,
                height: 600,
                decoration: BoxDecoration(
                  color: tokens.cardBackground.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.shadow.withValues(alpha: 0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 标题栏
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tokens.primaryAccent,
                            tokens.primaryAccent.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '选择材料',
                            style: TextStyle(
                              color: tokens.cardBackground,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon:
                                Icon(Icons.close, color: tokens.cardBackground),
                          ),
                        ],
                      ),
                    ),

                    // 搜索框
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: materialSearchController,
                        decoration: InputDecoration(
                          hintText: '搜索材料 (名称/编码)',
                          prefixIcon:
                              Icon(Icons.search, color: tokens.iconMuted),
                          suffixIcon: materialSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: tokens.iconMuted),
                                  onPressed: () {
                                    materialSearchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: tokens.cardBackground,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),

                    // 材料列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = filteredMaterials[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 2,
                            shadowColor: tokens.shadow.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              mouseCursor: SystemMouseCursors.click,
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(context).pop(material);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: tokens.primaryAccent,
                                      foregroundColor: tokens.cardBackground,
                                      child: const Icon(DentalIcons.pills,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            material.materialName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                              '编码: ${material.materialCode ?? 'N/A'}'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '¥${material.defaultPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: tokens.success,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 底部操作栏
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: tokens.divider),
                              ),
                            ),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    materialSearchController.dispose();
    return result;
  }
}
