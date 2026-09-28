import 'dart:convert';

import 'package:dentist_app/features/materials/services/material_catalog.dart';
import 'package:dentist_app/models/material.dart';
import 'package:flutter_test/flutter_test.dart';

DentalMaterial _material({
  int? id,
  required String name,
  String? code,
  String type = '其他',
  double price = 0,
  int stock = 1,
  int minStock = 0,
  String? specification,
  String? supplier,
  String? description,
}) {
  return DentalMaterial(
    id: id,
    materialName: name,
    materialCode: code,
    materialType: type,
    specification: specification,
    defaultPrice: price,
    stockQuantity: stock,
    minStock: minStock,
    supplier: supplier,
    description: description,
    createdAt: DateTime(2026, 1, 2),
  );
}

void main() {
  test('材料编码按 Windows 规则取下一个', () {
    expect(
      nextMaterialCode(materialCodes: const ['M010', 'M2'], maxId: 8),
      'M11',
    );
    expect(nextMaterialCode(materialCodes: const ['M304'], maxId: 1), 'M305');
    expect(nextMaterialCode(materialCodes: const ['m9'], maxId: 1), 'M10');
    expect(nextMaterialCode(materialCodes: const ['Mabc'], maxId: 4), 'M1');
    expect(nextMaterialCode(materialCodes: const ['普通编码'], maxId: 4), 'M305');
    expect(nextMaterialCode(materialCodes: const [], maxId: null), 'M301');
  });

  test('筛选覆盖名称、编码、供应商和描述，并按 10 条累加加载', () {
    final materials = [
      _material(
        name: '阿莫西林',
        code: 'M001',
        type: '药品',
        supplier: '华南医药',
        description: '口服抗生素',
        specification: '不会被搜索',
      ),
      _material(name: '碘伏', code: 'M016', type: '消毒用品', supplier: '本地供应商'),
      for (var i = 0; i < 9; i++)
        _material(name: '耗材$i', code: 'C$i', type: '牙科耗材'),
    ];

    final byType = filterMaterials(
      materials: materials,
      selectedType: '药品',
      searchQuery: '',
    );
    expect(byType.total, 1);
    expect(byType.filtered.single.materialName, '阿莫西林');

    expect(
      filterMaterials(
        materials: materials,
        selectedType: '全部',
        searchQuery: 'm001',
      ).filtered.single.materialName,
      '阿莫西林',
    );
    expect(
      filterMaterials(
        materials: materials,
        selectedType: '全部',
        searchQuery: '华南',
      ).filtered.single.materialName,
      '阿莫西林',
    );
    expect(
      filterMaterials(
        materials: materials,
        selectedType: '全部',
        searchQuery: '抗生素',
      ).filtered.single.materialName,
      '阿莫西林',
    );
    expect(
      filterMaterials(
        materials: materials,
        selectedType: '全部',
        searchQuery: '不会被搜索',
      ).total,
      0,
    );

    final paged = filterMaterials(
      materials: materials,
      selectedType: '全部',
      searchQuery: '',
    );
    expect(paged.total, 11);
    expect(paged.currentPage, 1);
    expect(paged.displayed, hasLength(10));
    expect(paged.hasMore, isTrue);

    final second = loadMoreMaterials(paged);
    expect(second.currentPage, 2);
    expect(second.displayed, hasLength(11));
    expect(second.hasMore, isFalse);
    expect(loadMoreMaterials(second).displayed, hasLength(11));

    final kept = filterMaterials(
      materials: materials,
      selectedType: '全部',
      searchQuery: '',
      currentPage: 2,
      resetPage: false,
    );
    expect(kept.currentPage, 2);
    expect(kept.displayed, hasLength(11));

    final clamped = filterMaterials(
      materials: materials,
      selectedType: '药品',
      searchQuery: '',
      currentPage: 2,
      resetPage: false,
    );
    expect(clamped.currentPage, 1);
    expect(clamped.displayed, hasLength(1));
    expect(clamped.hasMore, isFalse);
  });

  test('统计按当前筛选结果计算，数量标题跟随类型', () {
    final materials = [
      _material(name: '甲硝唑', type: '药品', price: 20, supplier: '华南医药'),
      _material(name: '头孢', type: '药品', price: 5, supplier: '华南医药'),
      _material(name: '手套', type: '一次性用品', price: 3, supplier: ''),
      _material(name: '无供应商', type: '其他', price: 1),
    ];
    final filtered = filterMaterials(
      materials: materials,
      selectedType: '药品',
      searchQuery: '',
    );
    final stats = MaterialListStats.fromMaterials(filtered.filtered);

    expect(materialQuantityLabel('药品'), '材料数量-药品');
    expect(stats.count, 2);
    expect(stats.totalValueText, '¥25');
    expect(stats.typeCount, 1);
    expect(stats.supplierCount, 1);

    final allStats = MaterialListStats.fromMaterials(materials);
    expect(allStats.typeCount, 3);
    expect(allStats.supplierCount, 2);
    expect(allStats.totalValueText, '¥29');
  });

  test('乱码描述可还原中文，已是中文或英文时保持原样', () {
    final garbled = String.fromCharCodes(utf8.encode('阿莫西林'));
    expect(fixMaybeDecoded(garbled), '阿莫西林');
    expect(fixMaybeDecoded('阿莫西林'), '阿莫西林');
    expect(fixMaybeDecoded('amoxicillin'), 'amoxicillin');
    expect(fixMaybeDecoded(null), '');
  });

  test('表单草稿只改可见字段，编辑时保留规格和最小库存', () {
    expect(isMaterialNameValid('  '), isFalse);
    expect(parseStockQuantity('x'), 0);
    expect(parseDefaultPrice(''), 0);

    final created = buildMaterialDraft(
      existing: null,
      name: ' 纱布 ',
      code: ' ',
      type: '牙科耗材',
      unit: ' ',
      priceText: '12.5',
      quantityText: '3',
      supplier: ' ',
      description: ' ',
    );
    expect(created.materialName, '纱布');
    expect(created.materialCode, isNull);
    expect(created.unit, '个');
    expect(created.defaultPrice, 12.5);
    expect(created.stockQuantity, 3);
    expect(created.minStock, 0);
    expect(created.specification, isNull);
    expect(created.supplier, isNull);
    expect(created.description, isNull);

    final existing = _material(
      id: 7,
      name: '旧名称',
      code: 'M007',
      type: '药品',
      specification: '0.5g',
      minStock: 4,
      supplier: '原供应商',
      description: '原描述',
    );
    final edited = buildMaterialDraft(
      existing: existing,
      name: '新名称',
      code: '',
      type: '其他',
      unit: '盒',
      priceText: '8',
      quantityText: '2',
      supplier: '',
      description: '新描述',
    );
    expect(edited.id, 7);
    expect(edited.materialName, '新名称');
    expect(edited.materialCode, isNull);
    expect(edited.specification, '0.5g');
    expect(edited.minStock, 4);
    expect(edited.supplier, isNull);
    expect(edited.description, '新描述');
    expect(edited.createdAt, existing.createdAt);
  });
}
