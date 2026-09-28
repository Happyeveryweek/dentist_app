/// 采购列表标题：采购日期按年月日紧凑显示，后接「采购单」。
/// 例如 2026-08-08 显示为 20260808采购单。
String purchaseListTitle(DateTime purchaseDate) {
  final local = purchaseDate.isUtc ? purchaseDate.toLocal() : purchaseDate;
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year$month$day采购单';
}
