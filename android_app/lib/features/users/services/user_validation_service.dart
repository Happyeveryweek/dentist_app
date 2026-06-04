import 'package:sqflite/sqflite.dart';
import 'user_connection_service.dart';
import 'user_existence_query_service.dart';

/// 用户数据验证服务
/// 职责：用户名/邮箱存在性检查
class UserValidationService {
  final UserExistenceQueryService _existenceQueryService;

  UserValidationService({
    required UserConnectionService connectionService,
    required Database? database,
    required String dataSourceType,
  }) : _existenceQueryService = UserExistenceQueryService(
         connectionService: connectionService,
         database: database,
         dataSourceType: dataSourceType,
       );

  /// 检查用户名是否存在
  Future<bool> isUsernameExists(String username, {int? excludeId}) async {
    return await _existenceQueryService.exists(
      'users',
      'username',
      username,
      excludeId: excludeId,
    );
  }

  /// 检查邮箱是否存在
  Future<bool> isEmailExists(String email, {int? excludeId}) async {
    if (email.isEmpty) {
      return false;
    }

    return await _existenceQueryService.exists(
      'users',
      'email',
      email,
      excludeId: excludeId,
    );
  }
}
