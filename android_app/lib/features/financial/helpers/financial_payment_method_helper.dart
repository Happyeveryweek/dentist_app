class FinancialPaymentMethodHelper {
  static const String nonePaymentMethod = '__none__';
  static const String defaultPaymentMethod = 'wechat';

  static const List<String> supportedMethods = <String>[
    'wechat',
    'alipay',
    'cash',
  ];

  static const List<String> dropdownMethods = <String>[
    nonePaymentMethod,
    ...supportedMethods,
  ];

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == nonePaymentMethod) {
      return nonePaymentMethod;
    }
    if (normalized == null || normalized.isEmpty) {
      return defaultPaymentMethod;
    }
    if (normalized.contains('wechat') || normalized.contains('微信')) {
      return 'wechat';
    }
    if (normalized.contains('alipay') || normalized.contains('支付宝')) {
      return 'alipay';
    }
    if (normalized.contains('cash') || normalized.contains('现金')) {
      return 'cash';
    }
    if (supportedMethods.contains(normalized)) {
      return normalized;
    }
    return defaultPaymentMethod;
  }

  static String uiValue(String? value) {
    if (!_hasValue(value)) {
      return nonePaymentMethod;
    }
    return normalize(value);
  }

  static String? toStorageValue(String? value) {
    if (value == null || value == nonePaymentMethod) {
      return null;
    }
    return normalize(value);
  }

  static String displayName(String? value) {
    if (!_hasValue(value)) {
      return '';
    }
    if (normalize(value) == nonePaymentMethod) {
      return '无';
    }
    switch (normalize(value)) {
      case 'alipay':
        return '支付宝';
      case 'cash':
        return '现金';
      case 'wechat':
      default:
        return '微信';
    }
  }

  static String displayNameOrDefault(String? value) {
    final name = displayName(value);
    return name.isEmpty ? displayName(defaultPaymentMethod) : name;
  }

  static String iconAssetPath(String? value) {
    if (!_hasValue(value)) {
      return '';
    }
    if (normalize(value) == nonePaymentMethod) {
      return '';
    }
    switch (normalize(value)) {
      case 'alipay':
        return 'assets/icons/支付宝.png';
      case 'cash':
        return 'assets/icons/现金.png';
      case 'wechat':
      default:
        return 'assets/icons/微信.png';
    }
  }

  static String? iconAssetPathOrNull(String? value) {
    final path = iconAssetPath(value);
    return path.isEmpty ? null : path;
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
