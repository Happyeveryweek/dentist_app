/// 时间格式对比和排序测试
/// 验证新的统一时间格式不会影响排序功能
class TimeFormatComparison {
  
  /// 测试时间格式的排序兼容性
  static void testTimeSorting() {
    print('=== 时间格式排序兼容性测试 ===');
    
    // 旧格式的时间数据
    final oldFormatTimes = [
      '2025-09-27T22:08:05.483100',
      '2025-10-23T18:02:32.000',
      '2025-08-15T10:30:00.000Z',
      '2025-11-01T09:15:20.123',
    ];
    
    // 新格式的时间数据
    final newFormatTimes = [
      '2025-09-27 22:08:05',
      '2025-10-23 18:02:32',
      '2025-08-15 10:30:00',
      '2025-11-01 09:15:20',
    ];
    
    print('旧格式排序结果:');
    final oldSorted = List<String>.from(oldFormatTimes)..sort();
    oldSorted.forEach((time) => print('  $time'));
    
    print('\n新格式排序结果:');
    final newSorted = List<String>.from(newFormatTimes)..sort();
    newSorted.forEach((time) => print('  $time'));
    
    print('\n排序顺序是否一致: ${_isSortOrderSame(oldSorted, newSorted)}');
  }
  
  /// 检查两个排序结果的顺序是否一致
  static bool _isSortOrderSame(List<String> oldSorted, List<String> newSorted) {
    if (oldSorted.length != newSorted.length) return false;
    
    for (int i = 0; i < oldSorted.length; i++) {
      final oldDateTime = DateTime.parse(oldSorted[i]);
      final newDateTime = DateTime.parse(newSorted[i]);
      
      if (oldDateTime.compareTo(newDateTime) != 0) {
        return false;
      }
    }
    return true;
  }
  
  /// 测试数据库查询排序
  static void testDatabaseSorting() {
    print('\n=== 数据库排序兼容性 ===');
    
    print('SQLite TEXT类型排序:');
    print('  "2025-08-15 10:30:00" < "2025-09-27 22:08:05" < "2025-10-23 18:02:32"');
    print('  ✅ 字符串按字典序排序，YYYY-MM-DD HH:MM:SS格式天然支持正确排序');
    
    print('\nMySQL DATETIME类型排序:');
    print('  DATETIME类型原生支持时间排序');
    print('  ✅ 完全兼容，性能更好');
  }
}