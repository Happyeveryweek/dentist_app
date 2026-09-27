import 'package:dentist_app_windows/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('首页右上角日期包含年月日和星期', () {
    expect(
      formatClinicHeaderDate(DateTime(2026, 9, 27)),
      '2026年9月27日 周日',
    );
    expect(
      formatClinicHeaderDate(DateTime(2026, 1, 5)),
      '2026年1月5日 周一',
    );
  });
}
