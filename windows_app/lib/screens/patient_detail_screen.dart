import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../providers/database_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/patient_form_dialog.dart';
import '../widgets/appointment_form_dialog.dart';
import 'patients_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final int patientId;

  const PatientDetailScreen({
    Key? key,
    required this.patientId,
  }) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Patient? _patient;
  List<Appointment> _appointments = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPatientData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 读取患者数据
      final patient = await dbProvider.getPatient(widget.patientId);
      if (patient == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取患者数据')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // 读取患者预约数据
      final appointments =
          await dbProvider.getAppointmentsByPatient(widget.patientId);

      if (mounted) {
        setState(() {
          _patient = patient;
          _appointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据错误: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_patient?.name ?? '患者详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑患者',
            onPressed: _isLoading ? null : _editPatient,
          ),
        ],
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '基本信息'),
                  Tab(text: '预约记录'),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPatientInfoTab(),
                _buildAppointmentsTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              heroTag: 'patient_detail_add_button',
              onPressed: _addAppointment,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildPatientInfoTab() {
    if (_patient == null) {
      return const Center(child: Text('无法加载患者信息'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部概览卡片 - 更紧凑的设计
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 患者头像/标识
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _patient!.gender == '女'
                          ? const Color(0xFFFCE4EC) // 非常浅的粉红色
                          : const Color(0xFFE3F2FD), // 非常浅的蓝色
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _patient!.gender == '女'
                            ? Colors.pink.shade200
                            : Colors.blue.shade200,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _patient!.name.isNotEmpty ? _patient!.name[0] : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _patient!.gender == '女'
                              ? Colors.pink.shade400
                              : Colors.blue.shade400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 患者主要信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 姓名
                        Row(
                          children: [
                            Text(
                              _patient!.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _patient!.gender == '女'
                                    ? Colors.pink.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _patient!.gender == '女'
                                        ? Icons.female
                                        : Icons.male,
                                    size: 16,
                                    color: _patient!.gender == '女'
                                        ? Colors.pink.shade300
                                        : Colors.blue.shade300,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _patient!.gender,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _patient!.gender == '女'
                                          ? Colors.pink.shade400
                                          : Colors.blue.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${_patient!.age}岁',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            // 首诊日期显示
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: 14,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '首诊: ${DateFormat('yyyy-MM-dd').format(_patient!.first_visit_date)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 电话信息
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              _patient!.displayPhone(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // 身份证号信息
                        if (_patient!.identification_number != null)
                          Row(
                            children: [
                              Icon(Icons.credit_card,
                                  size: 16, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                _patient!.identification_number!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 用分区标签分割内容
          _buildSectionHeader('个人信息', Icons.person, const Color(0xFF2ecc71)),
          // 个人信息卡片 - 绿色主题，多个信息在同一行
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.green.withOpacity(0.1)),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 第一行：病历号和主治医生（移除身份证号）
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 病历号部分 - 固定宽度保证对齐
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ecc71).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.badge,
                                size: 20,
                                color: Color(0xFF2ecc71),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '病历号',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _patient!.medical_record_number
                                            ?.toString() ??
                                        '无',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 主治医生部分 - 固定宽度保证对齐
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ecc71).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medical_services,
                                size: 20,
                                color: Color(0xFF2ecc71),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '主治医生',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _patient!.doctor ?? '无',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 第二行：电话和住址
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 电话部分
                      Expanded(
                        child: _patient!.phoneList.isNotEmpty
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2ecc71)
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.phone,
                                      size: 20,
                                      color: Color(0xFF2ecc71),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '联系电话',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '主要电话: ${_patient!.mainPhone}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            if (_patient!.phoneList.length >
                                                1) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '备用电话: ${_patient!.backupPhone}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      // 住址部分
                      Expanded(
                        child: _patient!.address != null &&
                                _patient!.address!.isNotEmpty
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2ecc71)
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.home,
                                      size: 20,
                                      color: Color(0xFF2ecc71),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '住址',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _patient!.address!,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 牙齿状况和治疗分区
          _buildSectionHeader(
              '诊疗信息', Icons.medical_information, const Color(0xFFe74c3c)),
          // 诊疗信息卡片 - 红色主题
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.withOpacity(0.1)),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDentalCondition(),
                  if (_patient!.dental_condition != null &&
                      _patient!.dental_condition!.isNotEmpty &&
                      _patient!.treatment_items != null &&
                      _patient!.treatment_items!.isNotEmpty)
                    const Divider(),
                  if (_patient!.treatment_items != null &&
                      _patient!.treatment_items!.isNotEmpty)
                    _buildDetailItem(
                      '治疗项目',
                      _patient!.treatment_items!,
                      Icons.medical_services,
                      const Color(0xFFe74c3c),
                    ),
                  if (_patient!.dental_condition == null &&
                      _patient!.treatment_items == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          '暂无诊疗信息',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 信息标签小部件
  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 详细信息项目部件
  Widget _buildDetailItem(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 分区标题小部件
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDentalCondition() {
    if (_patient!.dental_condition == null ||
        _patient!.dental_condition!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('暂无牙齿状况记录'),
      );
    }

    try {
      // 为MySQL和SQLite数据来源处理不同的数据类型
      Map<String, dynamic> dentalCharts;

      if (Provider.of<DatabaseProvider>(context, listen: false)
              .dataSourceType ==
          'mysql') {
        // MySQL数据源
        print('使用MySQL数据源解析dental_condition');

        // 处理dental_condition字段的数据
        final dynamic rawData = _patient!.dental_condition;
        String jsonStr = '';

        try {
          // 根据实际类型进行处理
          if (rawData is List<int>) {
            // 已经是List<int>类型，直接解码
            jsonStr = utf8.decode(rawData, allowMalformed: true);
          } else if (rawData is Uint8List) {
            // 是Uint8List类型，直接解码
            jsonStr = utf8.decode(rawData, allowMalformed: true);
          } else if (rawData is String) {
            // 是String类型，直接使用
            jsonStr = rawData;
          } else {
            // 其他类型，尝试toString()
            jsonStr = rawData.toString();
          }

          print(
              '处理后的dental_condition: ${jsonStr.length > 50 ? jsonStr.substring(0, 50) + "..." : jsonStr}');
        } catch (e) {
          print('转换dental_condition错误: $e');
          // 转换失败，使用toString作为后备方案
          jsonStr = rawData != null ? rawData.toString() : '{}';
        }

        // 尝试解析JSON字符串
        try {
          final decodedData = jsonDecode(jsonStr);
          if (decodedData is Map) {
            dentalCharts = Map<String, dynamic>.from(decodedData);

            // 额外处理可能存在的编码问题
            if (Provider.of<DatabaseProvider>(context, listen: false)
                    .dataSourceType ==
                'mysql') {
              _fixChineseEncodingInMap(dentalCharts);
            }
          } else {
            throw FormatException('期望Map类型，实际为: ${decodedData.runtimeType}');
          }
        } catch (e) {
          print('JSON解析错误: $e，尝试修复格式问题');

          // 尝试清理JSON字符串中可能存在的问题字符
          final cleanedJson =
              jsonStr.replaceAll(RegExp(r'[\u0000-\u001F]'), '');

          try {
            final decodedData = jsonDecode(cleanedJson);
            if (decodedData is Map) {
              dentalCharts = Map<String, dynamic>.from(decodedData);

              // 额外处理可能存在的编码问题
              if (Provider.of<DatabaseProvider>(context, listen: false)
                      .dataSourceType ==
                  'mysql') {
                _fixChineseEncodingInMap(dentalCharts);
              }
            } else {
              throw FormatException(
                  '清理后期望Map类型，实际为: ${decodedData.runtimeType}');
            }
          } catch (e2) {
            print('清理后JSON解析仍然失败: $e2');
            // 尝试最后的修复方法
            try {
              // 对于MySQL，尝试手动处理JSON字符串中的编码问题
              if (Provider.of<DatabaseProvider>(context, listen: false)
                      .dataSourceType ==
                  'mysql') {
                String fixedJson = _fixJsonEncoding(jsonStr);
                final decodedData = jsonDecode(fixedJson);
                if (decodedData is Map) {
                  dentalCharts = Map<String, dynamic>.from(decodedData);
                  _fixChineseEncodingInMap(dentalCharts);
                } else {
                  throw FormatException(
                      '修复后期望Map类型，实际为: ${decodedData.runtimeType}');
                }
              } else {
                // 解析失败，使用空Map
                dentalCharts = {};
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('牙齿状况数据格式错误: $e2'),
                );
              }
            } catch (e3) {
              print('所有修复尝试均失败: $e3');
              // 解析失败，使用空Map
              dentalCharts = {};
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('牙齿状况数据格式错误: $e3'),
              );
            }
          }
        }
      } else {
        // SQLite数据源
        dentalCharts = _patient!.dentalCharts;
      }

      if (dentalCharts.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('暂无牙齿状况记录'),
        );
      }

      // 找出有多少行数据
      int rowCount = 0;
      for (String key in dentalCharts.keys) {
        if (key.startsWith('date-')) {
          int index = int.tryParse(key.split('-').last) ?? 0;
          rowCount = rowCount > index ? rowCount : index + 1;
        }
      }

      List<Widget> chartRows = [];
      for (int i = 0; i < rowCount; i++) {
        // 获取日期
        String rawDateStr = dentalCharts['date-$i'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        // 确保日期字符串只包含年月日，去掉时分秒
        String dateStr;
        try {
          // 尝试解析日期字符串，然后重新格式化为年月日
          DateTime date;
          if (rawDateStr.contains('-')) {
            // 尝试解析包含"-"的日期格式
            date = DateTime.parse(rawDateStr.split(' ')[0]); // 只取日期部分
          } else if (rawDateStr.contains('/')) {
            // 尝试解析包含"/"的日期格式
            date = DateFormat('yyyy/MM/dd')
                .parse(rawDateStr.split(' ')[0]); // 只取日期部分
          } else {
            // 其他格式
            date = DateTime.parse(rawDateStr);
          }
          // 统一格式化为年-月-日
          dateStr = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          // 解析失败时使用原始字符串
          print('日期解析错误: $e，使用原始日期字符串');
          dateStr = rawDateStr;
        }

        // 获取各位置数据并确保是字符串类型
        // 第一个图表
        String chart1TopLeft =
            _ensureString(dentalCharts['chart1-top-left-$i']);
        String chart1TopRight =
            _ensureString(dentalCharts['chart1-top-right-$i']);
        String chart1BottomLeft =
            _ensureString(dentalCharts['chart1-bottom-left-$i']);
        String chart1BottomRight =
            _ensureString(dentalCharts['chart1-bottom-right-$i']);
        String chart1Note = _ensureString(dentalCharts['chart1-note-$i']);

        // 第二个图表
        String chart2TopLeft =
            _ensureString(dentalCharts['chart2-top-left-$i']);
        String chart2TopRight =
            _ensureString(dentalCharts['chart2-top-right-$i']);
        String chart2BottomLeft =
            _ensureString(dentalCharts['chart2-bottom-left-$i']);
        String chart2BottomRight =
            _ensureString(dentalCharts['chart2-bottom-right-$i']);
        String chart2Note = _ensureString(dentalCharts['chart2-note-$i']);

        // 第三个图表
        String chart3TopLeft =
            _ensureString(dentalCharts['chart3-top-left-$i']);
        String chart3TopRight =
            _ensureString(dentalCharts['chart3-top-right-$i']);
        String chart3BottomLeft =
            _ensureString(dentalCharts['chart3-bottom-left-$i']);
        String chart3BottomRight =
            _ensureString(dentalCharts['chart3-bottom-right-$i']);
        String chart3Note = _ensureString(dentalCharts['chart3-note-$i']);

        chartRows.add(
          _buildDentalChartCard(
            dateStr,
            chart1TopLeft,
            chart1TopRight,
            chart1BottomLeft,
            chart1BottomRight,
            chart1Note,
            chart2TopLeft,
            chart2TopRight,
            chart2BottomLeft,
            chart2BottomRight,
            chart2Note,
            chart3TopLeft,
            chart3TopRight,
            chart3BottomLeft,
            chart3BottomRight,
            chart3Note,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 添加标题
            Row(
              children: [
                const Icon(Icons.medical_services,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '牙齿状况',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 添加滚动视图来显示多行牙齿状况
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: chartRows.length > 2 ? 400 : 200,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: chartRows,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('解析牙齿状况数据出错: $e'),
      );
    }
  }

  // 确保值为字符串类型的辅助方法
  String _ensureString(dynamic value) {
    if (value == null) return '';

    try {
      if (value is List<int>) {
        // 二进制数据转换为字符串，尝试多种编码方式
        try {
          final utf8Result = utf8.decode(value, allowMalformed: true);
          if (_containsChinese(utf8Result)) {
            return utf8Result;
          }

          // 尝试其他编码
          if (Provider.of<DatabaseProvider>(context, listen: false)
                  .dataSourceType ==
              'mysql') {
            // MySQL默认通常是latin1或utf8
            try {
              // 尝试转换为latin1编码字符串再转回utf8
              final latin1Result = String.fromCharCodes(value);
              if (_containsChinese(latin1Result)) {
                return latin1Result;
              }
            } catch (e) {
              print('latin1转换失败: $e');
            }
          }

          return utf8Result;
        } catch (e) {
          print('二进制数据转换为字符串失败: $e');
          // 尝试直接从字符码转换
          return String.fromCharCodes(value);
        }
      } else if (value is Uint8List) {
        // Uint8List转换为字符串，尝试多种编码方式
        try {
          final utf8Result = utf8.decode(value, allowMalformed: true);
          if (_containsChinese(utf8Result)) {
            return utf8Result;
          }

          // 尝试其他编码
          if (Provider.of<DatabaseProvider>(context, listen: false)
                  .dataSourceType ==
              'mysql') {
            // 尝试转换为latin1编码字符串
            try {
              final latin1Result = String.fromCharCodes(value);
              if (_containsChinese(latin1Result)) {
                return latin1Result;
              }
            } catch (e) {
              print('latin1转换失败: $e');
            }
          }

          return utf8Result;
        } catch (e) {
          print('Uint8List转换为字符串失败: $e');
          // 尝试直接从字符码转换
          return String.fromCharCodes(value);
        }
      } else if (value is String) {
        // 对已经是字符串的值检查是否需要重新解码
        if (Provider.of<DatabaseProvider>(context, listen: false)
                    .dataSourceType ==
                'mysql' &&
            !_containsChinese(value) &&
            _containsEncodedBytes(value)) {
          try {
            // 检测到可能是编码问题的字符串，尝试重新解码
            List<int> bytes = value.codeUnits;
            final decodedString = utf8.decode(bytes, allowMalformed: true);
            if (_containsChinese(decodedString)) {
              return decodedString;
            }
          } catch (e) {
            print('字符串重新解码失败: $e');
          }
        }
        return value;
      }
    } catch (e) {
      print('字符串处理异常: $e');
    }

    // 默认返回toString结果
    return value.toString();
  }

  // 检测字符串是否包含中文字符
  bool _containsChinese(String text) {
    // 中文Unicode范围大致为\u4e00-\u9fff
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  // 检测字符串是否可能包含编码问题的字节
  bool _containsEncodedBytes(String text) {
    // 检查是否包含常见的非ASCII字符但又不是中文
    return RegExp(r'[\u0080-\u00ff]').hasMatch(text);
  }

  Widget _buildDentalChartCard(
    String dateStr,
    String chart1TopLeft,
    String chart1TopRight,
    String chart1BottomLeft,
    String chart1BottomRight,
    String chart1Note,
    String chart2TopLeft,
    String chart2TopRight,
    String chart2BottomLeft,
    String chart2BottomRight,
    String chart2Note,
    String chart3TopLeft,
    String chart3TopRight,
    String chart3BottomLeft,
    String chart3BottomRight,
    String chart3Note,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 日期显示
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 图表部分
            Expanded(
              child: Row(
                children: [
                  // 第一个牙齿图表
                  Expanded(
                    child: _buildReadOnlyCrossChart(
                      chart1TopLeft,
                      chart1TopRight,
                      chart1BottomLeft,
                      chart1BottomRight,
                      chart1Note,
                    ),
                  ),
                  const SizedBox(width: 8), // 减少间距
                  // 第二个牙齿图表
                  Expanded(
                    child: _buildReadOnlyCrossChart(
                      chart2TopLeft,
                      chart2TopRight,
                      chart2BottomLeft,
                      chart2BottomRight,
                      chart2Note,
                    ),
                  ),
                  const SizedBox(width: 8), // 间距
                  // 第三个牙齿图表
                  Expanded(
                    child: _buildReadOnlyCrossChart(
                      chart3TopLeft,
                      chart3TopRight,
                      chart3BottomLeft,
                      chart3BottomRight,
                      chart3Note,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 新增方法：构建只读的十字图表，与表单中样式一致
  Widget _buildReadOnlyCrossChart(
    String topLeft,
    String topRight,
    String bottomLeft,
    String bottomRight,
    String note,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 80, // 从100减少到80
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Stack(
            children: [
              // 十字线 - 横线
              Center(
                child: Container(
                  width: double.infinity,
                  height: 1.5,
                  color: Colors.blue.shade300,
                ),
              ),
              // 十字线 - 竖线（高度减少）
              Center(
                child: Container(
                  width: 1.5,
                  height: 50, // 从66减少到50
                  color: Colors.blue.shade300,
                ),
              ),

              // 四个象限的文本显示
              Column(
                children: [
                  // 上排 - 左上和右上
                  Expanded(
                    child: Row(
                      children: [
                        // 左上象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(
                                right: 4, top: 18), // 从25减少到18
                            child: Text(
                              topLeft,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        // 右上象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(
                                left: 4, top: 18), // 从25减少到18
                            child: Text(
                              topRight,
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 下排 - 左下和右下
                  Expanded(
                    child: Row(
                      children: [
                        // 左下象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(
                                right: 4, bottom: 18), // 从25减少到18
                            child: Text(
                              bottomLeft,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        // 右下象限
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(
                                left: 4, bottom: 18), // 从25减少到18
                            child: Text(
                              bottomRight,
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 备注显示区域 - 固定高度30，与编辑页保持一致
        Container(
          margin: const EdgeInsets.only(top: 5),
          height: 30, // 固定高度确保一致
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 25.0), // 减少内边距适应三列布局
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // 内容底部对齐
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 如果有备注内容就显示，占据上部空间
              if (note.isNotEmpty)
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      note,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              // 始终显示横线在底部
              Container(
                height: 1.5,
                width: double.infinity,
                color: Colors.blue.shade300,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _fixChineseEncodingInMap(Map<String, dynamic> map) {
    // 遍历Map，尝试修复所有字符串值的编码问题
    map.forEach((key, value) {
      if (value is String &&
          !_containsChinese(value) &&
          _containsEncodedBytes(value)) {
        try {
          // 尝试修复编码问题
          List<int> bytes = value.codeUnits;

          // 尝试不同的解码方式
          String? fixedValue;

          // 尝试UTF-8解码
          try {
            final utf8Decoded = utf8.decode(bytes, allowMalformed: true);
            if (_containsChinese(utf8Decoded)) {
              fixedValue = utf8Decoded;
            }
          } catch (e) {
            print('UTF-8解码失败: $e');
          }

          // 尝试直接使用String.fromCharCodes
          if (fixedValue == null) {
            try {
              final directDecoded = String.fromCharCodes(bytes);
              if (_containsChinese(directDecoded)) {
                fixedValue = directDecoded;
              }
            } catch (e) {
              print('直接解码失败: $e');
            }
          }

          // 如果找到修复的值，更新Map
          if (fixedValue != null && fixedValue != value) {
            map[key] = fixedValue;
            print('修复编码问题: "$value" -> "$fixedValue"');
          }
        } catch (e) {
          print('修复编码过程中出错: $e');
        }
      }
    });
  }

  String _fixJsonEncoding(String jsonStr) {
    // 修复JSON字符串中的编码问题

    // 步骤1: 处理常见的MySQL编码问题
    // 尝试不同的编码组合
    String fixedJson = jsonStr;

    // 尝试处理可能的转义序列问题
    fixedJson =
        fixedJson.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
      try {
        final codePoint = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(codePoint);
      } catch (e) {
        return match.group(0)!;
      }
    });

    // 如果看起来是双重编码的问题，尝试解决
    if (fixedJson.contains(r'\u') && !_containsChinese(fixedJson)) {
      try {
        // 尝试解码一次
        final decoded = jsonDecode(fixedJson);
        if (decoded is String) {
          return decoded;
        } else if (decoded is Map) {
          return jsonEncode(decoded);
        }
      } catch (e) {
        print('尝试解决双重编码问题失败: $e');
      }
    }

    // 对于包含特殊字符序列但不包含中文的字符串，尝试特殊处理
    if (!_containsChinese(fixedJson) && _containsEncodedBytes(fixedJson)) {
      try {
        List<int> bytes = fixedJson.codeUnits;
        String decodedStr = utf8.decode(bytes, allowMalformed: true);
        if (_containsChinese(decodedStr)) {
          return decodedStr;
        }
      } catch (e) {
        print('尝试特殊处理编码失败: $e');
      }
    }

    return fixedJson;
  }

  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              '暂无预约记录',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addAppointment,
              icon: const Icon(Icons.add),
              label: const Text('添加预约'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 按日期排序，最近的排在前面
    _appointments
        .sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.event,
                      color: _getStatusColor(appointment.status),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm')
                          .format(appointment.appointment_date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(appointment.status)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        appointment.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(appointment.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '项目: ${appointment.treatment_type ?? '未指定'}',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (appointment.notes != null &&
                          appointment.notes!.isNotEmpty)
                        Text(
                          '备注: ${appointment.notes}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ),
              // 操作按钮行
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 查看详情按钮
                    TextButton.icon(
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('查看'),
                      onPressed: () => _viewAppointmentDetails(appointment),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    // 编辑按钮
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('编辑'),
                      onPressed: () => _editAppointment(appointment),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                    // 删除按钮
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('删除'),
                      onPressed: () => _deleteAppointment(appointment),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已完成':
        return Colors.green;
      case '已取消':
        return Colors.red;
      case '待确认':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _editPatient() async {
    if (_patient == null) return;

    showDialog(
      context: context,
      builder: (context) => PatientFormDialog(
        patient: _patient,
        onSave: _savePatient,
      ),
    );
  }

  void _savePatient(Patient updatedPatient) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      await dbProvider.updatePatient(updatedPatient);

      // 重新加载数据
      await _loadPatientData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('患者信息已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addAppointment() async {
    // 实现添加预约功能
    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        patientId: widget.patientId,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final dbProvider =
            Provider.of<DatabaseProvider>(context, listen: false);
        await dbProvider.addAppointment(result);

        // 重新加载数据
        await _loadPatientData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('预约已添加')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加预约失败: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _viewAppointmentDetails(Appointment appointment) {
    // 实现查看预约详情功能
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('预约详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                  '日期和时间:',
                  DateFormat('yyyy-MM-dd HH:mm')
                      .format(appointment.appointment_date)),
              _buildDetailRow('状态:', appointment.status),
              _buildDetailRow('项目:', appointment.treatment_type ?? '未指定'),
              if (appointment.cost != null)
                _buildDetailRow(
                    '费用:', '¥${appointment.cost!.toStringAsFixed(2)}'),
              if (appointment.notes != null && appointment.notes!.isNotEmpty)
                _buildDetailRow('备注:', appointment.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editAppointment(Appointment appointment) async {
    // 实现编辑预约功能
    final result = await showDialog<Appointment>(
      context: context,
      builder: (context) => AppointmentFormDialog(
        patientId: widget.patientId,
        appointment: appointment,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final dbProvider =
            Provider.of<DatabaseProvider>(context, listen: false);
        await dbProvider.updateAppointment(result);

        // 重新加载数据
        await _loadPatientData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('预约已更新')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新预约失败: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _deleteAppointment(Appointment appointment) async {
    // 实现删除预约功能
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个预约吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final dbProvider =
            Provider.of<DatabaseProvider>(context, listen: false);
        await dbProvider.deleteAppointment(appointment.id!);

        // 重新加载数据
        await _loadPatientData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('预约已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除预约失败: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
