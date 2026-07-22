import 'package:dentist_app_windows/utils/timed_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('缓存按键隔离并在有效期内返回数据', () {
    var now = DateTime(2026, 7, 22, 10);
    final cache = TimedCache<String, int>(
      validDuration: const Duration(minutes: 20),
      now: () => now,
    );

    cache.put('page-1', 1);
    cache.put('page-2', 2);
    now = now.add(const Duration(minutes: 19));

    expect(cache.get('page-1'), 1);
    expect(cache.get('page-2'), 2);
  });

  test('单个键过期不会受其他键更新时间影响', () {
    var now = DateTime(2026, 7, 22, 10);
    final cache = TimedCache<String, int>(
      validDuration: const Duration(minutes: 20),
      now: () => now,
    );

    cache.put('old', 1);
    now = now.add(const Duration(minutes: 15));
    cache.put('new', 2);
    now = now.add(const Duration(minutes: 6));

    expect(cache.get('old'), isNull);
    expect(cache.get('new'), 2);
  });

  test('clear 清除全部缓存', () {
    final cache = TimedCache<String, int>(
      validDuration: const Duration(minutes: 20),
    );
    cache.put('page-1', 1);

    cache.clear();

    expect(cache.get('page-1'), isNull);
  });
}
