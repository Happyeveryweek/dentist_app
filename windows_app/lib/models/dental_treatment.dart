import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    DentalTreatment(
      id: 'root_canal_opening',
      name: '根管开髓',
      category: '根管治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'nerve_killing',
      name: '封药',
      category: '根管治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'root_canal_preparation',
      name: '根管预备',
      category: '根管治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'root_canal_filling',
      name: '根管填充',
      category: '根管治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'root_canal_disinfection',
      name: '根管消毒',
      category: '根管治疗',
      isCommon: true,
    ),

    // 补牙相关
    DentalTreatment(
      id: 'filling',
      name: '补牙',
      category: '修复治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'composite_resin_filling',
      name: '复合树脂充填',
      category: '修复治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'glass_ionomer_filling',
      name: '玻璃离子充填',
      category: '修复治疗',
      isCommon: false,
    ),
    DentalTreatment(
      id: 'crown',
      name: '烤瓷牙',
      category: '修复治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'all_ceramic',
      name: '全瓷牙',
      category: '修复治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'removable_denture',
      name: '活动牙',
      category: '修复治疗',
      isCommon: true,
    ),

    // 洁牙相关
    DentalTreatment(
      id: 'scaling',
      name: '洁牙',
      category: '预防治疗',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'polishing',
      name: '抛光',
      category: '预防治疗',
      isCommon: true,
    ),

    // 拔牙相关
    DentalTreatment(
      id: 'extraction',
      name: '拔牙',
      category: '口腔外科',
      isCommon: true,
    ),
    DentalTreatment(
      id: 'wisdom_tooth_extraction',
      name: '智齿拔除',
      category: '口腔外科',
      isCommon: true,
    ),

    // 正畸治疗 - 向前移动
    DentalTreatment(
      id: 'orthodontics',
      name: '正畸',
      category: '其它',
      isCommon: true,
    ),

    // 其它选项 - 新增分类
    DentalTreatment(
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
      if (!result.containsKey(treatment.category)) {
        result[treatment.category] = [];
      }
      result[treatment.category]!.add(treatment);
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
      child: Container(
        // 调整对话框整体宽度
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: BoxConstraints(
          minWidth: 480,
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          minHeight: 250,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Text(
                '选择治疗项目',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            // 调整菜单栏布局，确保"其它"不被遮挡
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min, // 让Row只占用必要的空间
                  children: _categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    final bool isSelected = _currentTabIndex == index;
                    final bool isLast =
                        index == _categories.length - 1; // 检查是否为最后一项

                    // 为最后一项（"其它"）添加额外右侧内边距，确保完全显示
                    EdgeInsets padding = isLast
                        ? const EdgeInsets.only(left: 4.0, right: 8.0)
                        : const EdgeInsets.symmetric(horizontal: 4.0);

                    return Padding(
                      padding: padding,
                      child: ChoiceChip(
                        label: Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _currentTabIndex = index;
                            });
                          }
                        },
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        selectedColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6), // 合理的内边距
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact, // 使用紧凑视觉密度，避免过宽
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            // 治疗项目列表 - 使用可滚动区域但高度自适应
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.3, // 减小列表最大高度
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8), // 减小内边距
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // 增加列数以显示更多项
                    childAspectRatio: 2.2, // 调整宽高比
                    crossAxisSpacing: 8, // 减小间距
                    mainAxisSpacing: 8, // 减小间距
                  ),
                  itemCount:
                      _categorizedTreatments[_categories[_currentTabIndex]]
                              ?.length ??
                          0,
                  itemBuilder: (context, index) {
                    final treatment = _categorizedTreatments[
                        _categories[_currentTabIndex]]![index];
                    final bool isSelected =
                        _selectedTreatments.contains(treatment.name);
                    final Color primaryColor = Theme.of(context).primaryColor;

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)), // 减小圆角
                      elevation: 0,
                      margin: EdgeInsets.zero, // 移除外边距
                      color: isSelected
                          ? primaryColor.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.05),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6), // 减小圆角
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTreatments.remove(treatment.name);
                            } else {
                              _selectedTreatments.add(treatment.name);
                            }
                          });
                        },
                        child: Stack(
                          children: [
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0), // 减小内边距
                                child: Text(
                                  treatment.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13, // 减小字体大小
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? primaryColor
                                        : Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                  ),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 2, // 调整位置
                                right: 2, // 调整位置
                                child: Icon(
                                  Icons.check_circle,
                                  color: primaryColor,
                                  size: 14, // 减小图标大小
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 已选项目预览
            if (_selectedTreatments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 6.0), // 减小内边距
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已选项目:',
                      style: TextStyle(
                        fontSize: 13, // 减小字体大小
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4), // 减小间距
                    Wrap(
                      spacing: 4, // 减小间距
                      runSpacing: 4, // 减小间距
                      children: _selectedTreatments
                          .map((treatment) => Chip(
                                label: Text(
                                  treatment,
                                  style: TextStyle(
                                    fontSize: 12, // 减小字体大小
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                deleteIcon:
                                    const Icon(Icons.close, size: 14), // 减小图标大小
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 4), // 减小内边距
                                padding: EdgeInsets.zero, // 移除内边距
                                onDeleted: () {
                                  setState(() {
                                    _selectedTreatments.remove(treatment);
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(12.0), // 减小内边距
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6), // 减小内边距
                    ),
                    child: Text('取消', style: TextStyle(fontSize: 14)), // 减小字体大小
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(_selectedTreatments);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6), // 减小内边距
                    ),
                    child: Text('确定', style: TextStyle(fontSize: 14)), // 减小字体大小
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
