import 'app_logger.dart';

/// 类型安全的 Map 解析工具。
///
/// 用于替代裸 `as` 转换和 `!` 断言，统一处理模型 `fromMap` 中的字段解析。
/// 必填字段缺失或解析失败时抛出 [FormatException]；
/// 可选字段缺失或解析失败时返回 null 并记录警告日志。
class MapParser {
  final Map<String, dynamic> _map;
  final String _context;

  MapParser(this._map, {required String context}) : _context = context;

  /// 解析可选字段。
  ///
  /// 字段为 null 时返回 null；解析失败时记录警告并返回 null。
  T? optional<T>(String key, T? Function(dynamic) parser) {
    final value = _map[key];
    if (value == null) return null;
    try {
      return parser(value);
    } catch (e) {
      AppLogger.warn('字段解析失败: $_context.$key, value=$value, error=$e');
      return null;
    }
  }

  /// 解析必填字段。
  ///
  /// 字段为 null 或解析失败时抛出 [FormatException]。
  T required<T>(String key, T Function(dynamic) parser) {
    final value = _map[key];
    if (value == null) {
      throw FormatException('$_context.$key 不能为空');
    }
    try {
      return parser(value);
    } catch (e) {
      throw FormatException('$_context.$key 解析失败: value=$value, error=$e');
    }
  }

  /// 解析字符串字段，为空或 null 时返回 [defaultValue]。
  String string(String key, {String defaultValue = ''}) =>
      optional(key, (v) => v.toString()) ?? defaultValue;

  /// 解析可选字符串字段。
  String? stringOptional(String key) =>
      optional(key, (v) => v.toString());

  /// 解析整数字段，为空或 null 时返回 [defaultValue]。
  int integer(String key, {int defaultValue = 0}) =>
      optional(key, _parseInt) ?? defaultValue;

  /// 解析可选整数字段。
  int? integerOptional(String key) => optional(key, _parseInt);

  /// 解析双精度浮点数字段。
  double doubleValue(String key, {double defaultValue = 0.0}) =>
      optional(key, _parseDouble) ?? defaultValue;

  /// 解析可选双精度浮点数字段。
  double? doubleOptional(String key) => optional(key, _parseDouble);

  /// 解析布尔字段。
  bool boolean(String key, {bool defaultValue = false}) =>
      optional(key, _parseBool) ?? defaultValue;

  /// 解析可选布尔字段。
  bool? booleanOptional(String key) => optional(key, _parseBool);

  /// 解析日期时间字段。
  DateTime dateTime(String key, {DateTime? defaultValue}) =>
      optional(key, _parseDateTime) ?? defaultValue ?? DateTime.now();

  /// 解析可选日期时间字段。
  DateTime? dateTimeOptional(String key) => optional(key, _parseDateTime);

  /// 解析列表字段。
  ///
  /// 字段为 null 或非 List 时返回空列表；解析失败的元素会被过滤。
  List<T> list<T>(String key, T Function(dynamic) parser) {
    final value = _map[key];
    if (value == null) return [];
    if (value is! List) {
      AppLogger.warn(
        '字段类型错误: $_context.$key, expected List, got ${value.runtimeType}',
      );
      return [];
    }
    return value.map(parser).whereType<T>().toList();
  }

  /// 解析可选列表字段。
  List<T>? listOptional<T>(String key, T Function(dynamic) parser) {
    final value = _map[key];
    if (value == null) return null;
    if (value is! List) {
      AppLogger.warn(
        '字段类型错误: $_context.$key, expected List, got ${value.runtimeType}',
      );
      return null;
    }
    return value.map(parser).whereType<T>().toList();
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.parse(value.toString());
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.parse(value.toString());
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true' || value == 1;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }
}
