import 'package:flutter/material.dart';

/// 采购记录导出选项对话框
class PurchaseExportOptionsDialog extends StatefulWidget {
  const PurchaseExportOptionsDialog({super.key});

  @override
  State<PurchaseExportOptionsDialog> createState() => _PurchaseExportOptionsDialogState();
}

class _PurchaseExportOptionsDialogState extends State<PurchaseExportOptionsDialog> {
  final Map<String, bool> _exportOptions = {
    'purchaseRecord': false,
    'purchaseSummary': true,
    'purchaseDetails': true,
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '导出选项',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            
            // 选项内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择要导出的内容:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 采购记录基本信息
                  CheckboxListTile(
                    title: const Text('采购记录基本信息'),
                    subtitle: const Text('记录ID、日期、供应商、备注等'),
                    value: _exportOptions['purchaseRecord'],
                    onChanged: (value) {
                      setState(() {
                        _exportOptions['purchaseRecord'] = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  // 采购汇总统计
                  CheckboxListTile(
                    title: const Text('采购汇总统计'),
                    subtitle: const Text('总数量、总金额、项目数等'),
                    value: _exportOptions['purchaseSummary'],
                    onChanged: (value) {
                      setState(() {
                        _exportOptions['purchaseSummary'] = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  // 采购项目明细
                  CheckboxListTile(
                    title: const Text('采购项目明细'),
                    subtitle: const Text('材料名称、数量、单价、总价等'),
                    value: _exportOptions['purchaseDetails'],
                    onChanged: (value) {
                      setState(() {
                        _exportOptions['purchaseDetails'] = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_exportOptions),
                      child: const Text('导出'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
