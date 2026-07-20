enum AppointmentStatus {
  scheduled('scheduled', '已预约'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  missed('missed', '未到诊');

  const AppointmentStatus(this.storageValue, this.displayName);
  final String storageValue;
  final String displayName;

  static AppointmentStatus? tryParse(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final status in values) {
      if (status.storageValue == normalized ||
          status.displayName == value?.trim()) {
        return status;
      }
    }
    return null;
  }

  static String normalizeStorageValue(String value) =>
      tryParse(value)?.storageValue ?? value;

  static String displayNameOf(String value) =>
      tryParse(value)?.displayName ?? value;
}
