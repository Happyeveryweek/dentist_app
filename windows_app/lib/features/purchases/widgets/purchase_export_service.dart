import 'package:flutter/material.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../services/purchase_export_service.dart' as core;

/// 兼容旧导入路径，实际实现统一委托到核心导出服务。
class PurchaseExportService {
  static Future<void> showExportDialog(
    BuildContext context,
    PurchaseRecord record,
    List<PurchaseItem> purchaseItems,
  ) =>
      core.PurchaseExportService.showExportDialog(
        context,
        record,
        purchaseItems,
      );

  static Future<void> exportPurchaseRecordAsImage(
    BuildContext context,
    PurchaseRecord record,
    List<PurchaseItem> purchaseItems,
    Map<String, bool> exportOptions,
  ) =>
      core.PurchaseExportService.exportPurchaseRecordAsImage(
        context,
        record,
        purchaseItems,
        exportOptions,
      );
}
