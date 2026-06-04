import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../widgets/success_toast.dart';
import './purchase_export_dialog.dart';

/// 采购记录导出相关的服务类
class PurchaseExportService {
  /// 显示导出内容选择对话框
  static Future<void> showExportDialog(
    BuildContext context,
    PurchaseRecord record,
    List<PurchaseItem> purchaseItems,
  ) async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PurchaseExportDialog(),
    );

    // 如果用户选择了导出选项，则执行导出
    if (result != null) {
      exportPurchaseRecordAsImage(context, record, purchaseItems, result);
    }
  }

  /// 导出采购记录为图片
  static Future<void> exportPurchaseRecordAsImage(
    BuildContext context,
    PurchaseRecord record,
    List<PurchaseItem> purchaseItems,
    Map<String, bool> exportOptions,
  ) async {
    try {
      // 创建图片数据
      final imageData = await generatePurchaseRecordImage(record, purchaseItems, exportOptions);

      // 直接保存到下载目录
      final result = await saveImageToDownloads(imageData);

      if (result != null) {
        // 显示成功提示
        AppToastManager.showSuccess(context, message: '导出成功！图片已保存到下载目录');
      } else {
        // 显示失败提示
        AppToastManager.showError(context, message: '图片保存失败');
      }
    } catch (e) {
      AppToastManager.showError(context, message: '导出失败: $e');
    }
  }

  /// 生成采购记录图片
  static Future<Uint8List> generatePurchaseRecordImage(
    PurchaseRecord record,
    List<PurchaseItem> purchaseItems,
    Map<String, bool> exportOptions,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();

    // 超高分辨率 - 确保最佳清晰度
    const scaleFactor = 3.0; // 3倍分辨率，提供超高DPI
    const width = 1200.0 * scaleFactor; // 3600像素宽度

    // 动态计算高度，避免内容重叠
    double estimatedHeight = 200 * scaleFactor; // 标题区域

    if (exportOptions['purchaseRecord'] == true) {
      estimatedHeight += 200 * scaleFactor; // 基本信息区域
    }

    if (exportOptions['purchaseSummary'] == true) {
      estimatedHeight += 150 * scaleFactor; // 汇总统计区域（显示在总计行下方）
    }

    if (exportOptions['purchaseDetails'] == true) {
      estimatedHeight += 150 * scaleFactor; // 表头区域
      estimatedHeight += purchaseItems.length * 70 * scaleFactor; // 每行项目
      estimatedHeight += exportOptions['purchaseSummary'] == true ? 180 * scaleFactor : 100 * scaleFactor; // 总计行（含汇总时更高）
    }

    estimatedHeight += 150 * scaleFactor; // 底部信息和边距

    final height = estimatedHeight;
    double currentY = 60 * scaleFactor;

    // 白色背景
    paint.color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

    // 标题 - 进一步增大和加粗字体
    paint.color = const Color(0xFF000000);
    final titleStyle = TextStyle(
      fontSize: 48 * scaleFactor, // 增大到144px
      fontWeight: FontWeight.w900, // 使用最粗字体
      color: const Color(0xFF000000),
    );
    final titlePainter = TextPainter(
      text: TextSpan(text: '采购记录详情', style: titleStyle),
      textDirection: ui.TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, currentY));
    currentY += 100 * scaleFactor;

    // 采购记录基本信息
    if (exportOptions['purchaseRecord'] == true) {
      final basicInfoStyle = TextStyle(fontSize: 32 * scaleFactor, fontWeight: FontWeight.w800, color: const Color(0xFF000000));

      // 构建基本信息文本，包含医生字段
      String basicInfoText = '采购记录 #${record.id}\n'
          '采购日期: ${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}\n';

      if (record.supplier != null && record.supplier!.isNotEmpty) {
        basicInfoText += '供应商: ${record.supplier}\n';
      }

      if (record.doctor != null && record.doctor!.isNotEmpty) {
        basicInfoText += '采购医生: ${record.doctor}\n';
      }

      if (record.notes != null && record.notes!.isNotEmpty) {
        basicInfoText += '备注: ${record.notes}\n';
      }

      final basicInfoPainter = TextPainter(
        text: TextSpan(
          text: basicInfoText,
          style: basicInfoStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      );
      basicInfoPainter.layout(maxWidth: width - 150 * scaleFactor);
      basicInfoPainter.paint(canvas, Offset(75 * scaleFactor, currentY));
      currentY += basicInfoPainter.height + 50 * scaleFactor;
    }

    // 采购项目明细
    if (exportOptions['purchaseDetails'] == true) {
      // 表格标题
      final tableTitleStyle = TextStyle(fontSize: 36 * scaleFactor, fontWeight: FontWeight.w900, color: Colors.blue[800]);
      final tableTitlePainter = TextPainter(
        text: TextSpan(text: '采购项目明细', style: tableTitleStyle),
        textDirection: ui.TextDirection.ltr,
      );
      tableTitlePainter.layout();
      tableTitlePainter.paint(canvas, Offset(75 * scaleFactor, currentY));
      currentY += 80 * scaleFactor;

      // 表格头部 - 进一步增大和加粗字体
      final headerStyle = TextStyle(fontSize: 26 * scaleFactor, fontWeight: FontWeight.w900, color: const Color(0xFF000000));
      final headers = ['材料名称', '数量', '单位', '单价', '总价'];
      final columnWidths = [450.0 * scaleFactor, 120.0 * scaleFactor, 120.0 * scaleFactor, 150.0 * scaleFactor, 180.0 * scaleFactor];
      double currentX = 75 * scaleFactor;

      // 绘制表头背景
      final headerBgPaint = ui.Paint()..color = const Color(0xFFE0E0E0); // 加深表头灰色
      canvas.drawRect(
        Rect.fromLTWH(75 * scaleFactor, currentY - 8 * scaleFactor, width - 150 * scaleFactor, 50 * scaleFactor),
        headerBgPaint,
      );

      // 绘制表头文字
      for (int i = 0; i < headers.length; i++) {
        final headerPainter = TextPainter(
          text: TextSpan(text: headers[i], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        headerPainter.layout();
        // 材料名称列左对齐，其他列居中对齐
        if (i == 0) {
          // 材料名称列左对齐
          headerPainter.paint(canvas, Offset(currentX + 12 * scaleFactor, currentY));
        } else {
          // 其他列居中对齐
          headerPainter.paint(canvas, Offset(currentX + (columnWidths[i] - headerPainter.width) / 2, currentY));
        }
        currentX += columnWidths[i];
      }

      // 绘制表头分隔线
      paint.color = const Color(0xFFE0E0E0);
      canvas.drawLine(
        Offset(75 * scaleFactor, currentY + 42 * scaleFactor),
        Offset(width - 75 * scaleFactor, currentY + 42 * scaleFactor),
        paint,
      );

      currentY += 60 * scaleFactor;

      // 表格内容 - 进一步增大和加粗字体
      final contentStyle = TextStyle(fontSize: 24 * scaleFactor, fontWeight: FontWeight.w700, color: const Color(0xFF000000));

      for (var entry in purchaseItems.asMap().entries) {
        final int index = entry.key;
        final PurchaseItem item = entry.value;

        // 交替行背景色 (偶数行加背景色)
        if (index % 2 == 1) {
            paint.color = Colors.grey[100]!;
            canvas.drawRect(Rect.fromLTWH(75 * scaleFactor, currentY - 8 * scaleFactor, width - 150 * scaleFactor, 70 * scaleFactor), paint);
        }

        currentX = 75 * scaleFactor;

        // 材料名称
        final namePainter = TextPainter(
          text: TextSpan(text: item.materialName, style: contentStyle),
          textDirection: ui.TextDirection.ltr,
          maxLines: 2,
        );
        namePainter.layout(maxWidth: columnWidths[0]);
        namePainter.paint(canvas, Offset(currentX + 12 * scaleFactor, currentY));
        currentX += columnWidths[0];

        // 数量
        final quantityPainter = TextPainter(
          text: TextSpan(text: '${item.quantity}', style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        quantityPainter.layout();
        quantityPainter.paint(canvas, Offset(currentX + (columnWidths[1] - quantityPainter.width) / 2, currentY));
        currentX += columnWidths[1];

        // 单位
        final unitPainter = TextPainter(
          text: TextSpan(text: item.formattedUnit, style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitPainter.layout();
        unitPainter.paint(canvas, Offset(currentX + (columnWidths[2] - unitPainter.width) / 2, currentY));
        currentX += columnWidths[2];

        // 单价
        final unitPricePainter = TextPainter(
          text: TextSpan(text: '¥${item.unitPrice.toStringAsFixed(2)}', style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitPricePainter.layout();
        unitPricePainter.paint(canvas, Offset(currentX + (columnWidths[3] - unitPricePainter.width) / 2, currentY));
        currentX += columnWidths[3];

        // 总价
        final totalPricePainter = TextPainter(
          text: TextSpan(text: '¥${item.totalPrice.toStringAsFixed(2)}', style: contentStyle),
          textDirection: ui.TextDirection.ltr,
        );
        totalPricePainter.layout();
        totalPricePainter.paint(canvas, Offset(currentX + (columnWidths[4] - totalPricePainter.width) / 2, currentY));

        currentY += 70 * scaleFactor; // 增加行高避免重叠

        // 添加分隔线
        paint.color = const Color(0xFFE0E0E0);
        canvas.drawLine(
          Offset(75 * scaleFactor, currentY - 10 * scaleFactor),
          Offset(width - 75 * scaleFactor, currentY - 10 * scaleFactor),
          paint,
        );
      }
      // 总计行（含汇总统计）
      final totalAmount = purchaseItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
      final bool showSummary = exportOptions['purchaseSummary'] == true;
      final double totalRowHeight = showSummary ? 140 * scaleFactor : 80 * scaleFactor;

      final totalRect = Rect.fromLTWH(75 * scaleFactor, currentY, width - 150 * scaleFactor, totalRowHeight);
      paint.color = Colors.green[50]!;
      canvas.drawRect(totalRect, paint);

      // "总计" 标签
      final totalLabelPainter = TextPainter(
        text: TextSpan(text: '总计', style: headerStyle),
        textDirection: ui.TextDirection.ltr,
      );
      totalLabelPainter.layout();
      totalLabelPainter.paint(canvas, Offset(90 * scaleFactor, currentY + 20 * scaleFactor));

      // 汇总统计信息（紧跟在总计文字下方，同一背景框内）
      if (showSummary) {
        final statStyle = TextStyle(fontSize: 24 * scaleFactor, fontWeight: FontWeight.w600, color: const Color(0xFF555555));
        final statPainter = TextPainter(
          text: TextSpan(
            text: '总采购数量: ${record.totalQuantity}    采购项目数: ${purchaseItems.length}    采购金额: ¥${record.totalAmount.toStringAsFixed(2)}',
            style: statStyle,
          ),
          textDirection: ui.TextDirection.ltr,
        );
        statPainter.layout(maxWidth: width - 150 * scaleFactor - 30 * scaleFactor);
        statPainter.paint(canvas, Offset(90 * scaleFactor, currentY + 20 * scaleFactor + totalLabelPainter.height + 10 * scaleFactor));
      }

      currentY += totalRowHeight + 20 * scaleFactor;
    }

    // 底部信息
    final footerStyle = TextStyle(fontSize: 20 * scaleFactor, fontWeight: FontWeight.w600, color: const Color(0xFF757575));
    final footerPainter = TextPainter(
      text: TextSpan(
        text: '导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}\n'
            '牙科诊所管理系统',
        style: footerStyle,
      ),
      textDirection: ui.TextDirection.ltr,
    );
    footerPainter.layout(maxWidth: width - 150 * scaleFactor);
    footerPainter.paint(canvas, Offset(75 * scaleFactor, currentY + 30 * scaleFactor));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return bytes;
  }

  /// 保存图片到下载目录 - 使用PNG格式确保最高质量
  static Future<String?> saveImageToDownloads(Uint8List imageData) async {
    try {
      final directory = await getDownloadsDirectory();
      final saveDir = directory ?? await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      // 始终使用PNG格式保持最佳质量
      final fileName = '采购记录_${timestamp}.png';
      final file = File('${saveDir.path}/$fileName');

      await file.writeAsBytes(imageData);
      return file.path;
    } catch (e) {
      print('保存图片失败: $e');
      return null;
    }
  }

  /// 打开文件所在文件夹
  static void openFileLocation(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        // 在Windows上打开文件所在文件夹
        Process.run('explorer', ['/select,', filePath]);
      }
    } catch (e) {
      print('打开文件夹失败: $e');
    }
  }
}
