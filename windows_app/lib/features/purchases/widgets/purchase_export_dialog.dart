import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../theme/app_theme.dart';

class PurchaseExportDialog extends StatefulWidget {
  const PurchaseExportDialog({
    Key? key,
  }) : super(key: key);

  @override
  State<PurchaseExportDialog> createState() => _PurchaseExportDialogState();
}

class _PurchaseExportDialogState extends State<PurchaseExportDialog> {
  // 导出内容选择
  bool _includePurchaseRecord = false; // 采购记录
  bool _includePurchaseSummary = true; // 采购汇总（默认勾选）
  bool _includePurchaseDetails = true; // 采购项目明细（默认勾选）

  @override
  void initState() {
    super.initState();
    // 默认勾选采购项目明细和采购汇总
    _includePurchaseDetails = true;
    _includePurchaseSummary = true;
  }

  @override
  Widget build(BuildContext context) {
    final isPurpleTheme =
        false;

    final textColor = isPurpleTheme ? AppTheme.purplePrimaryText : null;
    final accentColor =
        isPurpleTheme ? AppTheme.purpleColor : Theme.of(context).primaryColor;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.image, color: accentColor),
          const SizedBox(width: 10),
          Text(
            '选择导出内容',
            style: TextStyle(color: textColor),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请选择要导出的内容区域：',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),

            // 采购记录选项
            _buildExportOption(
              title: '采购记录',
              subtitle: '包含采购记录的基本信息（采购日期、供应商、备注等）',
              icon: Icons.shopping_cart,
              iconColor: Colors.blue,
              value: _includePurchaseRecord,
              onChanged: (value) {
                setState(() {
                  _includePurchaseRecord = value ?? false;
                });
              },
            ),

            const SizedBox(height: 16),

            // 采购汇总选项
            _buildExportOption(
              title: '采购汇总',
              subtitle: '包含采购统计信息（总数量、总金额、项目数等）',
              icon: Icons.analytics,
              iconColor: Colors.green,
              value: _includePurchaseSummary,
              onChanged: (value) {
                setState(() {
                  _includePurchaseSummary = value ?? false;
                });
              },
            ),

            const SizedBox(height: 16),

            // 采购项目明细选项
            _buildExportOption(
              title: '采购项目明细',
              subtitle: '包含详细的采购项目列表（材料名称、数量、单价、总价等）',
              icon: Icons.list_alt,
              iconColor: Colors.orange,
              value: _includePurchaseDetails,
              onChanged: (value) {
                setState(() {
                  _includePurchaseDetails = value ?? false;
                });
              },
            ),

            const SizedBox(height: 20),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: context.tokens.primaryAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '至少需要选择一个区域进行导出。建议至少包含"采购项目明细"以获得完整的采购信息。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
          ),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _canExport()
              ? () {
                  Navigator.of(context).pop(getExportOptions());
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            disabledBackgroundColor: accentColor.withValues(alpha: 0.5),
          ),
          child: const Text('确认导出'),
        ),
      ],
    );
  }

  Widget _buildExportOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? iconColor.withValues(alpha: 0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              value ? iconColor.withValues(alpha: 0.3) : Colors.grey.shade300,
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (value) => onChanged(value ?? false),
            activeColor: iconColor,
            checkColor: context.tokens.cardBackground,
          ),
          const SizedBox(width: 8),
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: value ? iconColor : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.iconMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canExport() {
    return _includePurchaseRecord ||
        _includePurchaseSummary ||
        _includePurchaseDetails;
  }

  // 获取导出选项
  Map<String, bool> getExportOptions() {
    return {
      'purchaseRecord': _includePurchaseRecord,
      'purchaseSummary': _includePurchaseSummary,
      'purchaseDetails': _includePurchaseDetails,
    };
  }
}
