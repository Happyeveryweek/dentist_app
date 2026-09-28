import 'dart:convert';

import '../../../models/material.dart';

/// 与 Windows 材料管理相同的类型。第一项「全部」只用于筛选。
const List<String> materialTypeOptions = [
  '全部',
  '药品',
  '局部麻醉药',
  '消毒用品',
  '一次性用品',
  '牙科材料',
  '牙科器械',
  '根管治疗器械',
  '牙科耗材',
  '正畸材料',
  '口腔护理用品',
  '防护用品',
  '办公用品',
  '其他',
];

/// 与 Windows 材料表单相同的单位。
const List<String> materialUnitOptions = [
  '个',
  '瓶',
  '把',
  '盒',
  '包',
  '支',
  '片',
  '克',
  '毫升',
  '米',
  '厘米',
  '箱',
  '卷',
  '袋',
  '套',
  '件',
  '条',
  '块',
  '粒',
  '颗',
  '根',
  '张',
  '台',
  '架',
  '组',
  '对',
  '双',
  '副',
  '只',
  '枚',
  '筒',
  '罐',
  '桶',
];

const int materialPageSize = 10;

String materialQuantityLabel(String selectedType) => '材料数量-$selectedType';

/// 数据库把 UTF-8 字节当成单字节字符串时，还原描述里的中文。
String fixMaybeDecoded(String? value) {
  if (value == null || value.isEmpty) return value ?? '';
  final cjk = RegExp(r'[\u4e00-\u9fff]');
  if (cjk.hasMatch(value)) return value;
  try {
    final decoded = utf8.decode(value.codeUnits, allowMalformed: true);
    if (cjk.hasMatch(decoded)) return decoded;
  } catch (_) {
    return value;
  }
  return value;
}

int _integerCast(String value) {
  final match = RegExp(r'^[+-]?\d+').firstMatch(value.trim());
  final matched = match?.group(0);
  if (matched == null) return 0;
  return int.tryParse(matched) ?? 0;
}

/// 与 Windows 材料编码规则一致。
///
/// 在 M 开头的编码里，按后缀的整数转换值取最大的一条，再用整段后缀加 1。
/// 没有这类编码时，用最大 id 加 301；材料表为空时返回 M301。
String nextMaterialCode({
  required Iterable<String?> materialCodes,
  int? maxId,
}) {
  String? bestCode;
  var bestCast = -1;
  for (final raw in materialCodes) {
    if (raw == null || raw.isEmpty) continue;
    if (!raw.toUpperCase().startsWith('M')) continue;
    final cast = _integerCast(raw.substring(1));
    if (bestCode == null || cast > bestCast) {
      bestCode = raw;
      bestCast = cast;
    }
  }
  if (bestCode != null) {
    final number = int.tryParse(bestCode.substring(1)) ?? 0;
    return 'M${number + 1}';
  }
  if (maxId != null) {
    return 'M${maxId + 301}';
  }
  return 'M301';
}

String? normalizeOptionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int parseStockQuantity(String value) => int.tryParse(value.trim()) ?? 0;

double parseDefaultPrice(String value) => double.tryParse(value.trim()) ?? 0.0;

bool isMaterialNameValid(String name) => name.trim().isNotEmpty;

/// 表单只改 Windows 材料表单上的字段。编辑时保留规格和最小库存。
DentalMaterial buildMaterialDraft({
  required DentalMaterial? existing,
  required String name,
  required String code,
  required String type,
  required String unit,
  required String priceText,
  required String quantityText,
  required String supplier,
  required String description,
}) {
  final materialName = name.trim();
  final materialCode = normalizeOptionalText(code);
  final supplierValue = normalizeOptionalText(supplier);
  final descriptionValue = normalizeOptionalText(description);
  final unitValue = unit.trim().isEmpty ? '个' : unit.trim();
  final price = parseDefaultPrice(priceText);
  final quantity = parseStockQuantity(quantityText);
  if (existing == null) {
    return DentalMaterial(
      materialName: materialName,
      materialCode: materialCode,
      materialType: type,
      unit: unitValue,
      defaultPrice: price,
      stockQuantity: quantity,
      minStock: 0,
      supplier: supplierValue,
      description: descriptionValue,
    );
  }
  return DentalMaterial(
    id: existing.id,
    materialName: materialName,
    materialCode: materialCode,
    materialType: type,
    specification: existing.specification,
    unit: unitValue,
    defaultPrice: price,
    stockQuantity: quantity,
    minStock: existing.minStock,
    supplier: supplierValue,
    description: descriptionValue,
    createdAt: existing.createdAt,
  );
}

class MaterialListStats {
  const MaterialListStats({
    required this.count,
    required this.totalValue,
    required this.typeCount,
    required this.supplierCount,
  });

  final int count;
  final double totalValue;
  final int typeCount;
  final int supplierCount;

  factory MaterialListStats.fromMaterials(List<DentalMaterial> materials) {
    return MaterialListStats(
      count: materials.length,
      totalValue: materials.fold<double>(
        0.0,
        (sum, material) => sum + material.defaultPrice,
      ),
      typeCount:
          materials.map((material) => material.materialType).toSet().length,
      supplierCount:
          materials
              .map((material) => material.supplier)
              .where((supplier) => supplier != null)
              .toSet()
              .length,
    );
  }

  String get totalValueText => '¥${totalValue.toStringAsFixed(0)}';
}

class MaterialListQuery {
  const MaterialListQuery({
    required this.filtered,
    required this.displayed,
    required this.total,
    required this.currentPage,
    required this.hasMore,
  });

  final List<DentalMaterial> filtered;
  final List<DentalMaterial> displayed;
  final int total;
  final int currentPage;
  final bool hasMore;
}

MaterialListQuery filterMaterials({
  required List<DentalMaterial> materials,
  required String selectedType,
  required String searchQuery,
  int currentPage = 1,
  bool resetPage = true,
}) {
  final query = searchQuery.toLowerCase();
  final filtered =
      materials.where((material) {
        final typeMatch =
            selectedType == '全部' || material.materialType == selectedType;
        if (!typeMatch) return false;
        if (query.isEmpty) return true;
        final name = material.materialName.toLowerCase();
        final code = material.materialCode?.toLowerCase() ?? '';
        final supplier = material.supplier?.toLowerCase() ?? '';
        final description = material.description?.toLowerCase() ?? '';
        return name.contains(query) ||
            code.contains(query) ||
            supplier.contains(query) ||
            description.contains(query);
      }).toList();

  final total = filtered.length;
  final maxPage = total == 0 ? 1 : (total / materialPageSize).ceil();
  var page = resetPage ? 1 : currentPage;
  if (page > maxPage) {
    page = maxPage;
  } else if (page < 1) {
    page = 1;
  }

  return _queryForPage(filtered, page);
}

MaterialListQuery loadMoreMaterials(MaterialListQuery current) {
  if (!current.hasMore) return current;
  return _queryForPage(current.filtered, current.currentPage + 1);
}

MaterialListQuery _queryForPage(List<DentalMaterial> filtered, int page) {
  final displayed = _prefix(filtered, page);
  return MaterialListQuery(
    filtered: filtered,
    displayed: displayed,
    total: filtered.length,
    currentPage: page,
    hasMore: displayed.length < filtered.length,
  );
}

List<DentalMaterial> _prefix(List<DentalMaterial> materials, int page) {
  if (materials.isEmpty) return const [];
  final end = page * materialPageSize;
  if (end >= materials.length) return materials;
  return materials.sublist(0, end);
}
