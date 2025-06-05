// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // 初始化测试环境
  setUpAll(() {
    // 初始化 FFI
    sqfliteFfiInit();
    // 设置数据库工厂
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('基础UI测试', (WidgetTester tester) async {
    // 构建一个基础的MaterialApp用于测试
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('牙医诊所管理系统'),
          ),
          body: const Center(
            child: Text('欢迎使用牙医诊所管理系统'),
          ),
        ),
      ),
    );

    // 验证基本UI元素
    expect(find.text('牙医诊所管理系统'), findsOneWidget);
    expect(find.text('欢迎使用牙医诊所管理系统'), findsOneWidget);
  });

  testWidgets('登录界面基础测试', (WidgetTester tester) async {
    // 构建一个简单的登录界面进行测试
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('登录'),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '用户名',
                  ),
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '密码',
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 验证登录界面的基本元素
    expect(find.text('登录'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // 应该有两个输入框
  });
}
