import 'package:flutter/material.dart';

// 定义牙齿图表类
class DentalChart {
  final TextEditingController topLeftController = TextEditingController();
  final TextEditingController topRightController = TextEditingController();
  final TextEditingController bottomLeftController = TextEditingController();
  final TextEditingController bottomRightController = TextEditingController();
  final TextEditingController noteController =
      TextEditingController(); // 添加备注控制器

  String topLeft = '';
  String topRight = '';
  String bottomLeft = '';
  String bottomRight = '';
  String note = ''; // 添加备注字段

  void dispose() {
    topLeftController.dispose();
    topRightController.dispose();
    bottomLeftController.dispose();
    bottomRightController.dispose();
    noteController.dispose(); // 释放备注控制器
  }
}

// 定义牙齿图表行类
class DentalChartRow {
  int index;
  DateTime date;
  String? createdByDoctor; // 创建此牙齿状况的医生姓名
  DentalChart chart1 = DentalChart();
  DentalChart chart2 = DentalChart();
  DentalChart chart3 = DentalChart();

  DentalChartRow({
    required this.index,
    required this.date,
    this.createdByDoctor,
  });

  void dispose() {
    chart1.dispose();
    chart2.dispose();
    chart3.dispose();
  }
}
