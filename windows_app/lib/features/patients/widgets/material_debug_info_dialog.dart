import 'package:flutter/material.dart';
import '../../../models/patient_material_with_images.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 材料调试信息弹窗组件
///
/// 用于显示材料数据的调试信息，帮助排查问题
class MaterialDebugInfoDialog extends StatelessWidget {
  final int? patientId;
  final List<PatientMaterialWithImages> materials;
  final int controllerCount;
  final int existingImagesCount;
  final int selectedImagesCount;

  const MaterialDebugInfoDialog({
    Key? key,
    required this.patientId,
    required this.materials,
    required this.controllerCount,
    required this.existingImagesCount,
    required this.selectedImagesCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          color: tokens.cardBackground,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: tokens.shadow.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.primaryAccent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bug_report,
                    color: colors.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '材料数据调试信息',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.close, color: colors.onPrimary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 患者信息
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: tokens.infoContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.info),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '患者信息',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.primaryAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDebugRow(context, '患者ID', '${patientId ?? "未知"}'),
                          _buildDebugRow(context, '材料数量', '${materials.length}'),
                        ],
                      ),
                    ),

                    // 材料详细信息
                    if (materials.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: tokens.mutedBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '材料详细信息',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < materials.length; i++) ...[
                              _buildDebugRow(context, '材料 $i',
                                  'ID=${materials[i].material.id ?? "新"}'),
                              _buildDebugRow(context, 
                                  '  描述', materials[i].material.description),
                              _buildDebugRow(context, 
                                  '  图片数量', '${materials[i].images.length}'),
                              if (materials[i].images.isNotEmpty) ...[
                                for (int j = 0;
                                    j < materials[i].images.length;
                                    j++) ...[
                                  _buildDebugRow(context, '    图片 $j',
                                      'ID=${materials[i].images[j].id}'),
                                  _buildDebugRow(context, '      类型',
                                      materials[i].images[j].imageType),
                                  _buildDebugRow(context, '      大小',
                                      '${(materials[i].images[j].fileSize / 1024).toStringAsFixed(1)} KB'),
                                  _buildDebugRow(context, 
                                      '      原始名称',
                                      materials[i].images[j].originalName ??
                                          "未知"),
                                  const SizedBox(height: 4),
                                ],
                              ],
                              if (i < materials.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: tokens.inputBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.divider),
                        ),
                        child: Center(
                          child: Text(
                            '暂无材料信息',
                            style: TextStyle(fontSize: 14, color: tokens.textMuted),
                          ),
                        ),
                      ),
                    ],

                    // 系统信息
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.warningContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.warning),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '系统信息',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.warning,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDebugRow(context, '控制器数量', '$controllerCount'),
                          _buildDebugRow(context, '现有图片数组长度', '$existingImagesCount'),
                          _buildDebugRow(context, '新选择图片数组长度', '$selectedImagesCount'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(BuildContext context, String label, String value) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
