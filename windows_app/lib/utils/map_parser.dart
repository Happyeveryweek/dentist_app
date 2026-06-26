import 'log_manager.dart';

/// 类型安全的 Map 解析工具。
///
/// 用于替代 `map['key']!` / `map['key'] as T` 等不安全写法，
/// 在模型 `fromMap` 阶段就把外部数据（数据库/网络/文件）校验为合法 Dart 对象。
class MapParser {
  final Map<String, dynamic> _map;
  final String _context;

  MapParser(this._map, {required String context}) : _context = context;

  /// 解析可选字段。字段缺失或解析失败时返回 null。
  T? optional<T>(String key, T? Function(dynamic value) parser) {
    final value = _map[key];
    if (value == null) return null;
    try {
      return parser(value);
    } catch (e) {
      LogManager.w(
        'MapParser',
        '$_context.$key 解析失败，已忽略该字段',
        error: e,
      );
      return null;
    }
  }

  /// 解析必填字段。字段缺失或解析失败时抛出 [FormatException]。
  T required<T>(String key, T Function(dynamic value) parser) {
    final value = _map[key];
    if (value == null) {
      throw FormatException('$_context.$key 不能为空');
    }
    try {
      return parser(value);
    } catch (e) {
      throw FormatException(
        '$_context.$key 解析失败: value=$value, error=$e',
      );
    }
  }

  /// 解析字符串，支持默认值。
  String string(String key, {String? defaultValue}) =>
      optional(key, (v) => v.toString()) ?? defaultValue ?? '';

  /// 解析整数，支持默认值。
  int integer(String key, {int? defaultValue}) =>
      optional(
        key,
        (v) => v is int ? v : int.parse(v.toString()),
      ) ??
      defaultValue ??
      0;

  /// 解析双精度浮点数，支持默认值。
  double decimal(String key, {double? defaultValue}) =>
      optional(
        key,
        (v) => v is double ? v : (v is num ? v.toDouble() : double.parse(v.toString())),
      ) ??
      defaultValue ??
      0.0;

  /// 解析可空的双精度浮点数。
  double? decimalOrNull(String key) => optional(
        key,
        (v) => v is double ? v : (v is num ? v.toDouble() : double.parse(v.toString())),
      );

  /// 解析布尔值，支持默认值。
  bool boolean(String key, {bool? defaultValue}) =>
      optional(
        key,
        (v) {
          if (v is bool) return v;
          if (v is int) return v != 0;
          final s = v.toString().toLowerCase();
          return s == 'true' || s == '1' || s == 'yes';
        },
      ) ??
      defaultValue ??
      false;

  /// 解析日期时间，支持多种输入类型。
  DateTime? dateTime(String key) => optional(
        key,
        (v) {
          if (v is DateTime) return v;
          if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
          return DateTime.parse(v.toString());
        },
      );

  /// 解析日期时间，字段缺失时返回 [fallback]。
  DateTime dateTimeOr(String key, DateTime fallback) =>
      dateTime(key) ?? fallback;

  /// 解析列表，元素类型由 [parser] 决定。
  List<T> list<T>(String key, T Function(dynamic value) parser) =>
      optional(
        key,
        (v) {
          if (v is List) {
            return v.map((e) => parser(e)).whereType<T>().toList();
          }
          if (v is String && v.isEmpty) return <T>[];
          throw FormatException('expected List, got ${v.runtimeType}');
        },
      ) ??
      <T>[];

  /// 解析 Map。
  Map<String, dynamic> map(String key) =>
      optional(
        key,
        (v) => v is Map<String, dynamic>
            ? v
            : (throw FormatException('expected Map, got ${v.runtimeType}')),
      ) ??
      <String, dynamic>{};
}

/// 模型解析异常，用于区分“数据格式错误”。
class ModelParseException implements Exception {
  final String message;
  ModelParseException(this.message);

  @override
  String toString() => 'ModelParseException: $message';
}
