enum AppModule {
  dashboard('dashboard'),
  patients('patients'),
  appointments('appointments'),
  financial('financial'),
  materials('materials'),
  purchase('purchase'),
  medicalRecords('medical_records'),
  users('users'),
  settings('settings');

  const AppModule(this.id);
  final String id;

  static AppModule? tryParse(String? value) {
    for (final module in values) {
      if (module.id == value) return module;
    }
    return null;
  }

  /// 病历使用历史配置键 `medical`，并继续跟随患者数据源。
  String? get dataSourceConfigKey => switch (this) {
        AppModule.dashboard || AppModule.settings => null,
        AppModule.medicalRecords => 'medical',
        _ => id,
      };
}
