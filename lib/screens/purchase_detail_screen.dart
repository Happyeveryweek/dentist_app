import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../providers/purchase_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/purchase_item_dialog.dart'; // Added import for PurchaseItemDialog
import '../widgets/purchase_record_dialog.dart'; // Added import for PurchaseRecordDialog
import '../widgets/success_toast.dart';
import '../utils/permission_utils.dart';
import '../utils/datetime_formatter.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseRecord record;

  const PurchaseDetailScreen({super.key, required this.record});

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
      
      // ✅ 检查数据库连接状态
      if (!purchaseProvider.isInitialized) {
        throw Exception('数据库未初始化，请检查数据库连接');
      }
      
      print('🔄 开始加载采购项目，记录ID: ${widget.record.id}');
      final items = await purchaseProvider.getPurchaseItemsByRecordId(widget.record.id!);
      
      // ✅ 按更新时间降序排序，确保最新添加/更新的项目显示在最上面
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      print('✅ 成功加载 ${items.length} 个采购项目，按更新时间排序');
      setState(() {
        _purchaseItems = items;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 加载采购项目失败: $e');
      setState(() {
        _hasError = true;
        _errorMessage = '加载采购项目失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('采购记录详情 #${widget.record.id}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () => _showExportOptions(context),
            tooltip: '导出为图片',
          ),
          PermissionWrapper(
            module: 'purchase',
            action: 'edit',
            recordDoctor: widget.record.doctor,
            onPermissionDenied: () {
              PermissionUtils.showPermissionDeniedMessage(
                context,
                customMessage: '您只能编辑自己的采购记录',
              );
            },
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editPurchaseRecord(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deletePurchaseRecord(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本信息
            _buildBasicInfoCard(),
            const SizedBox(height: 16),
            
            // 采购项目明细
            _buildItemsCard(),
            const SizedBox(height: 16),
            
            // 金额信息
            _buildAmountCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('记录ID:', '#${widget.record.id}'),
          _buildInfoRow('采购日期:', DateFormat('yyyy-MM-dd').format(widget.record.purchaseDate)),
          _buildInfoRow('供应商:', widget.record.supplier ?? '未指定'),
          _buildInfoRow('采购医生:', widget.record.doctor ?? '未指定'),
          _buildInfoRow('备注:', widget.record.notes ?? '无'),
          _buildInfoRow('创建时间:', DateFormat('yyyy-MM-dd HH:mm').format(widget.record.createdAt)),
          if (widget.record.updatedAt != widget.record.createdAt)
            _buildInfoRow('更新时间:', DateFormat('yyyy-MM-dd HH:mm').format(widget.record.updatedAt)),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '采购项目明细',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _addPurchaseItem(context),
                icon: const Icon(Icons.add),
                label: const Text('添加项目'),
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
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '暂无采购项目',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // 表头
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('材料名称', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                      Expanded(flex: 1, child: Text('数量', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('单价', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('单位', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('总价', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 项目列表
                ..._purchaseItems.map((item) => _buildPurchaseItemCard(item)).toList(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPurchaseItemCard(PurchaseItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.materialName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.quantity.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '¥${NumberFormat('#,##0.00').format(item.unitPrice)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange[700]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.unit ?? '-',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '¥${NumberFormat('#,##0.00').format(item.totalPrice)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '金额信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAmountItem(
                  '总金额',
                  '¥${NumberFormat('#,##0.00').format(widget.record.totalAmount)}',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildAmountItem(
                  '总数量',
                  widget.record.totalQuantity.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildAmountItem(
                  '项目数',
                  _purchaseItems.length.toString(),
                  Icons.list,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAmountItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addPurchaseItem(BuildContext context) async {
    final result = await showDialog<PurchaseItem>(
      context: context,
      builder: (context) => PurchaseItemDialog(
        purchaseRecordId: widget.record.id!, // ✅ 传递采购记录ID
      ),
    );
    
    if (result != null) {
      // 添加采购项目到数据库
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        
        // ✅ 确保项目有正确的采购记录ID和统一的时间格式
        final now = DateTimeFormatter.nowLocal();
        final purchaseItem = result.copyWith(
          purchaseRecordId: widget.record.id!,
          createdAt: now,
          updatedAt: now,
        );
        
        final itemId = await purchaseProvider.addPurchaseItem(purchaseItem);
        if (itemId > 0) {
          // 重新加载采购项目
          await _loadPurchaseItems();
          
          // ✅ 显示成功提示
          if (mounted) {
            // 使用公共组件的绿色背景成功提示
            SuccessToastManager.show(
              context,
              message: '采购项目添加成功',
              duration: const Duration(seconds: 2),
            );
          }
        } else {
          throw Exception('添加失败：返回ID无效');
        }
      } catch (e) {
        print('添加采购项目失败: $e');
        if (mounted) {
          // 使用公共组件的错误提示
          SuccessToastManager.showError(
            context,
            message: '添加失败: $e',
            duration: const Duration(seconds: 3),
          );
        }
      }
    }
  }

  void _editPurchaseRecord(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PurchaseRecordDialog(record: widget.record),
    );
    
    if (result == true) {
      // 编辑成功，重新加载数据
      await _loadPurchaseItems();
      // 使用公共组件的绿色背景成功提示
      SuccessToastManager.show(
        context,
        message: '采购记录已更新',
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _deletePurchaseRecord(BuildContext context) async {
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showPurchaseDelete(
      context,
      purchaseInfo: '采购记录 #${widget.record.id}',
    );

    if (confirmed == true) {
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final success = await purchaseProvider.deletePurchaseRecord(widget.record.id!);
        
        if (success > 0) {
          if (mounted) {
            // 删除成功后返回上一页，并传递删除成功的标志
            Navigator.of(context).pop(true);
            DeleteSuccessToastManager.show(
              context,
              message: '采购记录已删除',
            );
          }
        } else {
          SuccessToastManager.showError(
            context,
            message: '删除失败',
          );
        }
      } catch (e) {
        SuccessToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }

  // 显示导出选项对话框
  Future<void> _showExportOptions(BuildContext context) async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => _ExportOptionsDialog(),
    );
    
    // 如果用户选择了导出选项，则执行导出
    if (result != null) {
      _exportPurchaseRecordAsImage(result);
    }
  }

  /// 导出采购记录为图片
  Future<void> _exportPurchaseRecordAsImage(Map<String, bool> exportOptions) async {
    try {
      // 显示加载提示
      SuccessToastManager.showInfo(
        context,
        message: '正在生成图片...',
      );

      // 创建图片数据
      final imageData = await _generatePurchaseRecordImage(exportOptions);
      
      // 保存图片
      final result = await _saveImageToDownloads(imageData);
      
      if (result != null) {
        // 显示成功提示
        SuccessToastManager.show(
          context,
          message: '图片已保存到: $result',
        );
      } else {
        // 显示失败提示
        SuccessToastManager.showError(
          context,
          message: '图片保存失败',
        );
      }
    } catch (e) {
      SuccessToastManager.showError(
        context,
        message: '导出失败: $e',
      );
    }
  }

  /// 生成采购记录图片 - 优化版
  Future<Uint8List> _generatePurchaseRecordImage(Map<String, bool> exportOptions) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();
    
    // 优化安卓端图片尺寸 - 更高的DPI和更适合手机屏幕的比例
    const double baseWidth = 1080.0;  // 增加宽度以提高清晰度
    double baseHeight = 1920.0;  // 基础高度，会根据内容动态调整
    
    // 设置高DPI以获得更清晰的图像
    const double scale = 3.0;  // 3x DPI for high resolution

    final double scaledWidth = baseWidth * scale;
    
    // 先绘制一个足够大的白色背景（使用一个很大的高度，最后会裁剪到实际需要的高度）
    paint.color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, scaledWidth, baseHeight * scale * 2), paint);
    
    // 边距和间距设置
    const double margin = 60.0 * scale;
    const double sectionSpacing = 40.0 * scale;
    const double itemSpacing = 20.0 * scale;
    double currentY = margin;
    
    // 标题 - 加粗加大
    paint.color = const Color(0xFF000000);
    final titleStyle = TextStyle(
      fontSize: 48 * scale,  // 增大字体
      fontWeight: FontWeight.w900,  // 更粗的字体
      color: const Color(0xFF000000),
      fontFamily: 'Roboto',  // 使用安卓标准字体
    );
    final titlePainter = TextPainter(
      text: TextSpan(text: '采购记录详情', style: titleStyle),
      textDirection: ui.TextDirection.ltr,
    );
    titlePainter.layout(maxWidth: scaledWidth - 2 * margin);
    titlePainter.paint(canvas, Offset((scaledWidth - titlePainter.width) / 2, currentY));
    currentY += titlePainter.height + sectionSpacing;
    
    // 采购记录基本信息
    if (exportOptions['purchaseRecord'] == true) {
      // 区域背景 - 轻微的灰色背景
      paint.color = const Color(0xFFF8F9FA);
      final recordInfoHeight = 380.0 * scale;  // 预估高度，增加医生字段后需要更多空间
      canvas.drawRect(Rect.fromLTWH(margin, currentY, scaledWidth - 2 * margin, recordInfoHeight), paint);
      
      // 标题
      paint.color = const Color(0xFF1976D2);
      final sectionTitleStyle = TextStyle(
        fontSize: 36 * scale,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1976D2),
        fontFamily: 'Roboto',
      );
      final sectionTitlePainter = TextPainter(
        text: TextSpan(text: '基本信息', style: sectionTitleStyle),
        textDirection: ui.TextDirection.ltr,
      );
      sectionTitlePainter.layout();
      sectionTitlePainter.paint(canvas, Offset(margin + 20 * scale, currentY + 20 * scale));
      
      // 详细信息 - 加粗字体
      paint.color = const Color(0xFF212121);
      final basicInfoStyle = TextStyle(
        fontSize: 32 * scale,  // 增大字体
        fontWeight: FontWeight.w600,  // 加粗
        color: const Color(0xFF212121),
        fontFamily: 'Roboto',
        height: 1.5,  // 增加行高
      );
      final basicInfoText =
          '记录ID: #${widget.record.id}\n'
          '采购日期: ${DateFormat('yyyy年MM月dd日').format(widget.record.purchaseDate)}\n'
          '${widget.record.supplier != null && widget.record.supplier!.isNotEmpty ? '供应商: ${widget.record.supplier}\n' : ''}'
          '${widget.record.doctor != null && widget.record.doctor!.isNotEmpty ? '采购医生: ${widget.record.doctor}\n' : ''}'
          '${widget.record.notes != null && widget.record.notes!.isNotEmpty ? '备注: ${widget.record.notes}\n' : ''}'
          '创建时间: ${DateFormat('yyyy年MM月dd日 HH:mm').format(widget.record.createdAt)}\n'
          '${widget.record.updatedAt != widget.record.createdAt ? '更新时间: ${DateFormat('yyyy年MM月dd日 HH:mm').format(widget.record.updatedAt)}' : ''}';
      
      final basicInfoPainter = TextPainter(
        text: TextSpan(text: basicInfoText, style: basicInfoStyle),
        textDirection: ui.TextDirection.ltr,
      );
      basicInfoPainter.layout(maxWidth: scaledWidth - 2 * margin - 40 * scale);
      basicInfoPainter.paint(canvas, Offset(margin + 20 * scale, currentY + 80 * scale));
      currentY += recordInfoHeight + sectionSpacing;
    }
    
    // 采购汇总统计信息
    if (exportOptions['purchaseSummary'] == true) {
      // 区域背景
      paint.color = const Color(0xFFF3E5F5);
      final summaryHeight = 200.0 * scale;
      canvas.drawRect(Rect.fromLTWH(margin, currentY, scaledWidth - 2 * margin, summaryHeight), paint);
      
      // 标题
      paint.color = const Color(0xFF7B1FA2);
      final summaryTitleStyle = TextStyle(
        fontSize: 36 * scale,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF7B1FA2),
        fontFamily: 'Roboto',
      );
      final summaryTitlePainter = TextPainter(
        text: TextSpan(text: '采购汇总', style: summaryTitleStyle),
        textDirection: ui.TextDirection.ltr,
      );
      summaryTitlePainter.layout();
      summaryTitlePainter.paint(canvas, Offset(margin + 20 * scale, currentY + 20 * scale));
      
      // 统计信息 - 加粗字体
      paint.color = const Color(0xFF212121);
      final statStyle = TextStyle(
        fontSize: 32 * scale,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF212121),
        fontFamily: 'Roboto',
        height: 1.5,
      );
      final statText =
          '总采购数量: ${widget.record.totalQuantity} 件\n'
          '总采购金额: ¥${NumberFormat('#,##0.00').format(widget.record.totalAmount)}\n'
          '采购项目数: ${_purchaseItems.length} 项';
      
      final statPainter = TextPainter(
        text: TextSpan(text: statText, style: statStyle),
        textDirection: ui.TextDirection.ltr,
      );
      statPainter.layout(maxWidth: scaledWidth - 2 * margin - 40 * scale);
      statPainter.paint(canvas, Offset(margin + 20, currentY + 80));
      currentY += summaryHeight + sectionSpacing;
    }
    
    // 采购项目明细
    if (exportOptions['purchaseDetails'] == true) {
      // 表格标题
      paint.color = const Color(0xFF1976D2);
      final tableTitleStyle = TextStyle(
        fontSize: 40 * scale,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1976D2),
        fontFamily: 'Roboto',
      );
      final tableTitlePainter = TextPainter(
        text: TextSpan(text: '采购项目明细', style: tableTitleStyle),
        textDirection: ui.TextDirection.ltr,
      );
      tableTitlePainter.layout();
      tableTitlePainter.paint(canvas, Offset(margin, currentY));
      currentY += tableTitlePainter.height + 30 * scale;
      
      if (_purchaseItems.isEmpty) {
        // 空状态提示
        paint.color = const Color(0xFF757575);
        final emptyStyle = TextStyle(
          fontSize: 32 * scale,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF757575),
          fontFamily: 'Roboto',
        );
        final emptyPainter = TextPainter(
          text: TextSpan(text: '暂无采购项目', style: emptyStyle),
          textDirection: ui.TextDirection.ltr,
        );
        emptyPainter.layout();
        emptyPainter.paint(canvas, Offset((scaledWidth - emptyPainter.width) / 2, currentY));
        currentY += emptyPainter.height + sectionSpacing;
      } else {
        // 表格头部 - 灰色背景
        const double tableHeaderHeight = 80.0 * scale;
        paint.color = const Color(0xFFE0E0E0);  // 灰色背景
        canvas.drawRect(Rect.fromLTWH(margin, currentY, scaledWidth - 2 * margin, tableHeaderHeight), paint);
        
        // 表头文字 - 加粗，左对齐
        paint.color = const Color(0xFF212121);
        final headerStyle = TextStyle(
          fontSize: 32 * scale,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF212121),
          fontFamily: 'Roboto',
        );
        
        // 表格列设置 - 适配手机屏幕
        final columnWidths = [380.0, 120.0, 120.0, 150.0, 180.0].map((e) => e * scale).toList();  // 调整列宽并缩放
        final headers = ['材料名称', '数量', '单位', '单价', '总价'];
        double currentX = margin + 20 * scale;  // 统起点始位置，左对齐
        
        // 材料名称 - 左对齐
        final nameHeaderPainter = TextPainter(
          text: TextSpan(text: headers[0], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        nameHeaderPainter.layout();
        nameHeaderPainter.paint(canvas, Offset(currentX + 10 * scale, currentY + (tableHeaderHeight - nameHeaderPainter.height) / 2));
        currentX += columnWidths[0];
        
        // 数量 - 居中对齐
        final quantityHeaderPainter = TextPainter(
          text: TextSpan(text: headers[1], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        quantityHeaderPainter.layout();
        quantityHeaderPainter.paint(canvas,
            Offset(currentX + (columnWidths[1] - quantityHeaderPainter.width) / 2,
                   currentY + (tableHeaderHeight - quantityHeaderPainter.height) / 2));
        currentX += columnWidths[1];
        
        // 单位 - 居中对齐
        final unitHeaderPainter = TextPainter(
          text: TextSpan(text: headers[2], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitHeaderPainter.layout();
        unitHeaderPainter.paint(canvas,
            Offset(currentX + (columnWidths[2] - unitHeaderPainter.width) / 2,
                   currentY + (tableHeaderHeight - unitHeaderPainter.height) / 2));
        currentX += columnWidths[2];
        
        // 单价 - 居中对齐
        final unitPriceHeaderPainter = TextPainter(
          text: TextSpan(text: headers[3], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitPriceHeaderPainter.layout();
        unitPriceHeaderPainter.paint(canvas,
            Offset(currentX + (columnWidths[3] - unitPriceHeaderPainter.width) / 2,
                   currentY + (tableHeaderHeight - unitPriceHeaderPainter.height) / 2));
        currentX += columnWidths[3];
        
        // 总价 - 居中对齐
        final totalPriceHeaderPainter = TextPainter(
          text: TextSpan(text: headers[4], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        totalPriceHeaderPainter.layout();
        totalPriceHeaderPainter.paint(canvas,
            Offset(currentX + (columnWidths[4] - totalPriceHeaderPainter.width) / 2,
                   currentY + (tableHeaderHeight - totalPriceHeaderPainter.height) / 2));
        currentY += tableHeaderHeight;
        
        // 表格内容
        const double rowHeight = 100.0 * scale;
        final contentStyle = TextStyle(
          fontSize: 28 * scale,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF212121),
          fontFamily: 'Roboto',
        );
        
        for (final item in _purchaseItems) {
          // 交替背景色
          paint.color = _purchaseItems.indexOf(item) % 2 == 0 
              ? const Color(0xFFFFFFFF) 
              : const Color(0xFFF5F5F5);
          canvas.drawRect(Rect.fromLTWH(margin, currentY, scaledWidth - 2 * margin, rowHeight), paint);
          
          // 绘制分隔线
          paint.color = const Color(0xFFE0E0E0);
          canvas.drawLine(
            Offset(margin, currentY + rowHeight),
            Offset(scaledWidth - margin, currentY + rowHeight),
            paint,
          );
          
          double currentX = margin + 20 * scale; // 统起点始位置
          
          // 材料名称 - 左对齐
          final namePainter = TextPainter(
            text: TextSpan(text: item.materialName, style: contentStyle),
            textDirection: ui.TextDirection.ltr,
            maxLines: 2,
            ellipsis: '...',
          );
          namePainter.layout(maxWidth: columnWidths[0] - 40 * scale); // 留出边距
          namePainter.paint(canvas, Offset(currentX + 10 * scale, currentY + 15 * scale)); // 左对齐，顶部留边距
          currentX += columnWidths[0];
          
          // 数量 - 居中对齐
          final quantityText = '${item.quantity}';
          final quantityPainter = TextPainter(
            text: TextSpan(text: quantityText, style: contentStyle),
            textDirection: ui.TextDirection.ltr,
          );
          quantityPainter.layout();
          quantityPainter.paint(canvas, 
              Offset(currentX + (columnWidths[1] - quantityPainter.width) / 2, 
                     currentY + (rowHeight - quantityPainter.height) / 2));
          currentX += columnWidths[1];
          
          // 单位 - 居中对齐
          final unitText = item.unit ?? '个';
          final unitPainter = TextPainter(
            text: TextSpan(text: unitText, style: contentStyle),
            textDirection: ui.TextDirection.ltr,
          );
          unitPainter.layout();
          unitPainter.paint(canvas, 
              Offset(currentX + (columnWidths[2] - unitPainter.width) / 2, 
                     currentY + (rowHeight - unitPainter.height) / 2));
          currentX += columnWidths[2];
          
          // 单价 - 居中对齐
          final unitPriceText = '¥${item.unitPrice.toStringAsFixed(2)}';
          final unitPricePainter = TextPainter(
            text: TextSpan(text: unitPriceText, style: contentStyle),
            textDirection: ui.TextDirection.ltr,
          );
          unitPricePainter.layout();
          unitPricePainter.paint(canvas, 
              Offset(currentX + (columnWidths[3] - unitPricePainter.width) / 2, 
                     currentY + (rowHeight - unitPainter.height) / 2));
          currentX += columnWidths[3];
          
          // 总价 - 居中对齐，加粗显示
          final totalPriceText = '¥${item.totalPrice.toStringAsFixed(2)}';
          final totalPriceStyle = TextStyle(
            fontSize: 28 * scale,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E7D32),
            fontFamily: 'Roboto',
          );
          final totalPricePainter = TextPainter(
            text: TextSpan(text: totalPriceText, style: totalPriceStyle),
            textDirection: ui.TextDirection.ltr,
          );
          totalPricePainter.layout();
          totalPricePainter.paint(canvas, 
              Offset(currentX + (columnWidths[4] - totalPricePainter.width) / 2, 
                     currentY + (rowHeight - totalPricePainter.height) / 2));
          
          currentY += rowHeight;
        }
        
        // 总计行
        paint.color = const Color(0xFFE8F5E8);
        canvas.drawRect(Rect.fromLTWH(margin, currentY, scaledWidth - 2 * margin, rowHeight), paint);
        
        final totalAmount = _purchaseItems.fold(0.0, (sum, item) => sum + item.totalPrice);
        final totalStyle = TextStyle(
          fontSize: 36 * scale, // 增大字体并应用缩放
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2E7D32),
          fontFamily: 'Roboto',
        );
        
        final totalText = '总计: ¥${totalAmount.toStringAsFixed(2)}';
        final totalPainter = TextPainter(
          text: TextSpan(text: totalText, style: totalStyle),
          textDirection: ui.TextDirection.ltr,
        );
        totalPainter.layout();
        totalPainter.paint(canvas,
            Offset(scaledWidth - margin - totalPainter.width - 20 * scale, currentY + (rowHeight - totalPainter.height) / 2));
        
        currentY += rowHeight + sectionSpacing;
      }
    }
    
    // 底部信息
    paint.color = const Color(0xFF757575);
    final footerStyle = TextStyle(
      fontSize: 24 * scale,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF757575),
      fontFamily: 'Roboto',
      height: 1.5,
    );
    final footerText =
        '导出时间: ${DateFormat('yyyy年MM月dd日 HH:mm:ss').format(DateTime.now())}\n'
        '牙医诊所管理系统';
    final footerPainter = TextPainter(
      text: TextSpan(text: footerText, style: footerStyle),
      textDirection: ui.TextDirection.ltr,
    );
    footerPainter.layout(maxWidth: scaledWidth - 2 * margin);
    footerPainter.paint(canvas, Offset(margin, currentY + 40 * scale));
    
    // 动态调整最终高度
    final finalHeight = currentY + 120 * scale + footerPainter.height;
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(scaledWidth.toInt(), finalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    
    return bytes;
  }

  /// 保存图片到下载目录
  Future<String?> _saveImageToDownloads(Uint8List imageData) async {
    try {
      // 在安卓端，优先使用外部存储的下载目录
      Directory? directory;
      
      try {
        // 尝试获取外部存储的下载目录
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = null;
        }
      } catch (e) {
        // 如果外部存储不可用，忽略错误
      }
      
      if (directory == null) {
        // 如果外部存储不可用，使用应用文档目录
        final appDocDir = await getApplicationDocumentsDirectory();
        directory = Directory('${appDocDir.path}/exports');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
      
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '采购记录_${timestamp}.png';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(imageData);
      return file.path;
    } catch (e) {
      print('保存图片失败: $e');
      return null;
    }
  }

  /// 打开文件所在文件夹
  void _openFileLocation(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        // 在安卓端，可以尝试使用文件管理器打开
        // 这里暂时只显示路径信息
        // 使用公共组件的信息提示
        SuccessToastManager.showInfo(
          context,
          message: '文件路径: $filePath',
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      print('打开文件夹失败: $e');
    }
  }
}

// 导出选项对话框
class _ExportOptionsDialog extends StatefulWidget {
  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  final Map<String, bool> _exportOptions = {
    'purchaseRecord': false,
    'purchaseSummary': false,
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