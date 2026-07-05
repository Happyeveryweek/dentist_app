import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 牙科治疗项目模型
class DentalTreatment {
  final String id;
  final String name;
  final String? description;
  final String category;
  final bool isCommon; // 是否是常用项目

  const DentalTreatment({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.isCommon = false,
  });

  // 从Map创建DentalTreatment对象
  factory DentalTreatment.fromMap(Map<String, dynamic> map) {
    return DentalTreatment(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      category: map['category'],
      isCommon: map['isCommon'] ?? false,
    );
  }

  // 将DentalTreatment对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'category': category,
      'isCommon': isCommon,
    };
  }
}

/// 牙科治疗项目管理类
class DentalTreatmentManager {
  // 预定义的牙科治疗项目列表
  static final List<DentalTreatment> predefinedTreatments = [
    // 根管治疗相关
    const DentalTreatment(
      id: 'root_canal_opening',
      name: '根管开髓',
      category: '根管治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'nerve_killing',
      name: '封药',
      category: '根管治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'root_canal_preparation',
      name: '根管预备',
      category: '根管治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'root_canal_filling',
      name: '根管填充',
      category: '根管治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'root_canal_disinfection',
      name: '根管消毒',
      category: '根管治疗',
      isCommon: true,
    ),

    // 补牙相关
    const DentalTreatment(
      id: 'filling',
      name: '补牙',
      category: '修复治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'composite_resin_filling',
      name: '复合树脂充填',
      category: '修复治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'glass_ionomer_filling',
      name: '玻璃离子充填',
      category: '修复治疗',
      isCommon: false,
    ),
    const DentalTreatment(
      id: 'crown',
      name: '烤瓷牙',
      category: '修复治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'all_ceramic',
      name: '全瓷牙',
      category: '修复治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'removable_denture',
      name: '活动牙',
      category: '修复治疗',
      isCommon: true,
    ),

    // 洁牙相关
    const DentalTreatment(
      id: 'scaling',
      name: '洁牙',
      category: '预防治疗',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'polishing',
      name: '抛光',
      category: '预防治疗',
      isCommon: true,
    ),

    // 拔牙相关
    const DentalTreatment(
      id: 'extraction',
      name: '拔牙',
      category: '口腔外科',
      isCommon: true,
    ),
    const DentalTreatment(
      id: 'wisdom_tooth_extraction',
      name: '智齿拔除',
      category: '口腔外科',
      isCommon: true,
    ),

    // 正畸治疗 - 向前移动
    const DentalTreatment(
      id: 'orthodontics',
      name: '正畸',
      category: '其它',
      isCommon: true,
    ),

    // 其它选项 - 新增分类
    const DentalTreatment(
      id: 'appointment_check',
      name: '预约检查',
      category: '其它',
      isCommon: true,
    ),
  ];

  // 按类别获取治疗项目
  static Map<String, List<DentalTreatment>> getTreatmentsByCategory() {
    Map<String, List<DentalTreatment>> result = {};

    for (var treatment in predefinedTreatments) {
      final category = treatment.category;
      final list = result.putIfAbsent(category, () => []);
      list.add(treatment);
    }

    return result;
  }

  // 获取常用治疗项目
  static List<DentalTreatment> getCommonTreatments() {
    return predefinedTreatments
        .where((treatment) => treatment.isCommon)
        .toList();
  }

  // 根据ID获取治疗项目
  static DentalTreatment? getTreatmentById(String id) {
    try {
      return predefinedTreatments.firstWhere((treatment) => treatment.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// 治疗项目选择对话框
class TreatmentSelectionDialog extends StatefulWidget {
  final List<String> selectedTreatments;
  final Function(List<String>) onConfirm;

  const TreatmentSelectionDialog({
    Key? key,
    required this.selectedTreatments,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<TreatmentSelectionDialog> createState() =>
      _TreatmentSelectionDialogState();
}

class _TreatmentSelectionDialogState extends State<TreatmentSelectionDialog> {
  late List<String> _selectedTreatments;
  int _currentTabIndex = 0;
  final Map<String, List<DentalTreatment>> _categorizedTreatments =
      DentalTreatmentManager.getTreatmentsByCategory();
  final List<String> _categories = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTreatments = List.from(widget.selectedTreatments);
    _categories.addAll(_categorizedTreatments.keys);
    // 移除牙周治疗分类
    _categories.remove('牙周治疗');
    // 移除基础诊疗分类
    _categories.remove('基础诊疗');
    // 移除正畸治疗分类
    _categories.remove('正畸治疗');

    // 重新排序分类，把其它放在最后
    if (_categories.contains('其它')) {
      _categories.remove('其它');

      // 根据指定顺序插入分类
      List<String> preferredOrder = [
        '根管治疗',
        '修复治疗',
        '预防治疗',
        '口腔外科',
        '其它',
      ];

      // 按照preferredOrder的顺序排序_categories
      _categories.sort((a, b) {
        int indexA = preferredOrder.indexOf(a);
        int indexB = preferredOrder.indexOf(b);
        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;
        return indexA.compareTo(indexB);
      });

      // 确保其它出现在正确位置
      if (!_categories.contains('其它')) {
        _categories.add('其它');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: context.tokens.cardBackground,
      elevation: 2,
      child: Container(
        width: 640,
        constraints: const BoxConstraints(
          minWidth: 600,
          maxWidth: 680,
          minHeight: 380,
          maxHeight: 420,
        ),
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.tokens.primaryAccent.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colors.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.medical_services,
                      color: context.colors.onPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '选择治疗项目',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onPrimary,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                            color: context.tokens.shadow.withValues(alpha: 0.26),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close,
                          color: context.colors.onPrimary, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 16,
                      tooltip: '关闭',
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ],
              ),
            ),
            // 中部主体：左右两栏布局
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // 左侧：分类列表
                    Container(
                      width: 150,
                      decoration: BoxDecoration(
                        color: context.tokens.pageBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.tokens.divider),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = _currentTabIndex == index;
                          return InkWell(
                            onTap: () =>
                                setState(() => _currentTabIndex = index),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.tokens.primaryAccent
                                        .withValues(alpha: 0.08)
                                    : context.tokens.cardBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isSelected
                                        ? context.tokens.primaryAccent
                                        : context.tokens.divider),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.label_rounded,
                                      size: 14,
                                      color: isSelected
                                          ? context.tokens.primaryAccent
                                          : context.tokens.textMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? context.tokens.primaryAccent
                                            : context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 右侧：搜索 + 项目网格 + 已选信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 搜索行（右侧不再显示已选统计，移动到底部专栏）
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v.trim()),
                                  decoration: InputDecoration(
                                    hintText: '搜索当前分类项目...',
                                    isDense: true,
                                    prefixIcon:
                                        const Icon(Icons.search, size: 18),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: context.tokens.cardBackground,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 原位置不再显示“已选”栏（移至底部按钮上方）
                          const SizedBox.shrink(),
                          const SizedBox(height: 6),
                          // 网格区（可伸缩高度，内部滚动 - 优先填满剩余空间避免溢出）
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: context.tokens.pageBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.tokens.divider),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final currentList = (_categorizedTreatments[
                                              _categories[_currentTabIndex]] ??
                                          [])
                                      .where((t) =>
                                          _searchQuery.isEmpty ||
                                          t.name.contains(_searchQuery))
                                      .toList();
                                  return SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: currentList.map((treatment) {
                                        final bool isSelected =
                                            _selectedTreatments
                                                .contains(treatment.name);
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedTreatments
                                                    .remove(treatment.name);
                                              } else {
                                                _selectedTreatments
                                                    .add(treatment.name);
                                              }
                                            });
                                          },
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 120),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? context.tokens.primaryAccent
                                                  : context.tokens.cardBackground,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: isSelected
                                                      ? context.tokens.primaryAccent
                                                      : context.tokens.divider),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                          color: context
                                                              .tokens
                                                              .primaryAccent
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          blurRadius: 6,
                                                          offset: const Offset(
                                                              0, 2))
                                                    ]
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  treatment.name,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isSelected
                                                          ? context.colors.onPrimary
                                                          : context.colors.onSurfaceVariant),
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                      Icons.check_rounded,
                                                      size: 14,
                                                      color: context.colors.onPrimary),
                                                ]
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 移至底部按钮上方的固定高度“已选”栏
                          Container(
                            decoration: BoxDecoration(
                              color: context.tokens.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.tokens.divider),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            constraints: const BoxConstraints(
                                minHeight: 72, maxHeight: 84),
                            child: Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 16, color: Colors.green.shade600),
                                    const SizedBox(width: 6),
                                    Text('已选 ${_selectedTreatments.length}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w700)),
                                    if (_selectedTreatments.isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedTreatments.clear()),
                                        child: Text('清空',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: context.tokens.primaryAccent,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: _selectedTreatments.map((t) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: context.tokens.primaryAccent
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: context.tokens.primaryAccent),
                                          ),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            onTap: () {
                                              setState(() {
                                                _selectedTreatments.remove(t);
                                              });
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(t,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: context
                                                              .tokens
                                                              .primaryAccent)),
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.close,
                                                      size: 14,
                                                      color: context.tokens.primaryAccent),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部按钮（更紧凑，贴近上方“已选”栏）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.tokens.pageBackground,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: context.tokens.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(_selectedTreatments);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.tokens.primaryAccent,
                      foregroundColor: context.colors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor:
                          context.tokens.primaryAccent.withValues(alpha: 0.3),
                    ),
                    child: const Text('确定',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
