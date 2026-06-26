import 'package:sqflite/sqflite.dart';
import '../models/material.dart' as material_models;
import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';
import 'material_data_source.dart';

/// SQLite 材料数据源实现
class SqliteMaterialDataSource implements MaterialDataSource {
  final Database _database;

  SqliteMaterialDataSource(this._database);

  @override
  Future<List<material_models.MaterialInfo>> getAllMaterials() async {
    final result = await _database.query(
      'materials',
      orderBy: 'updated_at DESC',
    );
    return result.map((e) => material_models.MaterialInfo.fromMap(e)).toList();
  }

  @override
  Future<material_models.MaterialInfo?> getMaterialById(int id) async {
    final result = await _database.query(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return material_models.MaterialInfo.fromMap(result.first);
  }

  @override
  Future<material_models.MaterialInfo?> getMaterialByCode(String code) async {
    final result = await _database.query(
      'materials',
      where: 'material_code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return material_models.MaterialInfo.fromMap(result.first);
  }

  @override
  Future<int> createMaterial(material_models.MaterialInfo material) async {
    return await _database.insert('materials', {
      'material_name': material.materialName,
      'material_code': material.materialCode,
      'material_type': material.materialType,
      'description': material.description ?? '',
      'unit': material.unit,
      'default_price': material.defaultPrice,
      'stock_quantity': material.stockQuantity,
      'min_stock': 0,
      'supplier': material.supplier ?? '',
      'created_at': DateTimeFormatter.nowDbString(),
      'updated_at': DateTimeFormatter.nowDbString(),
    });
  }

  @override
  Future<bool> updateMaterial(material_models.MaterialInfo material) async {
    final count = await _database.update(
      'materials',
      {
        'material_name': material.materialName,
        'material_code': material.materialCode,
        'material_type': material.materialType,
        'unit': material.unit,
        'default_price': material.defaultPrice,
        'stock_quantity': material.stockQuantity,
        'supplier': material.supplier ?? '',
        'description': material.description ?? '',
        'updated_at': DateTimeFormatter.nowDbString(),
      },
      where: 'id = ?',
      whereArgs: [material.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteMaterial(int id) async {
    final count = await _database.delete(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<List<material_models.MaterialInfo>> searchMaterials(
      String query) async {
    final result = await _database.query(
      'materials',
      where:
          'material_name LIKE ? OR material_code LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'material_name ASC',
    );
    return result.map((e) => material_models.MaterialInfo.fromMap(e)).toList();
  }

  @override
  Future<List<material_models.MaterialInfo>> getMaterialsByCategory(
      String category) async {
    final result = await _database.query(
      'materials',
      where: 'material_type = ?',
      whereArgs: [category],
      orderBy: 'material_name ASC',
    );
    return result.map((e) => material_models.MaterialInfo.fromMap(e)).toList();
  }

  @override
  Future<int> getMaterialsCount({String? searchQuery}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause =
          ' WHERE material_name LIKE ? OR material_code LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?';
      whereArgs = [
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%'
      ];
    }

    final result = await _database.rawQuery(
        'SELECT COUNT(*) FROM materials$whereClause', whereArgs);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<material_models.MaterialInfo>> getPaginatedMaterials({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
    String? category,
  }) async {
    final offset = (page - 1) * pageSize;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    List<String> conditions = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add(
          '(material_name LIKE ? OR material_code LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?)');
      whereArgs.addAll([
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%'
      ]);
    }

    if (category != null && category.trim().isNotEmpty) {
      conditions.add('material_type = ?');
      whereArgs.add(category);
    }

    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }

    final sql =
        'SELECT * FROM materials$whereClause ORDER BY $sortBy $sortOrder LIMIT $pageSize OFFSET $offset';
    final result = await _database.rawQuery(sql, whereArgs);
    return result.map((e) => material_models.MaterialInfo.fromMap(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    final totalResult =
        await _database.rawQuery('SELECT COUNT(*) as total FROM materials');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    final typeResult = await _database.rawQuery('''
      SELECT material_type, COUNT(*) as count 
      FROM materials 
      GROUP BY material_type
    ''');

    final typeStats = <String, int>{};
    for (final row in typeResult) {
      typeStats[row['material_type'] as String] = row['count'] as int;
    }

    return {
      'totalMaterials': total,
      'typeStatistics': typeStats,
      'lowStockCount': 0, // 默认值
      'totalValue': 0.0, // 默认值
    };
  }

  @override
  Future<String> getNextMaterialCode() async {
    try {
      final result = await _database.rawQuery(
          'SELECT material_code FROM materials WHERE material_code LIKE "M%" ORDER BY CAST(SUBSTR(material_code, 2) AS INTEGER) DESC LIMIT 1');
      if (result.isNotEmpty) {
        final lastCode = result.first['material_code'] as String;
        final numberStr = lastCode.substring(1);
        final number = int.tryParse(numberStr) ?? 0;
        return 'M${number + 1}';
      }

      final idResult =
          await _database.rawQuery('SELECT MAX(id) as max_id FROM materials');
      if (idResult.isNotEmpty && idResult.first['max_id'] != null) {
        final maxId = idResult.first['max_id'] as int;
        return 'M${maxId + 301}';
      }

      return 'M301';
    } catch (e) {
      LogManager.e('SqliteMaterialDataSource', '获取下一个材料编码失败', error: e);
      return 'M301';
    }
  }

  @override
  Future<bool> clearAllMaterials() async {
    try {
      final count = await _database.delete('materials');
      return count > 0;
    } catch (e) {
      LogManager.e('SqliteMaterialDataSource', '清空所有材料失败', error: e);
      return false;
    }
  }
}
