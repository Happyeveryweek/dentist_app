import '../../../models/financial_record.dart';

/// 分页更新辅助类
///
/// 提供分页数据更新的纯逻辑
class FinancialPaginationUpdateHelper {
  /// 计算分页数据
  static PaginationResult calculatePaginationData({
    required List<Map<String, dynamic>> filteredData,
    required int currentPage,
    required int recordsPerPage,
  }) {
    final startIndex = (currentPage - 1) * recordsPerPage;
    final endIndex = startIndex + recordsPerPage;

    // 计算过滤后的数据页数
    final filteredPages = (filteredData.length / recordsPerPage).ceil();

    // 如果当前页码大于过滤后的页数，调整到最后一页
    int adjustedPage = currentPage;
    if (currentPage > filteredPages && filteredPages > 0) {
      adjustedPage = filteredPages;
    } else if (filteredPages == 0) {
      adjustedPage = 1;
    }

    // 从Map中提取FinancialRecord对象
    final List<FinancialRecord> records = filteredData
        .sublist(
          startIndex.clamp(0, filteredData.length),
          endIndex.clamp(0, filteredData.length),
        )
        .map((data) => data['record'] as FinancialRecord)
        .toList();

    return PaginationResult(
      records: records,
      adjustedPage: adjustedPage,
      filteredPages: filteredPages,
    );
  }
}

/// 分页结果
class PaginationResult {
  final List<FinancialRecord> records;
  final int adjustedPage;
  final int filteredPages;

  PaginationResult({
    required this.records,
    required this.adjustedPage,
    required this.filteredPages,
  });
}
