import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/material.dart' as material_models;
import '../../../theme/app_theme.dart';
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
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
                    _buildBasicInfo(),

                    const SizedBox(height: 20),

                    // 详细信息
                    if (material.supplier != null ||
                        material.description != null) ...[
                      _buildDetailInfo(),
                      const SizedBox(height: 20),
                    ],

                    // 创建时间
                    _buildCreateTime(),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medication,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '材料详情',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.medication,
              color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                if (material.materialCode != null) ...[
                  MaterialDetailRow(
                    icon: Icons.qr_code_rounded,
                    label: '编码',
                    value: material.materialCode ?? '',
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 4),
                ],
                MaterialDetailRow(
                  icon: Icons.straighten_rounded,
                  label: '单位',
                  value: material.unit,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 4),
                MaterialDetailRow(
                  icon: Icons.category_rounded,
                  label: '材料类型',
                  value: material.materialType,
                  color: Colors.purple.shade700,
                ),
                const SizedBox(height: 4),
                MaterialDetailRow(
                  icon: Icons.attach_money_rounded,
                  label: '默认价格',
                  value: '¥${material.defaultPrice.toStringAsFixed(0)}',
                  color: Colors.green.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (material.supplier != null) ...[
            MaterialDetailRow(
              icon: Icons.business_rounded,
              label: '供应商',
              value: material.supplier ?? '',
              color: Colors.orange.shade700,
            ),
            if (material.description != null) const SizedBox(height: 16),
          ],
          if (material.description != null) ...[
            MaterialDetailRow(
              icon: Icons.description_rounded,
              label: '描述',
              value: fixMaybeDecoded(material.description),
              color: Colors.grey.shade700,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateTime() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: MaterialDetailRow(
        icon: Icons.calendar_today_rounded,
        label: '创建时间',
        value: DateFormat('yyyy-MM-dd HH:mm').format(material.createdAt),
        color: Colors.green.shade700,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
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
                side: BorderSide(color: Colors.grey.shade400),
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
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
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
