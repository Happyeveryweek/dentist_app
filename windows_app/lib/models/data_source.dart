enum DataSourceType {
  sqlite('sqlite'),
  mysql('mysql');

  const DataSourceType(this.storageValue);
  final String storageValue;

  static DataSourceType? tryParse(String? value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }
    return null;
  }

  static DataSourceType parseOrThrow(String? value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(value, 'value', '未知数据源类型');
    }
    return parsed;
  }
}

enum DataSourceMode {
  global('global'),
  modular('modular');

  const DataSourceMode(this.storageValue);
  final String storageValue;

  static DataSourceMode? tryParse(String? value) {
    for (final mode in values) {
      if (mode.storageValue == value) return mode;
    }
    return null;
  }

  static DataSourceMode parseOrThrow(String? value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(value, 'value', '未知数据源模式');
    }
    return parsed;
  }
}

/// 将协议边界的稳定字符串转换为类型化业务判断。
extension DataSourceValueParsing on String? {
  DataSourceType? get asDataSourceType => DataSourceType.tryParse(this);

  DataSourceMode? get asDataSourceMode => DataSourceMode.tryParse(this);

  bool get isSqliteDataSource => asDataSourceType == DataSourceType.sqlite;

  bool get isMySqlDataSource => asDataSourceType == DataSourceType.mysql;

  bool get isGlobalDataSourceMode => asDataSourceMode == DataSourceMode.global;

  bool get isModularDataSourceMode =>
      asDataSourceMode == DataSourceMode.modular;
}
