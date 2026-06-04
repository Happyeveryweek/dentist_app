/// 财务分页辅助类
/// 
/// 提供分页相关的纯计算函数，不涉及状态管理
class FinancialPaginationHelper {
  /// 计算总页数
  static int calculateTotalPages(int totalRecords, int recordsPerPage) {
    if (totalRecords <= 0) return 0;
    return (totalRecords / recordsPerPage).ceil();
  }

  /// 计算分页的起始索引
  static int calculateStartIndex(int currentPage, int recordsPerPage) {
    return (currentPage - 1) * recordsPerPage;
  }

  /// 计算分页的结束索引
  static int calculateEndIndex(int startIndex, int recordsPerPage, int totalRecords) {
    final endIndex = startIndex + recordsPerPage;
    return endIndex > totalRecords ? totalRecords : endIndex;
  }

  /// 获取分页后的数据
  static List<T> getPagedData<T>(List<T> data, int currentPage, int recordsPerPage) {
    if (data.isEmpty) return [];
    
    final startIndex = calculateStartIndex(currentPage, recordsPerPage);
    final endIndex = calculateEndIndex(startIndex, recordsPerPage, data.length);
    
    if (startIndex >= data.length) return [];
    
    return data.sublist(startIndex, endIndex);
  }

  /// 验证页码是否有效
  static bool isValidPage(int page, int totalPages) {
    return page >= 1 && page <= totalPages;
  }
}
