import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dentist_app_windows/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('备份数据源保存为 MySQL 后可在重新初始化时恢复', () async {
    final originalProvider = SettingsProvider();
    await originalProvider.init();
    await originalProvider.setBackupDataSource('mysql');

    final reloadedProvider = SettingsProvider();
    await reloadedProvider.init();

    expect(reloadedProvider.backupDataSource, 'mysql');

    originalProvider.dispose();
    reloadedProvider.dispose();
  });
}
