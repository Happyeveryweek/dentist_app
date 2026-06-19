import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../utils/database_operation_wrapper.dart';
import '../../../utils/datetime_formatter.dart';
import 'financial_data_source_service.dart';
import 'financial_permission_service.dart';
import 'financial_connection_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';

/// 财务查询服务
/// 职责：管理财务数据的查询操作（分页、搜索、复杂查询）
class FinancialQueryService {
  final FinancialDataSourceService _dataSourceService;
  final FinancialPermissionService _permissionService;
  final FinancialConnectionService _connectionService;
  DatabaseOperationWrapper? _dbWrapper;
  String _dataSourceType = 'sqlite';
  Database? _database;
  MySqlConnection? _mysqlConnection;

  FinancialQueryService({
    required FinancialDataSourceService dataSourceService,
    required FinancialPermissionService permissionService,
    required FinancialConnectionService connectionService,
  }) : _dataSourceService = dataSourceService,
       _permissionService = permissionService,
       _connectionService = connectionService;

  /// 设置数据库连接
  void setDatabaseConnection({
    required String dataSourceType,
    Database? database,
    MySqlConnection? mysqlConnection,
    DatabaseOperationWrapper? dbWrapper,
  }) {
    _dataSourceType = dataSourceType;
    _dataSourceService.setDataSourceType(dataSourceType);
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dbWrapper = dbWrapper;
  }

  /// 获取当前 MySQL 连接
  MySqlConnection? get _currentMysqlConnection =>
      _connectionService.currentMysqlConnection;

  bool _isConnectionError(dynamic error) {
    return DatabaseOperationWrapper.isConnectionError(error);
  }

  /// 获取财务记录总数
  Future<int> getFinancialRecordsCount() async {
    if (_dbWrapper == null) return 0;

    return await _dbWrapper!.wrapOperation(
      'getFinancialRecordsCount',
      () async {
        try {
          int count = 0;

          if (_dataSourceType == 'sqlite') {
            final db = _database;
            if (db == null) return 0;

            // 构建查询条件
            List<String> conditions = ['fr.patient_id IS NOT NULL'];
            List<dynamic> queryArgs = [];

            // 权限过滤：基于医生字段
            final doctorFilter = _permissionService.getDoctorFilter();
            if (doctorFilter != null &&
                _permissionService.shouldFilterByDoctor()) {
              conditions.add('p.doctor = ?');
              queryArgs.add(doctorFilter);
            }

            final result = await db.rawQuery('''
            SELECT COUNT(*) as count
            FROM financial_records fr
            LEFT JOIN patients p ON fr.patient_id = p.id
            WHERE ${conditions.join(' AND ')}
          ''', queryArgs);
            if (result.isNotEmpty) {
              count = result.first['count'] as int;
            }
          } else if (_dataSourceType == 'mysql') {
            final conn = _currentMysqlConnection;
            if (conn == null) return 0;

            // 构建查询条件
            List<String> conditions = ['fr.patient_id IS NOT NULL'];
            List<dynamic> queryArgs = [];

            // 权限过滤：基于医生字段
            final doctorFilter = _permissionService.getDoctorFilter();
            if (doctorFilter != null &&
                _permissionService.shouldFilterByDoctor()) {
              conditions.add('p.doctor = ?');
              queryArgs.add(doctorFilter);
            }

            final results = await conn.query('''
            SELECT COUNT(*) as count
            FROM financial_records fr
            LEFT JOIN patients p ON fr.patient_id = p.id
            WHERE ${conditions.join(' AND ')}
          ''', queryArgs);
            if (results.isNotEmpty) {
              count = int.tryParse(results.first['count'].toString()) ?? 0;
            }
          }
          return count;
        } catch (e) {
          print('获取财务记录总数失败: $e');
          if (_isConnectionError(e)) rethrow;
          return 0;
        }
      },
    );
  }

  /// 分页获取财务记录
  Future<List<FinancialRecord>> getPaginatedFinancialRecords(
    int page,
    int pageSize,
  ) async {
    if (_dbWrapper == null) return [];

    return await _dbWrapper!.wrapOperation(
      'getPaginatedFinancialRecords',
      () async {
        try {
          print('🔄 从数据库分页获取财务记录，页码: $page, 每页大小: $pageSize');

          // 确保财务记录表存在
          await _dataSourceService.ensureFinancialRecordsTableExists(
            dataSourceType: _dataSourceType,
            sqliteDatabase: _database,
            mysqlConnection: _currentMysqlConnection,
          );

          // 检查MySQL连接状态
          if (_dataSourceType == 'mysql') {
            final connectionOk = await _connectionService.ensureConnection();
            if (!connectionOk) {
              // 尝试自动重连
              final reconnected = await _connectionService.autoReconnect();
              if (!reconnected) {
                throw Exception('数据库连接失败，请检查网络连接');
              }
            }
          }

          List<FinancialRecord> records = [];
          final offset = (page - 1) * pageSize;

          if (_dataSourceType == 'sqlite') {
            final db = _database;
            if (db == null) throw Exception('SQLite数据库未初始化');

            // 构建查询条件
            List<String> conditions = ['fr.patient_id IS NOT NULL'];
            List<dynamic> queryArgs = [];

            // 权限过滤：基于医生字段
            final doctorFilter = _permissionService.getDoctorFilter();
            if (doctorFilter != null &&
                _permissionService.shouldFilterByDoctor()) {
              conditions.add('p.doctor = ?');
              queryArgs.add(doctorFilter);
            }

            final result = await db.rawQuery(
              '''
            SELECT fr.*, p.name as patient_name
            FROM financial_records fr
            LEFT JOIN patients p ON fr.patient_id = p.id
            WHERE ${conditions.join(' AND ')}
            ORDER BY fr.updated_at DESC
            LIMIT ? OFFSET ?
          ''',
              [...queryArgs, pageSize, offset],
            );

            records =
                result
                    .map(
                      (e) => FinancialRecord.fromMap(e, dataSource: 'sqlite'),
                    )
                    .toList();
            print('✅ SQLite分页查询成功，获取到 ${records.length} 条记录');
          } else if (_dataSourceType == 'mysql') {
            final conn = _currentMysqlConnection;
            if (conn == null) throw Exception('MySQL连接未初始化');

            try {
              // 构建查询条件
              List<String> conditions = ['fr.patient_id IS NOT NULL'];
              List<dynamic> queryArgs = [];

              // 权限过滤：基于医生字段
              final doctorFilter = _permissionService.getDoctorFilter();
              if (doctorFilter != null &&
                  _permissionService.shouldFilterByDoctor()) {
                conditions.add('p.doctor = ?');
                queryArgs.add(doctorFilter);
              }

              final results = await conn.query(
                '''
              SELECT fr.*, COALESCE(p.name, '未知患者') as patient_name
              FROM financial_records fr
              LEFT JOIN patients p ON fr.patient_id = p.id
              WHERE ${conditions.join(' AND ')}
              ORDER BY fr.updated_at DESC
              LIMIT ? OFFSET ?
            ''',
                [...queryArgs, pageSize, offset],
              );

              records =
                  results
                      .map(
                        (row) => FinancialRecord.fromMap({
                          'id': int.tryParse(row['id'].toString()) ?? 0,
                          'patient_id':
                              int.tryParse(row['patient_id'].toString()) ?? 0,
                          'total_quantity':
                              int.tryParse(row['total_quantity'].toString()) ??
                              0,
                          'notes': row['notes']?.toString(),
                          'created_at':
                              FinancialPermissionService.convertBlobToString(
                                row['created_at'],
                              ) ??
                              DateTimeFormatter.nowDbString(),
                          'updated_at':
                              FinancialPermissionService.convertBlobToString(
                                row['updated_at'],
                              ) ??
                              DateTimeFormatter.nowDbString(),
                          'patient_name':
                              FinancialPermissionService.convertBlobToString(
                                row['patient_name'],
                              ),
                        }, dataSource: 'mysql'),
                      )
                      .toList();

              print('✅ MySQL分页查询成功，获取到 ${records.length} 条记录');
            } catch (e) {
              // 检查是否是连接错误
              if (e.toString().contains('SocketException') ||
                  e.toString().contains('Cannot write to socket') ||
                  e.toString().contains('Connection reset')) {
                print('检测到连接错误，尝试重连: $e');
                await _connectionService.autoReconnect();
                return await getPaginatedFinancialRecords(page, pageSize);
              }
              rethrow;
            }
          }

          return records;
        } catch (e) {
          print('❌ 分页查询失败: $e');
          rethrow;
        }
      },
    );
  }

  String _formatDateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 搜索财务记录
  Future<List<FinancialRecord>> searchFinancialRecords(
    String keyword, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_dbWrapper == null) return [];

    return await _dbWrapper!.wrapOperation('searchFinancialRecords', () async {
      try {
        final trimmed = keyword.trim();
        if (trimmed.isEmpty) return [];

        final lowerKeyword = trimmed.toLowerCase();
        final lowerPattern = '%$lowerKeyword%';
        final noSpacePattern = '%${lowerKeyword.replaceAll(' ', '')}%';
        final conditions = <String>[
          'fr.patient_id IS NOT NULL',
          '''(
            LOWER(COALESCE(p.name, '')) LIKE ?
            OR LOWER(COALESCE(p.name_pinyin, '')) LIKE ?
            OR LOWER(REPLACE(COALESCE(p.name_pinyin, ''), ' ', '')) LIKE ?
            OR LOWER(COALESCE(p.name_initials, '')) LIKE ?
          )''',
        ];
        final queryArgs = <dynamic>[
          lowerPattern,
          lowerPattern,
          noSpacePattern,
          lowerPattern,
        ];

        if (startDate != null && endDate != null) {
          conditions.add('DATE(fr.created_at) >= ?');
          conditions.add('DATE(fr.created_at) <= ?');
          queryArgs.addAll([
            _formatDateOnly(startDate),
            _formatDateOnly(endDate),
          ]);
        }

        final doctorFilter = _permissionService.getDoctorFilter();
        if (doctorFilter != null && _permissionService.shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }

        final whereClause = conditions.join(' AND ');

        if (_dataSourceType == 'sqlite') {
          final db = _database;
          if (db == null) throw Exception('SQLite数据库未初始化');
          final result = await db.rawQuery('''
            SELECT
              fr.id, fr.patient_id, fr.total_quantity, fr.notes,
              fr.created_at, fr.updated_at,
              COALESCE(p.name, '未知患者') as patient_name,
              p.name_pinyin as patient_name_pinyin,
              p.name_initials as patient_name_initials
            FROM financial_records fr
            LEFT JOIN patients p ON fr.patient_id = p.id
            WHERE $whereClause
            ORDER BY fr.updated_at DESC
          ''', queryArgs);
          return result
              .map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite'))
              .toList();
        } else if (_dataSourceType == 'mysql') {
          final conn = _currentMysqlConnection;
          if (conn == null) throw Exception('MySQL连接未初始化');
          final results = await conn.query('''
            SELECT
              fr.id, fr.patient_id, fr.total_quantity, fr.notes,
              fr.created_at, fr.updated_at,
              COALESCE(p.name, '未知患者') as patient_name,
              p.name_pinyin as patient_name_pinyin,
              p.name_initials as patient_name_initials
            FROM financial_records fr
            LEFT JOIN patients p ON fr.patient_id = p.id
            WHERE $whereClause
            ORDER BY fr.updated_at DESC
          ''', queryArgs);

          return results
              .map(
                (row) => FinancialRecord.fromMap({
                  'id': int.tryParse(row['id'].toString()) ?? 0,
                  'patient_id': int.tryParse(row['patient_id'].toString()) ?? 0,
                  'total_quantity':
                      int.tryParse(row['total_quantity'].toString()) ?? 0,
                  'notes': row['notes']?.toString(),
                  'created_at':
                      FinancialPermissionService.convertBlobToString(
                        row['created_at'],
                      ) ??
                      DateTimeFormatter.nowDbString(),
                  'updated_at':
                      FinancialPermissionService.convertBlobToString(
                        row['updated_at'],
                      ) ??
                      DateTimeFormatter.nowDbString(),
                  'patient_name':
                      FinancialPermissionService.convertBlobToString(
                        row['patient_name'],
                      ),
                  'patient_name_pinyin':
                      FinancialPermissionService.convertBlobToString(
                        row['patient_name_pinyin'],
                      ),
                  'patient_name_initials':
                      FinancialPermissionService.convertBlobToString(
                        row['patient_name_initials'],
                      ),
                }, dataSource: 'mysql'),
              )
              .toList();
        }
        return [];
      } catch (e) {
        print('❌ 搜索财务记录失败: $e');
        if (_isConnectionError(e)) rethrow;
        return [];
      }
    });
  }

  /// 带日期筛选的分页查询
  Future<List<FinancialRecord>> getPaginatedFinancialRecordsWithDateFilter({
    required int page,
    required int pageSize,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_dbWrapper == null) return [];

    return await _dbWrapper!.wrapOperation(
      'getPaginatedFinancialRecordsWithDateFilter',
      () async {
        try {
          final conditions = <String>['fr.patient_id IS NOT NULL'];
          final queryArgs = <dynamic>[];
          if (startDate != null && endDate != null) {
            conditions.add('DATE(fr.created_at) >= ?');
            conditions.add('DATE(fr.created_at) <= ?');
            queryArgs.addAll([
              _formatDateOnly(startDate),
              _formatDateOnly(endDate),
            ]);
          }

          final doctorFilter = _permissionService.getDoctorFilter();
          if (doctorFilter != null &&
              _permissionService.shouldFilterByDoctor()) {
            conditions.add('p.doctor = ?');
            queryArgs.add(doctorFilter);
          }

          final whereClause = conditions.join(' AND ');
          final offset = (page - 1) * pageSize;

          if (_dataSourceType == 'sqlite') {
            final db = _database;
            if (db == null) throw Exception('SQLite数据库未初始化');
            final result = await db.rawQuery(
              'SELECT fr.*, COALESCE(p.name, \'未知患者\') as patient_name, p.name_pinyin as patient_name_pinyin, p.name_initials as patient_name_initials '
              'FROM financial_records fr LEFT JOIN patients p ON fr.patient_id = p.id '
              'WHERE $whereClause '
              'ORDER BY fr.updated_at DESC LIMIT ? OFFSET ?',
              [...queryArgs, pageSize, offset],
            );
            return result
                .map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite'))
                .toList();
          } else if (_dataSourceType == 'mysql') {
            final conn = _currentMysqlConnection;
            if (conn == null) throw Exception('MySQL连接未初始化');
            final results = await conn.query(
              '''
            SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes,
                   fr.created_at, fr.updated_at,
                   COALESCE(p.name, '未知患者') as patient_name,
                   p.name_pinyin as patient_name_pinyin,
                   p.name_initials as patient_name_initials
            FROM financial_records fr
            LEFT JOIN patients p ON fr.patient_id = p.id
            WHERE $whereClause
            ORDER BY fr.updated_at DESC
            LIMIT ? OFFSET ?
          ''',
              [...queryArgs, pageSize, offset],
            );
            return results
                .map(
                  (row) => FinancialRecord.fromMap({
                    'id': int.tryParse(row['id'].toString()) ?? 0,
                    'patient_id':
                        int.tryParse(row['patient_id'].toString()) ?? 0,
                    'total_quantity':
                        int.tryParse(row['total_quantity'].toString()) ?? 0,
                    'notes': row['notes']?.toString(),
                    'created_at':
                        FinancialPermissionService.convertBlobToString(
                          row['created_at'],
                        ) ??
                        DateTimeFormatter.nowDbString(),
                    'updated_at':
                        FinancialPermissionService.convertBlobToString(
                          row['updated_at'],
                        ) ??
                        DateTimeFormatter.nowDbString(),
                    'patient_name':
                        FinancialPermissionService.convertBlobToString(
                          row['patient_name'],
                        ),
                    'patient_name_pinyin':
                        FinancialPermissionService.convertBlobToString(
                          row['patient_name_pinyin'],
                        ),
                    'patient_name_initials':
                        FinancialPermissionService.convertBlobToString(
                          row['patient_name_initials'],
                        ),
                  }, dataSource: 'mysql'),
                )
                .toList();
          }
          return [];
        } catch (e) {
          print('❌ 带日期筛选分页查询失败: $e');
          rethrow;
        }
      },
    );
  }

  /// 获取财务记录总数（带日期筛选）
  Future<int> getFinancialRecordCount({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final conditions = <String>['fr.patient_id IS NOT NULL'];
      final queryArgs = <dynamic>[];
      if (startDate != null && endDate != null) {
        conditions.add('DATE(fr.created_at) >= ?');
        conditions.add('DATE(fr.created_at) <= ?');
        queryArgs.addAll([
          _formatDateOnly(startDate),
          _formatDateOnly(endDate),
        ]);
      }

      final doctorFilter = _permissionService.getDoctorFilter();
      if (doctorFilter != null && _permissionService.shouldFilterByDoctor()) {
        conditions.add('p.doctor = ?');
        queryArgs.add(doctorFilter);
      }

      final whereClause = conditions.join(' AND ');

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM financial_records fr LEFT JOIN patients p ON fr.patient_id = p.id WHERE $whereClause',
          queryArgs,
        );
        return (result.first['count'] as int?) ?? 0;
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        final results = await conn.query(
          'SELECT COUNT(*) as count FROM financial_records fr LEFT JOIN patients p ON fr.patient_id = p.id WHERE $whereClause',
          queryArgs,
        );
        return int.tryParse(results.first['count'].toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ 带日期筛选计数失败: $e');
      if (_isConnectionError(e)) rethrow;
      return 0;
    }
  }

  /// 获取所有财务项目明细（带权限过滤）
  Future<List<Map<String, dynamic>>> getAllFinancialItemsWithDetailsFiltered({
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    DateTime? startDate,
    DateTime? endDate,
    String? patientName,
    String? itemName,
    double? priceMin,
    double? priceMax,
    double? processingMin,
    double? processingMax,
  }) async {
    if (_dbWrapper == null) return [];

    return await _dbWrapper!.wrapOperation(
      'getAllFinancialItemsWithDetailsFiltered',
      () async {
        try {
          // 构建查询条件
          List<String> conditions = [];
          List<dynamic> whereArgs = [];

          // 权限过滤：基于医生字段
          final doctorFilter = _permissionService.getDoctorFilter();
          if (doctorFilter != null &&
              _permissionService.shouldFilterByDoctor()) {
            conditions.add('p.doctor = ?');
            whereArgs.add(doctorFilter);
          }

          // 日期范围过滤
          if (startDate != null) {
            conditions.add('fi.charge_date >= ?');
            whereArgs.add(DateTimeFormatter.toDbString(startDate));
          }
          if (endDate != null) {
            conditions.add('fi.charge_date <= ?');
            whereArgs.add(DateTimeFormatter.toDbString(endDate));
          }

          // 患者姓名过滤
          if (patientName != null && patientName.isNotEmpty) {
            conditions.add('p.name LIKE ?');
            whereArgs.add('%$patientName%');
          }

          // 项目名称过滤
          if (itemName != null && itemName.isNotEmpty) {
            conditions.add('fi.item_name LIKE ?');
            whereArgs.add('%$itemName%');
          }

          // 价格范围过滤
          if (priceMin != null) {
            conditions.add('fi.item_price >= ?');
            whereArgs.add(priceMin);
          }
          if (priceMax != null) {
            conditions.add('fi.item_price <= ?');
            whereArgs.add(priceMax);
          }

          // 加工费范围过滤
          if (processingMin != null) {
            conditions.add('fi.processing_fee >= ?');
            whereArgs.add(processingMin);
          }
          if (processingMax != null) {
            conditions.add('fi.processing_fee <= ?');
            whereArgs.add(processingMax);
          }

          // 构建WHERE子句
          String whereClause =
              conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

          // 构建ORDER BY子句
          String orderBy = 'fi.$sortBy $sortOrder';

          List<Map<String, dynamic>> results = [];

          if (_dataSourceType == 'sqlite') {
            final db = _database;
            if (db == null) throw Exception('SQLite数据库未初始化');

            final query = '''
            SELECT
              fi.*,
              fr.patient_id,
              p.name as patient_name,
              p.doctor as patient_doctor
            FROM financial_items fi
            JOIN financial_records fr ON fi.financial_record_id = fr.id
            LEFT JOIN patients p ON fr.patient_id = p.id
            $whereClause
            ORDER BY $orderBy
          ''';

            final queryResults = await db.rawQuery(query, whereArgs);

            results =
                queryResults
                    .map(
                      (row) => {
                        'item': FinancialItem.fromMap({
                          'id': row['id'],
                          'financial_record_id': row['financial_record_id'],
                          'item_name': row['item_name'],
                          'item_price': row['item_price'],
                          'processing_fee': row['processing_fee'],
                          'quantity': row['quantity'],
                          'total_price': row['total_price'],
                          'charge_date': row['charge_date'],
                          'created_at': row['created_at'],
                          'updated_at': row['updated_at'],
                        }),
                        'patient_id': row['patient_id'],
                        'patient_name': row['patient_name'],
                        'patient_doctor': row['patient_doctor'],
                      },
                    )
                    .toList();
          } else if (_dataSourceType == 'mysql') {
            final conn = _currentMysqlConnection;
            if (conn == null) throw Exception('MySQL连接未初始化');

            final query = '''
            SELECT
              fi.*,
              fr.patient_id,
              p.name as patient_name,
              p.doctor as patient_doctor
            FROM financial_items fi
            JOIN financial_records fr ON fi.financial_record_id = fr.id
            LEFT JOIN patients p ON fr.patient_id = p.id
            $whereClause
            ORDER BY $orderBy
          ''';

            final queryResults = await conn.query(query, whereArgs);

            results =
                queryResults
                    .map(
                      (row) => {
                        'item': FinancialItem.fromMap({
                          'id': row['id'],
                          'financial_record_id': row['financial_record_id'],
                          'item_name':
                              FinancialPermissionService.convertBlobToString(
                                row['item_name'],
                              ) ??
                              '',
                          'item_price':
                              (row['item_price'] as num?)?.toDouble() ?? 0.0,
                          'processing_fee':
                              (row['processing_fee'] as num?)?.toDouble() ??
                              0.0,
                          'quantity': row['quantity'] ?? 1,
                          'total_price':
                              (row['total_price'] as num?)?.toDouble() ?? 0.0,
                          'charge_date':
                              FinancialPermissionService.convertBlobToString(
                                row['charge_date'],
                              ) ??
                              DateTimeFormatter.nowDbString(),
                          'created_at':
                              FinancialPermissionService.convertBlobToString(
                                row['created_at'],
                              ) ??
                              DateTimeFormatter.nowDbString(),
                          'updated_at':
                              FinancialPermissionService.convertBlobToString(
                                row['updated_at'],
                              ) ??
                              DateTimeFormatter.nowDbString(),
                        }),
                        'patient_id': row['patient_id'],
                        'patient_name':
                            FinancialPermissionService.convertBlobToString(
                              row['patient_name'],
                            ),
                        'patient_doctor':
                            FinancialPermissionService.convertBlobToString(
                              row['patient_doctor'],
                            ),
                      },
                    )
                    .toList();
          }

          return results;
        } catch (e) {
          print('❌ 获取财务项目明细失败: $e');
          rethrow;
        }
      },
    );
  }
}
