import 'package:dentist_app/utils/database_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaultPath = r'C:\app\databases\dental_clinic.db';

  test('未配置 SQLite 文件时同步到应用默认数据库', () {
    expect(
      DatabaseUtils.resolveSqliteSyncPath(
        configuredPath: '',
        defaultPath: defaultPath,
      ),
      defaultPath,
    );
    expect(
      DatabaseUtils.resolveSqliteSyncPath(
        configuredPath: 'dental_clinic.db',
        defaultPath: defaultPath,
      ),
      defaultPath,
    );
  });

  test('配置自定义 SQLite 文件时保留该绝对路径', () {
    const customPath = r'D:\clinic\custom.db';

    expect(
      DatabaseUtils.resolveSqliteSyncPath(
        configuredPath: customPath,
        defaultPath: defaultPath,
      ),
      customPath,
    );
    expect(
      DatabaseUtils.getSqliteSyncTargetLabel(
        configuredPath: customPath,
        resolvedPath: customPath,
      ),
      '自定义 SQLite（custom.db）',
    );
  });
}
