import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/confirm_dialogs.dart';
import '../services/material_catalog.dart';
import 'material_sheet_header.dart';

enum MaterialDetailOutcome { updated, deleted }

class MaterialDetailPage extends StatelessWidget {
  const MaterialDetailPage({
    super.key,
    required this.material,
    required this.onEdit,
    required this.onDelete,
  });

  final DentalMaterial material;
  final Future<bool> Function() onEdit;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final code = _present(material.materialCode);
    final supplier = _present(material.supplier);
    final description = _present(fixMaybeDecoded(material.description));
    final price = '¥${material.defaultPrice.toStringAsFixed(0)}';
    final created = DateFormat('yyyy-MM-dd HH:mm').format(material.createdAt);
    final updated = DateFormat('yyyy-MM-dd HH:mm').format(material.updatedAt);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('材料详情'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SummaryCard(material: material, code: code, price: price),
          const SizedBox(height: 12),
          MaterialSectionCard(
            title: '基本信息',
            child: Column(
              children: [
                MaterialInfoLine(
                  icon: Icons.qr_code_rounded,
                  label: '编码',
                  value: code,
                ),
                MaterialInfoLine(
                  icon: Icons.category_rounded,
                  label: '材料类型',
                  value: material.materialType,
                ),
                MaterialInfoLine(
                  icon: Icons.straighten_rounded,
                  label: '单位',
                  value: material.unit,
                ),
                MaterialInfoLine(
                  icon: Icons.numbers_rounded,
                  label: '数量',
                  value: material.stockQuantity.toString(),
                ),
                MaterialInfoLine(
                  icon: Icons.attach_money_rounded,
                  label: '默认价格',
                  value: price,
                  valueColor: AppTheme.successColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MaterialSectionCard(
            title: '补充说明',
            child: Column(
              children: [
                MaterialInfoLine(
                  icon: Icons.business_rounded,
                  label: '供应商',
                  value: supplier,
                ),
                MaterialInfoLine(
                  icon: Icons.description_rounded,
                  label: '描述',
                  value: description,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MaterialSectionCard(
            title: '记录时间',
            child: Column(
              children: [
                MaterialInfoLine(
                  icon: Icons.calendar_today_rounded,
                  label: '创建时间',
                  value: created,
                ),
                MaterialInfoLine(
                  icon: Icons.update_rounded,
                  label: '更新时间',
                  value: updated,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await confirmDeleteMaterial(
                      context,
                      material,
                    );
                    if (!confirmed || !context.mounted) return;
                    final deleted = await onDelete();
                    if (deleted && context.mounted) {
                      Navigator.of(context).pop(MaterialDetailOutcome.deleted);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final saved = await onEdit();
                    if (saved && context.mounted) {
                      Navigator.of(context).pop(MaterialDetailOutcome.updated);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('编辑'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.material,
    required this.code,
    required this.price,
  });

  final DentalMaterial material;
  final String code;
  final String price;

  @override
  Widget build(BuildContext context) {
    return MaterialSectionCard(
      title: '材料',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.materialName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  code == '未填写' ? '未填写编码' : code,
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      icon: Icons.category_rounded,
                      text: material.materialType,
                      color: AppTheme.primaryColor,
                    ),
                    _Chip(
                      icon: Icons.straighten_rounded,
                      text: material.unit,
                      color: AppTheme.infoColor,
                    ),
                    _Chip(
                      icon: Icons.attach_money,
                      text: price,
                      color: AppTheme.successColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _present(String? value) {
  if (value == null || value.trim().isEmpty) return '未填写';
  return value;
}

Future<bool> confirmDeleteMaterial(
  BuildContext context,
  DentalMaterial material,
) {
  final code = material.materialCode;
  final details = [
    material.materialName,
    if (code != null && code.isNotEmpty) code,
    material.materialType,
    material.unit,
  ].join(' · ');
  return ModernDeleteDialogManager.show(
    context,
    title: '删除材料',
    message: '您确定要删除材料"${material.materialName}"吗？此操作不可撤销。',
    itemType: '库存材料',
    itemName: details,
    icon: Icons.inventory_2_rounded,
    accentColor: AppTheme.errorColor,
  );
}
