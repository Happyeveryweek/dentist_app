import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../helpers/amount_input_formatter.dart';

/// 财务高级筛选对话框
/// 用于按收费项目和金额区间筛选财务记录
class FinancialAdvancedFilterDialog extends StatefulWidget {
  final String initialChargeItemQuery;
  final double? initialReceivableMin;
  final double? initialReceivableMax;
  final double? initialReceivedMin;
  final double? initialReceivedMax;
  final double? initialProcessingMin;
  final double? initialProcessingMax;

  const FinancialAdvancedFilterDialog({
    super.key,
    this.initialChargeItemQuery = '',
    this.initialReceivableMin,
    this.initialReceivableMax,
    this.initialReceivedMin,
    this.initialReceivedMax,
    this.initialProcessingMin,
    this.initialProcessingMax,
  });

  @override
  State<FinancialAdvancedFilterDialog> createState() =>
      _FinancialAdvancedFilterDialogState();
}

class _FinancialAdvancedFilterDialogState
    extends State<FinancialAdvancedFilterDialog> {
  late String _chargeItemQuery;
  late String _receivableMin;
  late String _receivableMax;
  late String _receivedMin;
  late String _receivedMax;
  late String _processingMin;
  late String _processingMax;

  @override
  void initState() {
    super.initState();
    _chargeItemQuery = widget.initialChargeItemQuery;
    _receivableMin = widget.initialReceivableMin?.toString() ?? '';
    _receivableMax = widget.initialReceivableMax?.toString() ?? '';
    _receivedMin = widget.initialReceivedMin?.toString() ?? '';
    _receivedMax = widget.initialReceivedMax?.toString() ?? '';
    _processingMin = widget.initialProcessingMin?.toString() ?? '';
    _processingMax = widget.initialProcessingMax?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 18, color: colors.onSurface),
                const SizedBox(width: 8),
                const Text('高级筛选',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: 20, color: colors.onSurface),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                  labelText: '收费项目（模糊）', prefixIcon: Icon(Icons.receipt_long)),
              controller: TextEditingController(text: _chargeItemQuery),
              onChanged: (v) => _chargeItemQuery = v,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: '应收费最小值',
                      prefixIcon: Icon(Icons.attach_money)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [amountInputFormatter],
                  controller: TextEditingController(text: _receivableMin),
                  onChanged: (v) => _receivableMin = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: '应收费最大值',
                      prefixIcon: Icon(Icons.attach_money)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [amountInputFormatter],
                  controller: TextEditingController(text: _receivableMax),
                  onChanged: (v) => _receivableMax = v,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: '已收费最小值', prefixIcon: Icon(Icons.payments)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [amountInputFormatter],
                  controller: TextEditingController(text: _receivedMin),
                  onChanged: (v) => _receivedMin = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: '已收费最大值', prefixIcon: Icon(Icons.payments)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [amountInputFormatter],
                  controller: TextEditingController(text: _receivedMax),
                  onChanged: (v) => _receivedMax = v,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: '加工费最小值', prefixIcon: Icon(Icons.build)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [amountInputFormatter],
                  controller: TextEditingController(text: _processingMin),
                  onChanged: (v) => _processingMin = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      labelText: '加工费最大值', prefixIcon: Icon(Icons.build)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [amountInputFormatter],
                  controller: TextEditingController(text: _processingMax),
                  onChanged: (v) => _processingMax = v,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'cleared': true,
                    });
                  },
                  child: const Text('清空'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    double? p(String s) =>
                        s.trim().isEmpty ? null : double.tryParse(s.trim());
                    Navigator.of(context).pop({
                      'cleared': false,
                      'chargeItemQuery': _chargeItemQuery.trim(),
                      'receivableMin': p(_receivableMin),
                      'receivableMax': p(_receivableMax),
                      'receivedMin': p(_receivedMin),
                      'receivedMax': p(_receivedMax),
                      'processingMin': p(_processingMin),
                      'processingMax': p(_processingMax),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.primaryAccent),
                  child: const Text('应用筛选'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
