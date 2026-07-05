import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/material.dart' as material_models;
import '../../../theme/theme_context_extensions.dart';
import 'material_detail_row.dart';

/// 材料详情对话框
///
/// 显示材料的详细信息，包括基本信息、供应商、描述、创建时间等
class MaterialDetailDialog extends StatelessWidget {
  final material_models.MaterialInfo material;
  final VoidCallback onEdit;
  final String Function(String?) fixMaybeDecoded;

  const MaterialDetailDialog({
    Key? key,
    required this.material,
    required this.onEdit,
    required this.fixMaybeDecoded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: tokens.cardBackground,
          boxShadow: tokens.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(context),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 材料基本信息
                    _buildBasicInfo(context),

                    const SizedBox(height: 20),

                    // 详细信息
                    if (material.supplier != null ||
                        material.description != null) ...[
                      _buildDetailInfo(context),
                      const SizedBox(height: 20),
                    ],

                    // 创建时间
                    _buildCreateTime(context),
                  ],
                ),
              ),
            ),

            // 按钮栏
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: tokens.primaryHeaderGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medication,
              color: colors.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '材料详情',
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: colors.onPrimary),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.infoContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.info),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: tokens.primaryAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.medication,
              color: colors.onPrimary,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.materialName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tokens.info,
                  ),
                ),
                const SizedBox(height: 8),
                if (material.materialCode != null) ...[
                  MaterialDetailRow(
                    icon: Icons.qr_code_rounded,
                    label: '编码',
                    value: material.materialCode ?? '',
                    color: tokens.info,
                  ),
                  const SizedBox(height: 4),
                ],
                MaterialDetailRow(
                  icon: Icons.straighten_rounded,
                  label: '单位',
                  value: material.unit,
                  color: tokens.info,
                ),
                const SizedBox(height: 4),
                MaterialDetailRow(
                  icon: Icons.category_rounded,
                  label: '材料类型',
                  value: material.materialType,
                  color: context.tokens.secondaryAccent,
                ),
                const SizedBox(height: 4),
                MaterialDetailRow(
                  icon: Icons.attach_money_rounded,
                  label: '默认价格',
                  value: '¥${material.defaultPrice.toStringAsFixed(0)}',
                  color: tokens.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailInfo(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (material.supplier != null) ...[
            MaterialDetailRow(
              icon: Icons.business_rounded,
              label: '供应商',
              value: material.supplier ?? '',
              color: tokens.warning,
            ),
            if (material.description != null) const SizedBox(height: 16),
          ],
          if (material.description != null) ...[
            MaterialDetailRow(
              icon: Icons.description_rounded,
              label: '描述',
              value: fixMaybeDecoded(material.description),
              color: tokens.textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateTime(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.successContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.success),
      ),
      child: MaterialDetailRow(
        icon: Icons.calendar_today_rounded,
        label: '创建时间',
        value: DateFormat('yyyy-MM-dd HH:mm').format(material.createdAt),
        color: tokens.success,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: tokens.border),
              ),
            ),
            child: const Text(
              '关闭',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('编辑'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.warning,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
}
