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

    print('🔄 _updateDisplayedData 调试: 开始更新显示数据');
    print('📊 过滤后数据长度: ${filteredData.length}');
    print('📍 当前页码: $currentPage');
    print('📊 开始索引: $startIndex, 结束索引: $endIndex');

    // 计算过滤后的数据页数
    final filteredPages = (filteredData.length / recordsPerPage).ceil();
    print('📑 过滤后总页数: $filteredPages');

    // 如果当前页码大于过滤后的页数，调整到最后一页
    int adjustedPage = currentPage;
    if (currentPage > filteredPages && filteredPages > 0) {
      print('⚠️ 当前页码超出范围，调整到最后一页: $filteredPages');
      adjustedPage = filteredPages;
    } else if (filteredPages == 0) {
      print('⚠️ 没有数据，调整到第一页');
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

    print('✅ 显示记录已更新，数量: ${records.length}');

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
