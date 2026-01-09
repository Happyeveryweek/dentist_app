import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/material.dart' as material_models;
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'base_mysql_data_source.dart';

// 抽象材料数据源接口
abstract class MaterialDataSource {
  Future<List<material_models.MaterialInfo>> getAllMaterials();
  Future<material_models.MaterialInfo?> getMaterialById(int id);
  Future<material_models.MaterialInfo?> getMaterialByCode(String code);
  Future<int> createMaterial(material_models.MaterialInfo material);
  Future<bool> updateMaterial(material_models.MaterialInfo material);
  Future<bool> deleteMaterial(int id);
  
  // 搜索和分类方法
  Future<List<material_models.MaterialInfo>> searchMaterials(String query);
  Future<List<material_models.MaterialInfo>> getMaterialsByCategory(String category);
  
  // 分页查询方法
  Future<int> getMaterialsCount({String? searchQuery});
  Future<List<material_models.MaterialInfo>> getPaginatedMaterials({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
    String? category,
  });
  
  // 统计方法
  Future<Map<String, dynamic>> getMaterialStatistics();
  
  // 材料编码相关
  Future<String> getNextMaterialCode();
  
  // 批量操作
  Future<bool> clearAllMaterials();
}

// SQLite材料数据源实现
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
      'stock_quantity': 0,
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
  Future<List<material_models.MaterialInfo>> searchMaterials(String query) async {
    final result = await _database.query(
      'materials',
      where: 'material_name LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'material_name ASC',
    );
    return result.map((e) => material_models.MaterialInfo.fromMap(e)).toList();
  }

  @override
  Future<List<material_models.MaterialInfo>> getMaterialsByCategory(String category) async {
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
      whereClause = ' WHERE material_name LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%', '%$searchQuery%'];
    }
    
    final result = await _database.rawQuery('SELECT COUNT(*) FROM materials$whereClause', whereArgs);
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
      conditions.add('(material_name LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    
    if (category != null && category.trim().isNotEmpty) {
      conditions.add('material_type = ?');
      whereArgs.add(category);
    }
    
    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }
    
    final sql = 'SELECT * FROM materials$whereClause ORDER BY $sortBy $sortOrder LIMIT $pageSize OFFSET $offset';
    final result = await _database.rawQuery(sql, whereArgs);
    return result.map((e) => material_models.MaterialInfo.fromMap(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    final totalResult = await _database.rawQuery('SELECT COUNT(*) as total FROM materials');
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
      'lowStockCount': 0, // 默认值，MaterialInfo中没有库存字段
      'totalValue': 0.0,  // 默认值
    };
  }

  @override
  Future<String> getNextMaterialCode() async {
    try {
      // 首先尝试从material_code字段获取
      final result = await _database.rawQuery(
        'SELECT material_code FROM materials WHERE material_code LIKE "M%" ORDER BY CAST(SUBSTR(material_code, 2) AS INTEGER) DESC LIMIT 1'
      );
      if (result.isNotEmpty) {
        final lastCode = result.first['material_code'] as String;
        final numberStr = lastCode.substring(1);
        final number = int.tryParse(numberStr) ?? 0;
        return 'M${number + 1}';
      }
      
      // 如果没有material_code，尝试使用id
      final idResult = await _database.rawQuery('SELECT MAX(id) as max_id FROM materials');
      if (idResult.isNotEmpty && idResult.first['max_id'] != null) {
        final maxId = idResult.first['max_id'] as int;
        return 'M${maxId + 301}'; // 从M301开始
      }
      
      return 'M301'; // 默认起始编码
    } catch (e) {
      print('SQLite获取下一个材料编码失败: $e');
      return 'M301';
    }
  }

  @override
  Future<bool> clearAllMaterials() async {
    try {
      final count = await _database.delete('materials');
      return count > 0;
    } catch (e) {
      print('SQLite清空所有材料失败: $e');
      return false;
    }
  }
}

// MySQL材料数据源实现
class MySqlMaterialDataSource extends BaseMySqlDataSource implements MaterialDataSource {
  MySqlMaterialDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );

  @override
  Future<List<material_models.MaterialInfo>> getAllMaterials() async {
    final result = await executeQuery(
      'SELECT * FROM materials ORDER BY updated_at DESC'
    );
    
    final materials = <material_models.MaterialInfo>[];
    for (final row in result) {
      final materialMap = convertRowToMap(row);
      materials.add(material_models.MaterialInfo.fromMap(materialMap));
    }
    return materials;
  }

  @override
  Future<material_models.MaterialInfo?> getMaterialById(int id) async {
    final result = await executeQuery(
      'SELECT * FROM materials WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    
    final materialMap = convertRowToMap(result.first);
    return material_models.MaterialInfo.fromMap(materialMap);
  }

  @override
  Future<material_models.MaterialInfo?> getMaterialByCode(String code) async {
    final result = await executeQuery(
      'SELECT * FROM materials WHERE material_code = ?',
      [code],
    );
    if (result.isEmpty) return null;
    
    final materialMap = convertRowToMap(result.first);
    return material_models.MaterialInfo.fromMap(materialMap);
  }

  @override
  Future<int> createMaterial(material_models.MaterialInfo material) async {
    final result = await executeQuery('''
      INSERT INTO materials (material_name, material_code, material_type, description, unit, default_price, stock_quantity, min_stock, supplier, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''', [
      material.materialName,
      material.materialCode,
      material.materialType,
      material.description ?? '',
      material.unit,
      material.defaultPrice,
      0, // 默认库存为0
      0, // 默认最小库存为0
      material.supplier ?? '',
    ]);
    
    return result.insertId ?? 0;
  }

  @override
  Future<bool> updateMaterial(material_models.MaterialInfo material) async {
    final result = await executeQuery('''
      UPDATE materials 
      SET material_name = ?, material_code = ?, material_type = ?, unit = ?, 
          default_price = ?, supplier = ?, description = ?, updated_at = NOW()
      WHERE id = ?
    ''', [
      material.materialName,
      material.materialCode,
      material.materialType,
      material.unit,
      material.defaultPrice,
      material.supplier ?? '',
      material.description ?? '',
      material.id,
    ]);
    
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteMaterial(int id) async {
    final result = await executeQuery('DELETE FROM materials WHERE id = ?', [id]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<material_models.MaterialInfo>> searchMaterials(String query) async {
    final result = await executeQuery('''
      SELECT * FROM materials 
      WHERE material_name LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?
      ORDER BY material_name ASC
    ''', ['%$query%', '%$query%', '%$query%', '%$query%']);
    
    final materials = <material_models.MaterialInfo>[];
    for (final row in result) {
      final materialMap = convertRowToMap(row);
      materials.add(material_models.MaterialInfo.fromMap(materialMap));
    }
    return materials;
  }

  @override
  Future<List<material_models.MaterialInfo>> getMaterialsByCategory(String category) async {
    final result = await executeQuery(
      'SELECT * FROM materials WHERE material_type = ? ORDER BY material_name ASC',
      [category],
    );
    
    final materials = <material_models.MaterialInfo>[];
    for (final row in result) {
      final materialMap = convertRowToMap(row);
      materials.add(material_models.MaterialInfo.fromMap(materialMap));
    }
    return materials;
  }

  @override
  Future<int> getMaterialsCount({String? searchQuery}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause = ' WHERE material_name LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%', '%$searchQuery%'];
    }
    
    final result = await executeQuery('SELECT COUNT(*) as count FROM materials$whereClause', whereArgs);
    final row = result.first;
    final dynamic v = row['count'] ?? row[0];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    return 0;
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
      conditions.add('(material_name LIKE ? OR material_type LIKE ? OR description LIKE ? OR supplier LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    
    if (category != null && category.trim().isNotEmpty) {
      conditions.add('material_type = ?');
      whereArgs.add(category);
    }
    
    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }
    
    final sql = 'SELECT * FROM materials$whereClause ORDER BY $sortBy $sortOrder LIMIT $offset, $pageSize';
    final result = await executeQuery(sql, whereArgs);
    
    final materials = <material_models.MaterialInfo>[];
    for (final row in result) {
      final materialMap = convertRowToMap(row);
      materials.add(material_models.MaterialInfo.fromMap(materialMap));
    }
    return materials;
  }

  @override
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    final totalResult = await executeQuery('SELECT COUNT(*) as total FROM materials');
    final totalRow = totalResult.first;
    final int total = (totalRow['total'] is BigInt) ? (totalRow['total'] as BigInt).toInt() : (totalRow['total'] ?? 0);
    
    final typeResult = await executeQuery('''
      SELECT material_type, COUNT(*) as count 
      FROM materials 
      GROUP BY material_type
    ''');
    
    final typeStats = <String, int>{};
    for (final row in typeResult) {
      final type = row['material_type']?.toString() ?? '';
      final count = (row['count'] is BigInt) ? (row['count'] as BigInt).toInt() : (row['count'] ?? 0);
      typeStats[type] = count;
    }
    
    return {
      'totalMaterials': total,
      'typeStatistics': typeStats,
      'lowStockCount': 0, // 默认值
      'totalValue': 0.0,  // 默认值
    };
  }

  @override
  Future<String> getNextMaterialCode() async {
    try {
      // 首先尝试从material_code字段获取
      final result = await executeQuery(
        'SELECT material_code FROM materials WHERE material_code LIKE "M%" ORDER BY CAST(SUBSTRING(material_code, 2) AS UNSIGNED) DESC LIMIT 1'
      );
      if (result.isNotEmpty) {
        final lastCode = result.first['material_code'] as String;
        final numberStr = lastCode.substring(1);
        final number = int.tryParse(numberStr) ?? 0;
        return 'M${number + 1}';
      }
      
      // 如果没有material_code，尝试使用id
      final idResult = await executeQuery('SELECT MAX(id) as max_id FROM materials');
      if (idResult.isNotEmpty && idResult.first['max_id'] != null) {
        final maxId = idResult.first['max_id'] as int;
        return 'M${maxId + 301}'; // 从M301开始
      }
      
      return 'M301'; // 默认起始编码
    } catch (e) {
      print('MySQL获取下一个材料编码失败: $e');
      return 'M301';
    }
  }

  @override
  Future<bool> clearAllMaterials() async {
    try {
      final result = await executeQuery('DELETE FROM materials');
      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      print('MySQL清空所有材料失败: $e');
      return false;
    }
  }
}

