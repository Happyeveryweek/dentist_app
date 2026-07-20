import 'package:dentist_app/models/database_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DatabaseHelper 使用配置指定的 SQLite 路径', () async {
    const configuredPath = '/app/data/databases/dental_clinic.db';

    DatabaseHelper.setCustomDbPath(configuredPath);

    expect(await DatabaseHelper().getDatabasePath(), configuredPath);
  });
}
