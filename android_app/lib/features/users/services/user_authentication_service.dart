import '../../../models/user.dart';
import '../../../data_sources/user_data_source.dart';
import '../../../utils/database_operation_wrapper.dart';
import 'user_permission_service.dart';

/// 用户认证服务
/// 职责：用户登录、登出、认证
class UserAuthenticationService {
  final UserDataSource _dataSource;
  final DatabaseOperationWrapper? _dbWrapper;
  final bool Function() _isInitialized;
  final String Function() _getDataSourceType;
  final void Function() _notifyListeners;
  final Future<void> Function(User) _primeCurrentUserPermissions;
  final Future<User?> Function(String username, String password) _authenticateWithLocalSqlite;

  UserAuthenticationService({
    required UserDataSource dataSource,
    required DatabaseOperationWrapper? dbWrapper,
    required bool Function() isInitialized,
    required String Function() getDataSourceType,
    required void Function() notifyListeners,
    required Future<void> Function(User) primeCurrentUserPermissions,
    required Future<User?> Function(String username, String password) authenticateWithLocalSqlite,
  }) : _dataSource = dataSource,
       _dbWrapper = dbWrapper,
       _isInitialized = isInitialized,
       _getDataSourceType = getDataSourceType,
       _notifyListeners = notifyListeners,
       _primeCurrentUserPermissions = primeCurrentUserPermissions,
       _authenticateWithLocalSqlite = authenticateWithLocalSqlite;

  /// 用户认证
  Future<User?> authenticateUser(String username, String password) async {
    if (!_isInitialized()) {
      print('UserProvider未初始化，无法进行用户认证');
      return null;
    }

    if (_dbWrapper == null) return null;
    
    return await _dbWrapper!.wrapOperation('authenticateUser', () async {
      try {
        print('用户认证 - 用户名: $username, 原始密码: $password');

        // 使用数据源模式（统一接口）
        final user = await _dataSource.authenticateUser(username, password);

        if (user != null) {
          print('用户认证成功: ${user.username}');
          
          // 登录成功后自动加载用户权限
          try {
            await _primeCurrentUserPermissions(user);
            print('用户权限加载成功: ${user.username}');
          } catch (e) {
            print('用户权限加载失败: $e');
            // 权限加载失败不影响登录，但记录错误
          }
          
          _notifyListeners();
        } else {
          print('用户认证失败: 用户名或密码错误');
        }

        return user;
      } catch (e) {
        print('用户认证异常: $e');

        if (_getDataSourceType() == 'mysql') {
          print('MySQL认证失败，尝试使用本地SQLite离线认证');
          final localUser = await _authenticateWithLocalSqlite(username, password);
          if (localUser != null) {
            await _primeCurrentUserPermissions(localUser);
            _notifyListeners();
            return localUser;
          }
        }

        rethrow;
      }
    });
  }
}
