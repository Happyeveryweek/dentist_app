/// 过敏类型常量定义
class AllergyTypes {
  /// 过敏类型映射
  static const Map<String, List<String>> allergies = {
    '药物过敏': [
      '青霉素',
      '头孢菌素',
      '磺胺类',
      '阿司匹林',
      '布洛芬',
      '利多卡因',
      '普鲁卡因',
      '碘伏',
      '碘酊',
      '氯己定',
      '甲硝唑',
      '红霉素',
      '四环素',
      '庆大霉素',
      '地塞米松',
      '氢化可的松',
    ],
    '食物过敏': [
      '海鲜',
      '虾蟹',
      '鱼类',
      '牛奶',
      '鸡蛋',
      '花生',
      '坚果',
      '大豆',
      '小麦',
      '芝麻',
      '水果',
      '蔬菜',
      '蜂蜜',
      '巧克力',
    ],
    '材料过敏': [
      '乳胶',
      '金属',
      '镍',
      '铬',
      '钴',
      '汞',
      '银汞合金',
      '复合树脂',
      '印模材料',
      '粘接剂',
      '漂白剂',
      '橡胶',
      '塑料',
    ],
    '环境过敏': [
      '花粉',
      '尘螨',
      '霉菌',
      '动物毛发',
      '化妆品',
      '香水',
      '洗涤剂',
      '消毒剂',
      '紫外线',
      '冷热刺激',
    ],
  };

  /// 获取所有过敏类型名称
  static List<String> get allAllergyTypes => allergies.keys.toList();

  /// 获取指定过敏类型的具体过敏原
  static List<String> getAllergens(String allergyType) {
    return allergies[allergyType] ?? [];
  }

  /// 检查是否为有效的过敏类型
  static bool isValidAllergyType(String allergyType) {
    return allergies.containsKey(allergyType);
  }

  /// 检查是否为有效的过敏原
  static bool isValidAllergen(String allergyType, String allergen) {
    final allergens = allergies[allergyType];
    return allergens != null && allergens.contains(allergen);
  }

  /// 获取过敏类型的显示名称（用于UI显示）
  static String getDisplayName(String allergyType) {
    return allergyType;
  }

  /// 获取所有过敏类型和过敏原的扁平化列表
  static List<String> getAllAllergyItems() {
    final List<String> allItems = [];
    allergies.forEach((type, allergens) {
      allItems.add(type);
      allItems.addAll(allergens.map((allergen) => '$type - $allergen'));
    });
    return allItems;
  }

  /// 根据搜索关键词过滤过敏类型
  static Map<String, List<String>> filterAllergies(String keyword) {
    if (keyword.isEmpty) return allergies;

    final Map<String, List<String>> filtered = {};
    allergies.forEach((type, allergens) {
      if (type.contains(keyword)) {
        filtered[type] = allergens;
      } else {
        final matchingAllergens =
            allergens.where((allergen) => allergen.contains(keyword)).toList();
        if (matchingAllergens.isNotEmpty) {
          filtered[type] = matchingAllergens;
        }
      }
    });
    return filtered;
  }

  /// 获取常见药物过敏原（用于快速选择）
  static List<String> get commonDrugAllergens => [
        '青霉素',
        '头孢菌素',
        '磺胺类',
        '利多卡因',
        '碘伏',
      ];

  /// 获取常见食物过敏原（用于快速选择）
  static List<String> get commonFoodAllergens => [
        '海鲜',
        '牛奶',
        '鸡蛋',
        '花生',
        '坚果',
      ];

  /// 获取牙科相关过敏原（影响牙科治疗）
  static List<String> get dentalRelatedAllergens => [
        '利多卡因',
        '普鲁卡因',
        '碘伏',
        '碘酊',
        '氯己定',
        '乳胶',
        '金属',
        '镍',
        '汞',
        '银汞合金',
        '复合树脂',
        '印模材料',
        '粘接剂',
      ];

  /// 检查是否为牙科相关过敏原
  static bool isDentalRelatedAllergen(String allergen) {
    return dentalRelatedAllergens.contains(allergen);
  }

  /// 获取过敏严重程度选项
  static List<String> get severityLevels => [
        '轻度',
        '中度',
        '重度',
        '过敏性休克',
      ];

  /// 获取过敏反应类型
  static List<String> get reactionTypes => [
        '皮疹',
        '瘙痒',
        '红肿',
        '呼吸困难',
        '恶心呕吐',
        '腹泻',
        '头晕',
        '心悸',
        '血压下降',
        '意识丧失',
      ];
}
