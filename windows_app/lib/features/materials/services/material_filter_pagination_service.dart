import '../../../models/material.dart' as material_models;

/// 材料筛选和分页服务
///
/// 负责材料数据的筛选和分页逻辑，包括：
/// - 按类型筛选
/// - 按搜索关键词筛选
/// - 分页计算
/// - 页面跳转
class MaterialFilterPaginationService {
  final int materialsPerPage;

  MaterialFilterPaginationService({this.materialsPerPage = 10});

  /// 筛选材料
  FilterResult filterMaterials({
    required List<material_models.MaterialInfo> materials,
    required String selectedType,
    required String searchQuery,
    int currentPage = 1,
    bool resetPage = true,
  }) {
    // 类型筛选和搜索关键词筛选
    final filteredMaterials = materials.where((material) {
      // 类型筛选
      bool typeMatch =
          selectedType == '全部' || (material.materialType == selectedType);

      // 搜索关键词筛选
      bool searchMatch = searchQuery.isEmpty;
      if (!searchMatch) {
        final query = searchQuery.toLowerCase();
        searchMatch = (material.materialName.toLowerCase().contains(query)) ||
            (material.materialCode?.toLowerCase().contains(query) ?? false) ||
            (material.supplier?.toLowerCase().contains(query) ?? false) ||
            (material.description?.toLowerCase().contains(query) ?? false);
      }

      return typeMatch && searchMatch;
    }).toList();

    // 更新分页信息
    final totalMaterials = filteredMaterials.length;
    final totalPages = (totalMaterials / materialsPerPage).ceil();

    // 计算当前页
    int newCurrentPage = currentPage;
    if (resetPage) {
      newCurrentPage = 1;
    } else {
      // 保留当前页，但确保不超出范围
      if (newCurrentPage > totalPages && totalPages > 0) {
        newCurrentPage = totalPages;
      }
    }

    // 更新当前页面显示的数据
    final displayedMaterials = _getDisplayedMaterials(
      filteredMaterials,
      newCurrentPage,
    );

    return FilterResult(
      filteredMaterials: filteredMaterials,
      displayedMaterials: displayedMaterials,
      totalMaterials: totalMaterials,
      totalPages: totalPages,
      currentPage: newCurrentPage,
    );
  }

  /// 获取当前页面显示的材料
  List<material_models.MaterialInfo> _getDisplayedMaterials(
    List<material_models.MaterialInfo> filteredMaterials,
    int currentPage,
  ) {
    final startIndex = (currentPage - 1) * materialsPerPage;
    final endIndex = startIndex + materialsPerPage;

    return filteredMaterials.sublist(
      startIndex,
      endIndex > filteredMaterials.length ? filteredMaterials.length : endIndex,
    );
  }

  /// 跳转到指定页面
  FilterResult goToPage(
    FilterResult currentResult,
    int page,
  ) {
    if (page >= 1 && page <= currentResult.totalPages) {
      final displayedMaterials = _getDisplayedMaterials(
        currentResult.filteredMaterials,
        page,
      );

      return FilterResult(
        filteredMaterials: currentResult.filteredMaterials,
        displayedMaterials: displayedMaterials,
        totalMaterials: currentResult.totalMaterials,
        totalPages: currentResult.totalPages,
        currentPage: page,
      );
    }
    return currentResult;
  }

  /// 跳转到上一页
  FilterResult goToPreviousPage(FilterResult currentResult) {
    if (currentResult.currentPage > 1) {
      return goToPage(currentResult, currentResult.currentPage - 1);
    }
    return currentResult;
  }

  /// 跳转到下一页
  FilterResult goToNextPage(FilterResult currentResult) {
    if (currentResult.currentPage < currentResult.totalPages) {
      return goToPage(currentResult, currentResult.currentPage + 1);
    }
    return currentResult;
  }
}

/// 筛选结果
class FilterResult {
  final List<material_models.MaterialInfo> filteredMaterials;
  final List<material_models.MaterialInfo> displayedMaterials;
  final int totalMaterials;
  final int totalPages;
  final int currentPage;

  FilterResult({
    required this.filteredMaterials,
    required this.displayedMaterials,
    required this.totalMaterials,
    required this.totalPages,
    required this.currentPage,
  });
}
