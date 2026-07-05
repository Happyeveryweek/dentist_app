import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../utils/app_logger.dart';

/// 采购记录导出服务
/// 负责将采购记录导出为图片
class PurchaseExportService {
  /// 生成采购记录图片
  Future<Uint8List> generatePurchaseRecordImage(
    PurchaseRecord record,
    List<PurchaseItem> purchaseItems,
    Map<String, bool> exportOptions,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();

    // 优化安卓端图片尺寸 - 更高的DPI和更适合手机屏幕的比例
    const double baseWidth = 1080.0; // 增加宽度以提高清晰度

    // 设置高DPI以获得更清晰的图像
    const double scale = 3.0; // 3x DPI for high resolution

    const double scaledWidth = baseWidth * scale;
    final estimatedHeight = _estimateCanvasHeight(
      purchaseItems: purchaseItems,
      exportOptions: exportOptions,
      scale: scale,
    );

    // 先按内容估算高度铺满白底，避免导出长图底部出现黑边
    paint.color = const Color(0xFFFFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, scaledWidth, estimatedHeight),
      paint,
    );

    // 边距和间距设置
    const double margin = 60.0 * scale;
    const double sectionSpacing = 40.0 * scale;
    double currentY = margin;

    // 标题 - 加粗加大
    paint.color = const Color(0xFF000000);
    const titleStyle = TextStyle(
      fontSize: 48 * scale, // 增大字体
      fontWeight: FontWeight.w900, // 更粗的字体
      color: Color(0xFF000000),
      fontFamily: 'Roboto', // 使用安卓标准字体
    );
    final titlePainter = TextPainter(
      text: const TextSpan(text: '采购记录详情', style: titleStyle),
      textDirection: ui.TextDirection.ltr,
    );
    titlePainter.layout(maxWidth: scaledWidth - 2 * margin);
    titlePainter.paint(
      canvas,
      Offset((scaledWidth - titlePainter.width) / 2, currentY),
    );
    currentY += titlePainter.height + sectionSpacing;

    // 采购记录基本信息
    if (exportOptions['purchaseRecord'] == true) {
      // 区域背景 - 轻微的灰色背景
      paint.color = const Color(0xFFF8F9FA);
      const recordInfoHeight = 380.0 * scale; // 预估高度，增加医生字段后需要更多空间
      canvas.drawRect(
        Rect.fromLTWH(
          margin,
          currentY,
          scaledWidth - 2 * margin,
          recordInfoHeight,
        ),
        paint,
      );

      // 标题
      paint.color = const Color(0xFF1976D2);
      const sectionTitleStyle = TextStyle(
        fontSize: 36 * scale,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1976D2),
        fontFamily: 'Roboto',
      );
      final sectionTitlePainter = TextPainter(
        text: const TextSpan(text: '基本信息', style: sectionTitleStyle),
        textDirection: ui.TextDirection.ltr,
      );
      sectionTitlePainter.layout();
      sectionTitlePainter.paint(
        canvas,
        Offset(margin + 20 * scale, currentY + 20 * scale),
      );

      // 详细信息 - 加粗字体
      paint.color = const Color(0xFF212121);
      const basicInfoStyle = TextStyle(
        fontSize: 32 * scale, // 增大字体
        fontWeight: FontWeight.w600, // 加粗
        color: Color(0xFF212121),
        fontFamily: 'Roboto',
        height: 1.5, // 增加行高
      );
      final supplier = record.supplier;
      final doctor = record.doctor;
      final notes = record.notes;
      final basicInfoText =
          '记录ID: #${record.id}\n'
          '采购日期: ${DateFormat('yyyy年MM月dd日').format(record.purchaseDate)}\n'
          '${supplier != null && supplier.isNotEmpty ? '供应商: ${record.supplier}\n' : ''}'
          '${doctor != null && doctor.isNotEmpty ? '采购医生: ${record.doctor}\n' : ''}'
          '${notes != null && notes.isNotEmpty ? '备注: ${record.notes}\n' : ''}'
          '创建时间: ${DateFormat('yyyy年MM月dd日 HH:mm').format(record.createdAt)}\n'
          '${record.updatedAt != record.createdAt ? '更新时间: ${DateFormat('yyyy年MM月dd日 HH:mm').format(record.updatedAt)}' : ''}';

      final basicInfoPainter = TextPainter(
        text: TextSpan(text: basicInfoText, style: basicInfoStyle),
        textDirection: ui.TextDirection.ltr,
      );
      basicInfoPainter.layout(maxWidth: scaledWidth - 2 * margin - 40 * scale);
      basicInfoPainter.paint(
        canvas,
        Offset(margin + 20 * scale, currentY + 80 * scale),
      );
      currentY += recordInfoHeight + sectionSpacing;
    }

    // 采购项目明细
    if (exportOptions['purchaseDetails'] == true) {
      // 表格标题
      paint.color = const Color(0xFF1976D2);
      const tableTitleStyle = TextStyle(
        fontSize: 40 * scale,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1976D2),
        fontFamily: 'Roboto',
      );
      final tableTitlePainter = TextPainter(
        text: const TextSpan(text: '采购项目明细', style: tableTitleStyle),
        textDirection: ui.TextDirection.ltr,
      );
      tableTitlePainter.layout();
      tableTitlePainter.paint(canvas, Offset(margin, currentY));
      currentY += tableTitlePainter.height + 30 * scale;

      if (purchaseItems.isEmpty) {
        // 空状态提示
        paint.color = const Color(0xFF757575);
        const emptyStyle = TextStyle(
          fontSize: 32 * scale,
          fontWeight: FontWeight.w500,
          color: Color(0xFF757575),
          fontFamily: 'Roboto',
        );
        final emptyPainter = TextPainter(
          text: const TextSpan(text: '暂无采购项目', style: emptyStyle),
          textDirection: ui.TextDirection.ltr,
        );
        emptyPainter.layout();
        emptyPainter.paint(
          canvas,
          Offset((scaledWidth - emptyPainter.width) / 2, currentY),
        );
        currentY += emptyPainter.height + sectionSpacing;
      } else {
        // 表格头部 - 灰色背景
        const double tableHeaderHeight = 80.0 * scale;
        paint.color = const Color(0xFFE0E0E0); // 灰色背景
        canvas.drawRect(
          Rect.fromLTWH(
            margin,
            currentY,
            scaledWidth - 2 * margin,
            tableHeaderHeight,
          ),
          paint,
        );

        // 表头文字 - 加粗，左对齐
        paint.color = const Color(0xFF212121);
        const headerStyle = TextStyle(
          fontSize: 32 * scale,
          fontWeight: FontWeight.bold,
          color: Color(0xFF212121),
          fontFamily: 'Roboto',
        );

        // 表格列设置 - 适配手机屏幕
        final columnWidths =
            [
              380.0,
              120.0,
              120.0,
              150.0,
              180.0,
            ].map((e) => e * scale).toList(); // 调整列宽并缩放
        final headers = ['材料名称', '数量', '单位', '单价', '总价'];
        double currentX = margin + 20 * scale; // 统起点始位置，左对齐

        // 材料名称 - 左对齐
        final nameHeaderPainter = TextPainter(
          text: TextSpan(text: headers[0], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        nameHeaderPainter.layout();
        nameHeaderPainter.paint(
          canvas,
          Offset(
            currentX + 10 * scale,
            currentY + (tableHeaderHeight - nameHeaderPainter.height) / 2,
          ),
        );
        currentX += columnWidths[0];

        // 数量 - 居中对齐
        final quantityHeaderPainter = TextPainter(
          text: TextSpan(text: headers[1], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        quantityHeaderPainter.layout();
        quantityHeaderPainter.paint(
          canvas,
          Offset(
            currentX + (columnWidths[1] - quantityHeaderPainter.width) / 2,
            currentY + (tableHeaderHeight - quantityHeaderPainter.height) / 2,
          ),
        );
        currentX += columnWidths[1];

        // 单位 - 居中对齐
        final unitHeaderPainter = TextPainter(
          text: TextSpan(text: headers[2], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitHeaderPainter.layout();
        unitHeaderPainter.paint(
          canvas,
          Offset(
            currentX + (columnWidths[2] - unitHeaderPainter.width) / 2,
            currentY + (tableHeaderHeight - unitHeaderPainter.height) / 2,
          ),
        );
        currentX += columnWidths[2];

        // 单价 - 居中对齐
        final unitPriceHeaderPainter = TextPainter(
          text: TextSpan(text: headers[3], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        unitPriceHeaderPainter.layout();
        unitPriceHeaderPainter.paint(
          canvas,
          Offset(
            currentX + (columnWidths[3] - unitPriceHeaderPainter.width) / 2,
            currentY + (tableHeaderHeight - unitPriceHeaderPainter.height) / 2,
          ),
        );
        currentX += columnWidths[3];

        // 总价 - 居中对齐
        final totalPriceHeaderPainter = TextPainter(
          text: TextSpan(text: headers[4], style: headerStyle),
          textDirection: ui.TextDirection.ltr,
        );
        totalPriceHeaderPainter.layout();
        totalPriceHeaderPainter.paint(
          canvas,
          Offset(
            currentX + (columnWidths[4] - totalPriceHeaderPainter.width) / 2,
            currentY + (tableHeaderHeight - totalPriceHeaderPainter.height) / 2,
          ),
        );
        currentY += tableHeaderHeight;

        // 表格内容
        const double rowHeight = 100.0 * scale;
        const contentStyle = TextStyle(
          fontSize: 28 * scale,
          fontWeight: FontWeight.w500,
          color: Color(0xFF212121),
          fontFamily: 'Roboto',
        );

        for (final item in purchaseItems) {
          // 交替背景色
          paint.color =
              purchaseItems.indexOf(item) % 2 == 0
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFFF5F5F5);
          canvas.drawRect(
            Rect.fromLTWH(
              margin,
              currentY,
              scaledWidth - 2 * margin,
              rowHeight,
            ),
            paint,
          );

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
          namePainter.paint(
            canvas,
            Offset(currentX + 10 * scale, currentY + 15 * scale),
          ); // 左对齐，顶部留边距
          currentX += columnWidths[0];

          // 数量 - 居中对齐
          final quantityText = '${item.quantity}';
          final quantityPainter = TextPainter(
            text: TextSpan(text: quantityText, style: contentStyle),
            textDirection: ui.TextDirection.ltr,
          );
          quantityPainter.layout();
          quantityPainter.paint(
            canvas,
            Offset(
              currentX + (columnWidths[1] - quantityPainter.width) / 2,
              currentY + (rowHeight - quantityPainter.height) / 2,
            ),
          );
          currentX += columnWidths[1];

          // 单位 - 居中对齐
          final unitText = item.unit ?? '个';
          final unitPainter = TextPainter(
            text: TextSpan(text: unitText, style: contentStyle),
            textDirection: ui.TextDirection.ltr,
          );
          unitPainter.layout();
          unitPainter.paint(
            canvas,
            Offset(
              currentX + (columnWidths[2] - unitPainter.width) / 2,
              currentY + (rowHeight - unitPainter.height) / 2,
            ),
          );
          currentX += columnWidths[2];

          // 单价 - 居中对齐
          final unitPriceText = '¥${item.unitPrice.toStringAsFixed(2)}';
          final unitPricePainter = TextPainter(
            text: TextSpan(text: unitPriceText, style: contentStyle),
            textDirection: ui.TextDirection.ltr,
          );
          unitPricePainter.layout();
          unitPricePainter.paint(
            canvas,
            Offset(
              currentX + (columnWidths[3] - unitPricePainter.width) / 2,
              currentY + (rowHeight - unitPricePainter.height) / 2,
            ),
          );
          currentX += columnWidths[3];

          // 总价 - 居中对齐，加粗显示
          final totalPriceText = '¥${item.totalPrice.toStringAsFixed(2)}';
          const totalPriceStyle = TextStyle(
            fontSize: 28 * scale,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
            fontFamily: 'Roboto',
          );
          final totalPricePainter = TextPainter(
            text: TextSpan(text: totalPriceText, style: totalPriceStyle),
            textDirection: ui.TextDirection.ltr,
          );
          totalPricePainter.layout();
          totalPricePainter.paint(
            canvas,
            Offset(
              currentX + (columnWidths[4] - totalPricePainter.width) / 2,
              currentY + (rowHeight - totalPricePainter.height) / 2,
            ),
          );

          currentY += rowHeight;
        }

        // 总计行（含汇总统计）
        final bool showSummary = exportOptions['purchaseSummary'] == true;
        final double totalRowHeight =
            showSummary ? (rowHeight * 1.8) : rowHeight;

        paint.color = const Color(0xFFE8F5E8);
        canvas.drawRect(
          Rect.fromLTWH(
            margin,
            currentY,
            scaledWidth - 2 * margin,
            totalRowHeight,
          ),
          paint,
        );

        // "总计" 标签
        const totalStyle = TextStyle(
          fontSize: 36 * scale,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
          fontFamily: 'Roboto',
        );
        final totalLabelPainter = TextPainter(
          text: const TextSpan(text: '总计', style: totalStyle),
          textDirection: ui.TextDirection.ltr,
        );
        totalLabelPainter.layout();
        totalLabelPainter.paint(
          canvas,
          Offset(margin + 20 * scale, currentY + 18 * scale),
        );

        // 汇总统计信息（紧跟在总计文字下方，同一背景框内）
        if (showSummary) {
          const statStyle = TextStyle(
            fontSize: 26 * scale,
            fontWeight: FontWeight.w500,
            color: Color(0xFF555555),
            fontFamily: 'Roboto',
          );
          final statText =
              '总采购数量: ${record.totalQuantity} 件    '
              '采购项目数: ${purchaseItems.length} 项    '
              '采购金额: ¥${NumberFormat('#,##0.00').format(record.totalAmount)}';
          final statPainter = TextPainter(
            text: TextSpan(text: statText, style: statStyle),
            textDirection: ui.TextDirection.ltr,
          );
          statPainter.layout(maxWidth: scaledWidth - 2 * margin - 40 * scale);
          statPainter.paint(
            canvas,
            Offset(
              margin + 20 * scale,
              currentY + 18 * scale + totalLabelPainter.height + 10 * scale,
            ),
          );
        }

        currentY += totalRowHeight + sectionSpacing;
      }
    }

    // 底部信息
    paint.color = const Color(0xFF757575);
    const footerStyle = TextStyle(
      fontSize: 24 * scale,
      fontWeight: FontWeight.w500,
      color: Color(0xFF757575),
      fontFamily: 'Roboto',
      height: 1.5,
    );
    final footerText =
        '导出时间: ${DateFormat('yyyy年MM月dd日 HH:mm:ss').format(DateTime.now())}\n'
        '牙科诊所管理系统';
    final footerPainter = TextPainter(
      text: TextSpan(text: footerText, style: footerStyle),
      textDirection: ui.TextDirection.ltr,
    );
    footerPainter.layout(maxWidth: scaledWidth - 2 * margin);
    footerPainter.paint(canvas, Offset(margin, currentY + 40 * scale));

    // 动态调整最终高度
    final finalHeight = currentY + 120 * scale + footerPainter.height;

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      scaledWidth.toInt(),
      finalHeight.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('导出图片数据失败');
    }
    final bytes = byteData.buffer.asUint8List();

    return bytes;
  }

  double _estimateCanvasHeight({
    required List<PurchaseItem> purchaseItems,
    required Map<String, bool> exportOptions,
    required double scale,
  }) {
    double height = 900 * scale;

    if (exportOptions['purchaseRecord'] == true) {
      height += 420 * scale;
    }

    if (exportOptions['purchaseDetails'] == true) {
      height += 180 * scale;
      if (purchaseItems.isEmpty) {
        height += 160 * scale;
      } else {
        height += 80 * scale;
        height += purchaseItems.length * 100 * scale;
        height += (exportOptions['purchaseSummary'] == true ? 180 : 100) * scale;
      }
    }

    return height + 260 * scale;
  }

  /// 保存图片到下载目录
  Future<String?> saveImageToDownloads(Uint8List imageData) async {
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
      final fileName = '采购记录_$timestamp.png';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(imageData);
      return file.path;
    } catch (e) {
      AppLogger.info('保存图片失败: $e');
      return null;
    }
  }
}
