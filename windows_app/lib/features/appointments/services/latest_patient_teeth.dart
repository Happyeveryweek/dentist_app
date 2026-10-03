import 'dart:convert';

import '../../../utils/log_manager.dart';

const int patientDentalChartCount = 3;

/// 预约牙位与患者牙齿状况对齐，至少显示三个十字。
List<Map<String, String>> normalizeAppointmentTeethData(
  Iterable<Map<String, String>>? teethData,
) {
  final normalized = <Map<String, String>>[];
  if (teethData != null) {
    for (final item in teethData) {
      normalized.add({
        'topLeft': item['topLeft'] ?? '',
        'topRight': item['topRight'] ?? '',
        'bottomLeft': item['bottomLeft'] ?? '',
        'bottomRight': item['bottomRight'] ?? '',
      });
    }
  }
  while (normalized.length < patientDentalChartCount) {
    normalized.add(_emptyToothChart());
  }
  return normalized;
}

/// 添加预约尚未选择患者时的空白牙位。
List<Map<String, String>> blankAppointmentTeethData() {
  return normalizeAppointmentTeethData(null);
}

/// 最新牙齿状况日期往后一周的早上 9 点。没有可解析记录时返回 null。
DateTime? appointmentDateTimeFromLatestDentalRecord(
  String? dentalConditionJson,
) {
  final recordDate = latestPatientDentalRecordDate(dentalConditionJson);
  if (recordDate == null) return null;
  final nextWeek = DateTime(recordDate.year, recordDate.month, recordDate.day)
      .add(const Duration(days: 7));
  return DateTime(nextWeek.year, nextWeek.month, nextWeek.day, 9);
}

/// 患者牙齿状况里最新一条记录的日期。同一天有多条时，与带入牙位的那一条一致。
DateTime? latestPatientDentalRecordDate(String? dentalConditionJson) {
  final data = _decodeDentalCondition(dentalConditionJson);
  if (data == null) return null;
  final latestIndex = _latestDentalRowIndex(data);
  if (latestIndex == null) return null;
  return _parseDentalDate(data['date-$latestIndex']);
}

/// 从患者牙齿状况中取出最新一条记录的十字牙位。
///
/// 只返回各十字的四个象限，不包含十字下方的说明。
/// 没有可解析记录时返回 null。
List<Map<String, String>>? latestPatientTeethForAppointment(
  String? dentalConditionJson,
) {
  final data = _decodeDentalCondition(dentalConditionJson);
  if (data == null) return null;

  final latestIndex = _latestDentalRowIndex(data);
  if (latestIndex == null) return null;

  return [
    for (var chart = 1; chart <= patientDentalChartCount; chart++)
      {
        'topLeft': _text(data['chart$chart-top-left-$latestIndex']),
        'topRight': _text(data['chart$chart-top-right-$latestIndex']),
        'bottomLeft': _text(data['chart$chart-bottom-left-$latestIndex']),
        'bottomRight': _text(data['chart$chart-bottom-right-$latestIndex']),
      },
  ];
}

Map<String, dynamic>? _decodeDentalCondition(String? dentalConditionJson) {
  if (dentalConditionJson == null || dentalConditionJson.trim().isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(dentalConditionJson);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  } catch (e) {
    LogManager.w('LatestPatientTeeth', '解析患者牙齿状况失败', error: e);
    return null;
  }
}

int? _latestDentalRowIndex(Map<String, dynamic> data) {
  int? latestIndex;
  DateTime? latestDate;

  for (final entry in data.entries) {
    if (!entry.key.startsWith('date-')) continue;
    final index = int.tryParse(entry.key.substring('date-'.length));
    if (index == null || index < 0) continue;
    final date = _parseDentalDate(entry.value);
    if (date == null) continue;

    final currentLatest = latestDate;
    final currentIndex = latestIndex;
    final isNewer = currentLatest == null || date.isAfter(currentLatest);
    final isSameDayEarlierRow = currentLatest != null &&
        currentIndex != null &&
        date.isAtSameMomentAs(currentLatest) &&
        index < currentIndex;
    if (isNewer || isSameDayEarlierRow) {
      latestDate = date;
      latestIndex = index;
    }
  }

  return latestIndex;
}

DateTime? _parseDentalDate(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final datePart = raw.split(RegExp(r'[ T]')).first.replaceAll('/', '-');
  final parsed = DateTime.tryParse(datePart);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _text(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

Map<String, String> _emptyToothChart() {
  return {
    'topLeft': '',
    'topRight': '',
    'bottomLeft': '',
    'bottomRight': '',
  };
}
