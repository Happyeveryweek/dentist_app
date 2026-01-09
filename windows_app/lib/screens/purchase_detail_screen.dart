import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../providers/purchase_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../widgets/success_toast.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseRecord purchaseRecord;
  
  const PurchaseDetailScreen({
    Key? key,
    required this.purchaseRecord,
  }) : super(key: key);

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  List<PurchaseItem> _purchaseItems = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPurchaseItems();
  }

  Future<void> _loadPurchaseItems() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      final items = await purchaseProvider.getPurchaseItemsByRecordId(widget.purchaseRecord.id!);
      
      setState(() {
        _purchaseItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '加载采购项目失败: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildPurchaseItemCard(PurchaseItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(
            Icons.inventory_2,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          item.materialName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('数量: ${item.quantity} × ¥${item.unitPrice.toStringAsFixed(2)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${item.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editPurchaseItem(item),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(DentalIcons.shoppingCart, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('采购详情'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '导出为图片',
            onPressed: () => _exportPurchaseDetailAsImage(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 采购记录基本信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '采购记录信息',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.calendar_today,
                            label: '采购日期',
                            value: DateFormat('yyyy-MM-dd').format(widget.purchaseRecord.purchaseDate),
                            color: Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.inventory,
                            label: '总数量',
                            value: widget.purchaseRecord.totalQuantity.toString(),
                            color: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.attach_money,
                            label: '总金额',
                            value: '¥${widget.purchaseRecord.totalAmount.toStringAsFixed(2)}',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (widget.purchaseRecord.supplier != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoItem(
                        icon: Icons.business,
                        label: '供应商',
                        value: widget.purchaseRecord.supplier!,
                        color: Colors.purple,
                      ),
                    ],
                    if (widget.purchaseRecord.doctor != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoItem(
                        icon: Icons.person,
                        label: '采购医生',
                        value: widget.purchaseRecord.doctor!,
                        color: Colors.indigo,
                      ),
                    ],
                    if (widget.purchaseRecord.notes != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoItem(
                        icon: Icons.note,
                        label: '备注',
                        value: widget.purchaseRecord.notes!,
                        color: Colors.grey,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 采购项目列表
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(DentalIcons.pills, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          '采购项目明细',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '共 ${_purchaseItems.length} 项',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_hasError)
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 8),
                            Text(
                              '加载失败',
                              style: TextStyle(color: Colors.red[300]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPurchaseItems,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    else if (_purchaseItems.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            '暂无采购项目',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _purchaseItems.map((item) => _buildPurchaseItemCard(item)).toList(),
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

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            const Text(
              '采购详情',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.black87),
              onPressed: _exportPurchaseDetailAsImage,
            ),
          ],
        ),
      ),
    );
  }

  /// 导出采购详情为图片 - 使用Android端样式
  Future<void> _exportPurchaseDetailAsImage() async {
    try {
      // 确保采购项目已加载
      if (_purchaseItems.isEmpty && !_isLoading) {
        await _loadPurchaseItems();
      }
  
      // 显示导出选项对话框
      final result = await showDialog<Map<String, bool>>(
        context: context,
        builder: (context) => _ExportOptionsDialog(),
      );
      
      // 如果用户选择了导出选项，则执行导出
      if (result != null) {
        // 显示加载提示
        SuccessToastManager.showInfo(
          context,
          message: '正在生成图片...',
        );
  
        // 创建图片数据，传递选项参数
        final imageData = await _generatePurchaseDetailImage(
          widget.purchaseRecord,
          _purchaseItems,
          exportOptions: result,
        );
        
        // 保存到下载目录
        final resultPath = await _saveImageToDownloads(imageData);
        
        if (resultPath != null) {
          // 显示成功提示
          SuccessToastManager.show(
            context,
            message: '导出成功！图片已保存到下载目录',
            duration: const Duration(seconds: 2),
          );
        } else {
          // 显示失败提示
          SuccessToastManager.showError(
            context,
            message: '图片保存失败，请重试',
          );
        }
      }
    } catch (e) {
      // 显示错误提示
      SuccessToastManager.showError(
        context,
        message: '导出失败: $e',
      );
    }
  }

  /// 生成采购详情图片 - 支持选项选择
  Future<Uint8List> _generatePurchaseDetailImage(
    PurchaseRecord purchaseRecord,
    List<PurchaseItem> items, {
    Map<String, bool> exportOptions = const {
      'basicInfo': true,
      'summary': true,
      'details': true,
    },
  }) async {
    final baseWidth = 1080.0;
    const scale = 3.0;
    
    // 计算图片高度，根据选项动态调整
    double calculateHeight() {
      double height = 120; // 顶部边距
      
      if (exportOptions['basicInfo'] == true) {
        height += 120; // 标题区域
        height += 320; // 基本信息区域
      }
      
      if (exportOptions['summary'] == true) {
        height += 80; // 汇总标题
        height += 200; // 汇总统计区域
      }
      
      if (exportOptions['details'] == true && items.isNotEmpty) {
        height += 80; // 明细标题
        height += 120; // 表头
        height += items.length * 100; // 项目行
        height += 100; // 总计行
      }
      
      height += 100; // 底部边距和页脚
      return height;
    }
    
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    
    // 设置画布背景为白色
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, baseWidth, calculateHeight()), paint);
    
    // 创建文本样式
    final textStyle = ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontSize: 32 * scale,
      fontFamily: 'Roboto',
    );
    
    double currentY = 60;
    
    // 标题
    if (exportOptions['basicInfo'] == true) {
      final titleStyle = ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 48 * scale,
        fontWeight: FontWeight.w900,
        fontFamily: 'Roboto',
      );
      
      final titleBuilder = ui.ParagraphBuilder(titleStyle)
        ..pushStyle(ui.TextStyle(
          color: const Color(0xFF7B1FA2),
          fontSize: 48 * scale,
          fontWeight: FontWeight.w900,
        ))
        ..addText('采购记录详情');
      
      final titleParagraph = titleBuilder.build()
        ..layout(ui.ParagraphConstraints(width: baseWidth - 80));
      
      canvas.drawParagraph(titleParagraph, Offset(40, currentY));
      currentY += 120;
      
      // 基本信息区域
      final basicInfoPaint = Paint()
        ..color = const Color(0xFFF8F9FA)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(40, currentY, baseWidth - 80, 280),
          const Radius.circular(16),
        ),
        basicInfoPaint,
      );
      
      final basicInfoStyle = ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 36 * scale,
        fontWeight: FontWeight.bold,
        fontFamily: 'Roboto',
      );
      
      final basicInfoBuilder = ui.ParagraphBuilder(basicInfoStyle)
        ..pushStyle(ui.TextStyle(
          color: const Color(0xFF1976D2),
          fontSize: 36 * scale,
          fontWeight: FontWeight.bold,
        ))
        ..addText('基本信息');
      
      final basicInfoParagraph = basicInfoBuilder.build()
        ..layout(ui.ParagraphConstraints(width: baseWidth - 120));
      
      canvas.drawParagraph(basicInfoParagraph, Offset(60, currentY + 20));
      
      final infoTextStyle = ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 32 * scale,
        fontFamily: 'Roboto',
      );
      
      final infoBuilder = ui.ParagraphBuilder(infoTextStyle)
        ..pushStyle(ui.TextStyle(
          color: Colors.black87,
          fontSize: 32 * scale,
        ))
        ..addText('采购日期: ${DateFormat('yyyy-MM-dd').format(purchaseRecord.purchaseDate)}\n')
        ..addText('供应商: ${purchaseRecord.supplier ?? '无'}\n')
        ..addText('采购医生: ${purchaseRecord.doctor ?? '无'}\n')
        ..addText('备注: ${purchaseRecord.notes ?? '无'}');
      
      final infoParagraph = infoBuilder.build()
        ..layout(ui.ParagraphConstraints(width: baseWidth - 120));
      
      canvas.drawParagraph(infoParagraph, Offset(60, currentY + 80));
      currentY += 320;
    }
    
    // 汇总统计
    if (exportOptions['summary'] == true) {
      final summaryTitleStyle = ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 36 * scale,
        fontWeight: FontWeight.bold,
        fontFamily: 'Roboto',
      );
      
      final summaryTitleBuilder = ui.ParagraphBuilder(summaryTitleStyle)
        ..pushStyle(ui.TextStyle(
          color: const Color(0xFF1976D2),
          fontSize: 36 * scale,
          fontWeight: FontWeight.bold,
        ))
        ..addText('采购汇总统计');
      
      final summaryTitleParagraph = summaryTitleBuilder.build()
        ..layout(ui.ParagraphConstraints(width: baseWidth - 80));
      
      canvas.drawParagraph(summaryTitleParagraph, Offset(40, currentY + 20));
      
      final summaryPaint = Paint()
        ..color = const Color(0xFFF8F9FA)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(40, currentY + 80, baseWidth - 80, 120),
          const Radius.circular(16),
        ),
        summaryPaint,
      );
      
      final totalAmount = items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
      
      final summaryStyle = ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 32 * scale,
        fontFamily: 'Roboto',
      );
      
      final summaryBuilder = ui.ParagraphBuilder(summaryStyle)
        ..pushStyle(ui.TextStyle(
          color: Colors.black87,
          fontSize: 32 * scale,
        ))
        ..addText('总项目数: ${items.length}\n')
        ..addText('总金额: ¥${totalAmount.toStringAsFixed(2)}');
      
      final summaryParagraph = summaryBuilder.build()
        ..layout(ui.ParagraphConstraints(width: baseWidth - 120));
      
      canvas.drawParagraph(summaryParagraph, Offset(60, currentY + 100));
      currentY += 200;
    }
    
    // 项目明细
    if (exportOptions['details'] == true && items.isNotEmpty) {
      final detailsTitleStyle = ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 36 * scale,
        fontWeight: FontWeight.bold,
        fontFamily: 'Roboto',
      );
      
      final detailsTitleBuilder = ui.ParagraphBuilder(detailsTitleStyle)
        ..pushStyle(ui.TextStyle(
          color: const Color(0xFF1976D2),
          fontSize: 36 * scale,
          fontWeight: FontWeight.bold,
        ))
        ..addText('采购项目明细');
      
      final detailsTitleParagraph = detailsTitleBuilder.build()
        ..layout(ui.ParagraphConstraints(width: baseWidth - 80));
      
      canvas.drawParagraph(detailsTitleParagraph, Offset(40, currentY + 20));
      currentY += 80;
      
      // 表头
      final headerPaint = Paint()
        ..color = const Color(0xFF1976D2)
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(40, currentY, baseWidth - 80, 80),
        headerPaint,
      );
      
      final headerStyle = ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 28 * scale,
        fontWeight: FontWeight.bold,
        fontFamily: 'Roboto',
      );
      
      final headers = ['材料名称', '数量', '单位', '单价', '总价'];
      final columnWidths = [300.0, 120.0, 100.0, 150.0, 150.0];
      
      double currentX = 40;
      for (int i = 0; i < headers.length; i++) {
        final headerBuilder = ui.ParagraphBuilder(headerStyle)
          ..pushStyle(ui.TextStyle(
            color: Colors.white,
            fontSize: 28 * scale,
            fontWeight: FontWeight.bold,
          ))
          ..addText(headers[i]);
        
        final headerParagraph = headerBuilder.build()
          ..layout(ui.ParagraphConstraints(width: columnWidths[i]));
        
        canvas.drawParagraph(headerParagraph, Offset(currentX + (columnWidths[i] - headerParagraph.width) / 2, currentY + 20));
        currentX += columnWidths[i];
      }
      
      currentY += 100;
      
      // 项目行
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final rowPaint = Paint()
          ..color = i % 2 == 0 ? const Color(0xFFF8F9FA) : Colors.white
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromLTWH(40, currentY, baseWidth - 80, 80),
          rowPaint,
        );
        
        final rowStyle = ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontSize: 24 * scale,
          fontFamily: 'Roboto',
        );
        
        final values = [
          item.materialName,
          item.quantity.toString(),
          item.unit,
          '¥${item.unitPrice.toStringAsFixed(2)}',
          '¥${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
        ];
        
        currentX = 40;
        for (int j = 0; j < values.length; j++) {
          final rowBuilder = ui.ParagraphBuilder(rowStyle)
            ..pushStyle(ui.TextStyle(
              color: Colors.black87,
              fontSize: 24 * scale,
            ))
            ..addText(values[j]);
          
          final rowParagraph = rowBuilder.build()
            ..layout(ui.ParagraphConstraints(width: columnWidths[j]));
          
          canvas.drawParagraph(rowParagraph, Offset(currentX + (columnWidths[j] - rowParagraph.width) / 2, currentY + 20));
          currentX += columnWidths[j];
        }
        
        currentY += 80;
      }
      
      // 总计行
      final totalAmount = items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
      final totalPaint = Paint()
        ..color = const Color(0xFFE8F5E8)
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(40, currentY, baseWidth - 80, 80),
        totalPaint,
      );
      
      final totalStyle = ui.ParagraphStyle(
        textAlign: TextAlign.right,
        fontSize: 28 * scale,
        fontWeight: FontWeight.bold,
        fontFamily: 'Roboto',
      );
      
      final totalBuilder = ui.ParagraphBuilder(totalStyle)
        ..pushStyle(ui.TextStyle(
          color: const Color(0xFF2E7D32),
          fontSize: 28 * scale,
          fontWeight: FontWeight.bold,
        ))
        ..addText('总计: ¥${totalAmount.toStringAsFixed(2)}');
      
      final totalParagraph = totalBuilder.build()
        ..layout(ui.ParagraphConstraints(width: baseWidth - 120));
      
      canvas.drawParagraph(totalParagraph, Offset(60, currentY + 20));
      currentY += 100;
    }
    
    // 页脚
    final footerStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 24 * scale,
      fontFamily: 'Roboto',
    );
    
    final footerBuilder = ui.ParagraphBuilder(footerStyle)
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF666666),
        fontSize: 24 * scale,
      ))
      ..addText('导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    
    final footerParagraph = footerBuilder.build()
      ..layout(ui.ParagraphConstraints(width: baseWidth - 80));
    
    canvas.drawParagraph(footerParagraph, Offset(40, currentY + 40));
    
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(
      (baseWidth * scale).toInt(),
      (calculateHeight() * scale).toInt(),
    );
    
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 保存图片到下载目录
  Future<String?> _saveImageToDownloads(Uint8List imageData) async {
    try {
      final directory = await getDownloadsDirectory();
      final saveDir = directory ?? await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      // 使用PNG格式保持最佳质量
      final fileName = '采购详情_${timestamp}.png';
      final file = File('${saveDir.path}/$fileName');
      
      await file.writeAsBytes(imageData);
      return file.path;
    } catch (e) {
      print('保存图片失败: $e');
      return null;
    }
  }

/// 导出选项对话框
class _ExportOptionsDialog extends StatefulWidget {
const _ExportOptionsDialog();

@override
State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
bool _exportBasicInfo = true;
bool _exportSummary = true;
bool _exportDetails = true;

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);

return AlertDialog(
title: const Text('选择导出内容'),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
CheckboxListTile(
title: const Text('采购记录基本信息'),
value: _exportBasicInfo,
onChanged: (value) {
setState(() {
_exportBasicInfo = value ?? true;
});
},
),
CheckboxListTile(
title: const Text('采购汇总统计'),
value: _exportSummary,
onChanged: (value) {
setState(() {
_exportSummary = value ?? true;
});
},
),
CheckboxListTile(
title: const Text('采购项目明细'),
value: _exportDetails,
onChanged: (value) {
setState(() {
_exportDetails = value ?? true;
});
},
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('取消'),
),
ElevatedButton(
onPressed: (_exportBasicInfo || _exportSummary || _exportDetails)
? () {
Navigator.pop(context, {
'basicInfo': _exportBasicInfo,
'summary': _exportSummary,
'details': _exportDetails,
});
}
: null,
child: const Text('导出'),
),
],
);
}
}

  /// 编辑采购项目
  Future<void> _editPurchaseItem(PurchaseItem item) async {
    final result = await showDialog<PurchaseItem>(
      context: context,
      builder: (context) => _EditPurchaseItemDialog(
        item: item,
        purchaseRecord: widget.purchaseRecord,
      ),
    );
    
    if (result != null) {
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        await purchaseProvider.updatePurchaseItem(result);
        
        // 重新加载采购项目
        await _loadPurchaseItems();
        
        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('采购项目更新成功')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

/// 编辑采购项目对话框
class _EditPurchaseItemDialog extends StatefulWidget {
  final PurchaseItem item;
  final PurchaseRecord purchaseRecord;

  const _EditPurchaseItemDialog({
    Key? key,
    required this.item,
    required this.purchaseRecord,
  }) : super(key: key);

  @override
  State<_EditPurchaseItemDialog> createState() => _EditPurchaseItemDialogState();
}

class _EditPurchaseItemDialogState extends State<_EditPurchaseItemDialog> {
  late TextEditingController _materialNameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;
  late TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _materialNameController = TextEditingController(text: widget.item.materialName);
    _quantityController = TextEditingController(text: widget.item.quantity.toString());
    _unitPriceController = TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
    _unitController = TextEditingController(text: widget.item.unit ?? '个');
  }

  @override
  void dispose() {
    _materialNameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑采购项目'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _materialNameController,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                labelText: '材料名称',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      labelText: '单位',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _unitPriceController,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                labelText: '单价',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('总价:'),
                  Text(
                    '¥${_calculateTotalPrice().toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('保存'),
        ),
      ],
    );
  }

  double _calculateTotalPrice() {
    try {
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
      return quantity * unitPrice;
    } catch (e) {
      return 0;
    }
  }

  void _saveChanges() {
    if (_materialNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入材料名称')),
      );
      return;
    }

    try {
      final quantity = double.parse(_quantityController.text);
      final unitPrice = double.parse(_unitPriceController.text);
      final totalPrice = quantity * unitPrice;

      final updatedItem = PurchaseItem(
        id: widget.item.id,
        purchaseRecordId: widget.item.purchaseRecordId,
        materialId: widget.item.materialId,
        materialName: _materialNameController.text.trim(),
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
        unit: _unitController.text.trim(),
        createdAt: widget.item.createdAt,
        updatedAt: DateTime.now(),
      );

      Navigator.pop(context, updatedItem);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数字')),
      );
    }
  }
}