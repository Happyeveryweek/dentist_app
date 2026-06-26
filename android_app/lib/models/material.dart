import '../utils/datetime_formatter.dart';
import '../utils/map_parser.dart';

// 材料信息模型
class DentalMaterial {
  final int? id;
  final String materialName;
  final String? materialCode;
  final String materialType; // 新增：材料类型
  final String? specification; // 新增：规格说明
  final String unit;
  final double defaultPrice;
  final int stockQuantity; // 新增：库存数量
  final int minStock; // 新增：最小库存
  final String? supplier;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  DentalMaterial({
    this.id,
    required this.materialName,
    this.materialCode,
    this.materialType = '其他',
    this.specification,
    this.unit = '个',
    this.defaultPrice = 0.0,
    this.stockQuantity = 0,
    this.minStock = 0,
    this.supplier,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // 从Map构造DentalMaterial对象
  factory DentalMaterial.fromMap(
    Map<String, dynamic> map, {
    String dataSource = 'sqlite',
  }) {
    final p = MapParser(map, context: 'DentalMaterial');
    return DentalMaterial(
      id: p.optional('id', (v) => v as int),
      materialName: p.string('material_name'),
      materialCode: p.stringOptional('material_code'),
      materialType: p.string('material_type', defaultValue: '其他'),
      specification: p.stringOptional('specification'),
      unit: p.string('unit', defaultValue: '个'),
      defaultPrice: p.doubleValue('default_price'),
      stockQuantity: p.integer('stock_quantity'),
      minStock: p.integer('min_stock'),
      supplier: p.stringOptional('supplier'),
      description: p.stringOptional('description'),
      createdAt: p.dateTime('created_at'),
      updatedAt: p.dateTime('updated_at'),
    );
  }

  // 将Material对象转换为Map
  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        'id': id,
        'material_name': materialName,
        'material_code': materialCode,
        'material_type': materialType,
        'specification': specification,
        'unit': unit,
        'default_price': defaultPrice,
        'stock_quantity': stockQuantity,
        'min_stock': minStock,
        'supplier': supplier,
        'description': description,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    } else {
      // SQLite数据源
      return {
        'id': id,
        'material_name': materialName,
        'material_code': materialCode,
        'material_type': materialType,
        'specification': specification,
        'unit': unit,
        'default_price': defaultPrice,
        'stock_quantity': stockQuantity,
        'min_stock': minStock,
        'supplier': supplier,
        'description': description,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    }
  }

  // 创建副本
  DentalMaterial copyWith({
    int? id,
    String? materialName,
    String? materialCode,
    String? materialType,
    String? specification,
    String? unit,
    double? defaultPrice,
    int? stockQuantity,
    int? minStock,
    String? supplier,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DentalMaterial(
      id: id ?? this.id,
      materialName: materialName ?? this.materialName,
      materialCode: materialCode ?? this.materialCode,
      materialType: materialType ?? this.materialType,
      specification: specification ?? this.specification,
      unit: unit ?? this.unit,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStock: minStock ?? this.minStock,
      supplier: supplier ?? this.supplier,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'DentalMaterial(id: $id, materialName: $materialName, materialType: $materialType, unit: $unit, defaultPrice: $defaultPrice, stockQuantity: $stockQuantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DentalMaterial && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
