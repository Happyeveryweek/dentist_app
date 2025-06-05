// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app/providers/settings_provider.dart';
import 'package:dentist_app/main.dart';

void main() {
  testWidgets('基础功能测试', (WidgetTester tester) async {
    // 创建一个SettingsProvider实例
    final settingsProvider = SettingsProvider();
    await settingsProvider.init();

    // 构建应用并触发一帧渲染
    await tester.pumpWidget(const MyApp());

    // 验证应用是否正确加载
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
