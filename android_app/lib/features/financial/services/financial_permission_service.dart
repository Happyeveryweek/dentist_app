import '../../../models/financial_record.dart';
import '../../../providers/user_provider.dart';
import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../../../utils/datetime_formatter.dart';
import '../../../utils/app_logger.dart';

/// 财务权限过滤服务
/// 职责：管理财务数据的权限过滤逻辑
class FinancialPermissionService {
  UserProvider? _userProvider;

  /// 设置用户提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  /// 获取医生过滤条件（用于数据访问权限控制）
  String? getDoctorFilter() {
    final provider = _userProvider;
    if (provider == null) return null;
    final currentUser = provider.currentUser;
    if (currentUser == null) {
      return null;
    }

    return provider.buildDoctorFilter(currentUser);
  }

  /// 财务管理需要数据过滤 - 普通用户只能查看自己医生的数据
  bool shouldFilterByDoctor() {
    final currentUser = _userProvider?.currentUser;
    if (currentUser == null) {
      return false;
    }

    // 管理员不需要数据过滤
    if (currentUser.role == 'admin') {
      return false;
    }

    final doctor = currentUser.doctor;
    return currentUser.role == 'doctor' && doctor != null && doctor.isNotEmpty;
  }

  bool hasAccess() {
    final user = _userProvider?.currentUser;
    return user?.role == 'admin' || shouldFilterByDoctor();
  }

  /// 获取过滤后的财务记录（基于医生字段）
  Future<List<FinancialRecord>> getFilteredFinancialRecords(
    String doctorFilter,
    String dataSourceType,
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
  ) async {
    List<FinancialRecord> records = [];

    if (dataSourceType == 'sqlite') {
      final db = sqliteDatabase;
      if (db == null) throw Exception('SQLite数据库未初始化');

      final result = await db.rawQuery(
        '''
        SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
               COALESCE(p.name, '未知患者') as patient_name,
               p.name_pinyin as patient_name_pinyin,
               p.name_initials as patient_name_initials
        FROM financial_records fr 
        LEFT JOIN patients p ON fr.patient_id = p.id 
        WHERE p.doctor = ?
        ORDER BY fr.created_at DESC
      ''',
        [doctorFilter],
      );

      records =
          result
              .map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite'))
              .toList();
    } else if (dataSourceType == 'mysql') {
      final conn = mysqlConnection;
      if (conn == null) throw Exception('MySQL连接未初始化');

      final results = await conn.query(
        '''
        SELECT fr.*, COALESCE(p.name, '未知患者') as patient_name,
               p.name_pinyin as patient_name_pinyin,
               p.name_initials as patient_name_initials
        FROM financial_records fr 
        LEFT JOIN patients p ON fr.patient_id = p.id 
        WHERE p.doctor = ?
        ORDER BY fr.created_at DESC
      ''',
        [doctorFilter],
      );

      records =
          results
              .map(
                (row) => FinancialRecord.fromMap({
                  'id': int.tryParse(row['id'].toString()) ?? 0,
                  'patient_id': int.tryParse(row['patient_id'].toString()) ?? 0,
                  'total_quantity':
                      int.tryParse(row['total_quantity'].toString()) ?? 0,
                  'notes': row['notes']?.toString(),
                  'created_at':
                      _convertBlobToString(row['created_at']) ??
                      DateTimeFormatter.nowDbString(),
                  'updated_at':
                      _convertBlobToString(row['updated_at']) ??
                      DateTimeFormatter.nowDbString(),
                  'patient_name': _convertBlobToString(row['patient_name']),
                  'patient_name_pinyin': _convertBlobToString(
                    row['patient_name_pinyin'],
                  ),
                  'patient_name_initials': _convertBlobToString(
                    row['patient_name_initials'],
                  ),
                }, dataSource: 'mysql'),
              )
              .toList();
    }

    return records;
  }

  /// 转换 Blob 类型为 String（公共方法，供外部调用）
  static String? convertBlobToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Blob) {
      try {
        return String.fromCharCodes(value.toBytes());
      } catch (e) {
        AppLogger.info('Blob转换错误: $e');
        return value.toString();
      }
    }
    return value.toString();
  }

  /// 转换 Blob 类型为 String（私有方法）
  String? _convertBlobToString(dynamic value) {
    return convertBlobToString(value);
  }
}
