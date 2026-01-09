import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../models/patient.dart';
import '../providers/database_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/app_state.dart';
import '../widgets/dental_icons.dart';
import './patient_detail_screen.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
};

// 十字画笔
class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5;

    // 绘制水平线 - 明显长于竖线（占据整个宽度）
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // 绘制垂直线 - 高度约为三个字符高度
    double verticalHeight = 40; // 恢复原先高度，避免文字溢出
    double startY = size.height / 2 - verticalHeight / 2;
    double endY = size.height / 2 + verticalHeight / 2;

    canvas.drawLine(
      Offset(size.width / 2, startY),
      Offset(size.width / 2, endY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// 只读十字图显示组件
class TeethCrossWidget extends StatelessWidget {
  final Map<String, String> teethData;
  final int index;

  const TeethCrossWidget({
    required this.teethData,
    required this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120, // 恢复原始尺寸
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('牙位 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          _buildCross(),
        ],
      ),
    );
  }

  Widget _buildCross() {
    // 使用固定尺寸而非LayoutBuilder，避免潜在的布局计算问题（恢复原值）
    final double width = 170.0;
    final double height = 90.0;
    final double centerX = width / 2;
    final double centerY = height / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 自定义画笔绘制十字
        CustomPaint(
          size: Size(width, height),
          painter: CrossPainter(),
        ),

        // 上左象限
        Positioned(
          top: centerY - 20, // 更加靠近横线
          left: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              teethData['topLeft'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ),

        // 上右象限
        Positioned(
          top: centerY - 20, // 更加靠近横线
          right: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              teethData['topRight'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.left,
            ),
          ),
        ),

        // 下左象限
        Positioned(
          top: centerY + 3, // 更加靠近横线
          left: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 2),
            child: Text(
              teethData['bottomLeft'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ),

        // 下右象限
        Positioned(
          top: centerY + 3, // 更加靠近横线
          right: 10,
          width: centerX - 12,
          height: 18,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              teethData['bottomRight'] ?? '',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ],
    );
  }
}

class AppointmentDetailsScreen extends StatefulWidget {
  final int appointmentId;

  const AppointmentDetailsScreen({
    Key? key,
    required this.appointmentId,
  }) : super(key: key);

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  Appointment? _appointment;
  Patient? _patient;
  bool _isLoading = true;

  // 预约详情数据
  List<Map<String, String>> _teethData = [];
  List<String> _treatments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointmentData();
  }

  Future<void> _loadAppointmentData() async {
    setState(() => _isLoading = true);

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);

      // 获取预约详情
      final appointments = await appointmentProvider.getAllAppointments();
      final appointment = appointments.firstWhere(
        (a) => a.id == widget.appointmentId,
        orElse: () => throw Exception('预约不存在'),
      );

      // 获取患者信息
      final patient = appointment.patientId != null
          ? await patientProvider.getPatient(appointment.patientId!)
          : null;

      // 解析treatment_type字段，获取牙齿情况和治疗项目
      if (appointment.treatment_type != null) {
        _parseTreatmentTypeData(appointment.treatment_type!);
      }

      setState(() {
        _appointment = appointment;
        _patient = patient;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载预约数据失败: $e'), backgroundColor: Colors.red),
      );
      Navigator.of(context).pop();
    }
  }

  // 解析treatment_type字段中的数据
  void _parseTreatmentTypeData(String treatmentTypeStr) {
    try {
      // 尝试解析为JSON
      Map<String, dynamic> data = json.decode(treatmentTypeStr);

      // 提取牙齿情况数据
      if (data.containsKey('teethData')) {
        var teethJsonData = data['teethData'];
        _teethData = List<Map<String, String>>.from(
            teethJsonData.map((item) => Map<String, String>.from(item)));
      }

      // 提取治疗项目数据
      if (data.containsKey('treatments')) {
        _treatments = List<String>.from(data['treatments']);
      }
    } catch (e) {
      // 如果解析失败，可能是旧数据格式，直接设为治疗项目
      print('解析treatment_type失败: $e');

      // 如果治疗类型包含多个项目（用顿号分隔），则解析为多选项目
      if (treatmentTypeStr.contains('、')) {
        _treatments = treatmentTypeStr.split('、');
      } else if (treatmentTypeStr.isNotEmpty) {
        _treatments = [treatmentTypeStr];
      }
    }
  }

  void _changeAppointmentStatus(String newStatus) async {
    if (_appointment == null) return;

    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      // 创建更新后的预约对象
      var updatedAppointment = Appointment(
        id: _appointment!.id,
        patient_id: _appointment!.patient_id,
        patient: _appointment!.patient,
        appointment_date: _appointment!.appointment_date,
        status: newStatus,
        treatment_type: _appointment!.treatment_type,
        notes: _appointment!.notes,
        cost: _appointment!.cost,
        created_at: _appointment!.created_at,
        updated_at: DateTime.now(),
      );

      // 添加防重复提交保护
      await appState.showLoading(
        appointmentProvider.updateAppointment(updatedAppointment),
        message: '正在更新状态...',
      );

      // 重新加载数据
      _loadAppointmentData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('预约状态已更新为: $newStatus'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新预约状态失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: DentalColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_note_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isLoading
                  ? '预约详情'
                  : '预约: ${DateFormat('MM/dd HH:mm').format(_appointment!.appointmentDate)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: DentalColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.info.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: DentalColors.info,
              ),
              tooltip: '刷新',
              onPressed: _loadAppointmentData,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointment == null
              ? const Center(child: Text('预约信息不存在'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAppointmentCard(),
                      const SizedBox(height: 16),
                      if (_patient != null) _buildPatientCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAppointmentCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            DentalColors.background.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: DentalColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: DentalColors.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        DentalColors.primary,
                        DentalColors.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: DentalColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN')
                            .format(_appointment!.appointmentDate),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '时间: ${DateFormat('HH:mm').format(_appointment!.appointmentDate)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: DentalColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(int.parse(_appointment!.statusColor.replaceAll('#', '0xff'))).withOpacity(0.1),
                        Color(int.parse(_appointment!.statusColor.replaceAll('#', '0xff'))).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(int.parse(_appointment!.statusColor.replaceAll('#', '0xff'))),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(int.parse(_appointment!.statusColor.replaceAll('#', '0xff'))).withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _appointment!.statusDisplay,
                    style: TextStyle(
                      color: Color(int.parse(_appointment!.statusColor.replaceAll('#', '0xff'))),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 1, color: DentalColors.divider),

            // 牙齿情况
            _buildTeethConditionSection(),
            const Divider(height: 24, thickness: 1, color: DentalColors.divider),

            // 治疗项目
            _buildTreatmentItemsSection(),

            if (_appointment!.notes != null &&
                _appointment!.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow('备注', _appointment!.notes!),
            ],

            if (_appointment!.cost != null) ...[
              const Divider(height: 24),
              _buildInfoRow('费用', '¥${_appointment!.cost!.toStringAsFixed(2)}'),
            ],

            const SizedBox(height: 12),
            // 精简：更新预约状态
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DentalColors.divider.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.update_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        '更新预约状态',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: DentalColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusButton('已预约', Colors.blue),
                      _buildStatusButton('已完成', Colors.green),
                      _buildStatusButton('已取消', Colors.red),
                      _buildStatusButton('未到诊', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 精简：创建/更新时间
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '创建于: ${_appointment!.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(_appointment!.createdAt!) : '未知'}',
                        style: TextStyle(fontSize: 12, color: DentalColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.update_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '上次更新: ${_appointment!.updatedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(_appointment!.updatedAt!) : '未知'}',
                        style: TextStyle(fontSize: 12, color: DentalColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 牙齿情况区域
  Widget _buildTeethConditionSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            DentalColors.background.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DentalColors.primary.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: DentalColors.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: DentalColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    DentalIcons.tooth,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '牙位情况',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: DentalColors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '从医生视角看患者：显示的是患者的实际牙位（右上、左上、右下、左下）',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: DentalColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: DentalColors.info,
                    ),
                  ),
                ),
              ],
            ),
            // 添加牙位方向提示信息
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DentalColors.info.withOpacity(0.1),
                    DentalColors.info.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DentalColors.info.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: DentalColors.info.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: DentalColors.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '注意：十字图中位置对应患者的实际牙位',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DentalColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            // 使用牙位交叉组件显示 - 两个十字并排显示
            if (_teethData.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.start, // 靠左显示
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._teethData.map((toothData) {
                    int index = _teethData.indexOf(toothData);
                    Map<String, String> data = {
                      'topLeft': toothData['topLeft'] ?? '',
                      'topRight': toothData['topRight'] ?? '',
                      'bottomLeft': toothData['bottomLeft'] ?? '',
                      'bottomRight': toothData['bottomRight'] ?? '',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0), // 减小间距从16降至8
                      child: TeethCrossWidget(
                        teethData: data,
                        index: index,
                      ),
                    );
                  }).toList(),
                ],
              )
            else
              const Text('暂无牙位信息'),
          ],
        ),
      ),
    );
  }

  // 治疗项目区域 - 显示治疗项目
  Widget _buildTreatmentItemsSection() {
    // 处理治疗项目显示
    Widget treatmentContent;

    try {
      final treatmentData = jsonDecode(_appointment!.treatment_type ?? '[]');

      if (treatmentData is Map<String, dynamic>) {
        // 处理新格式数据 - 只显示治疗项目
        List<Widget> contentWidgets = [];

        // 处理治疗项目 - 格式化展示
        if (treatmentData.containsKey('treatments') &&
            treatmentData['treatments'] is List &&
            (treatmentData['treatments'] as List).isNotEmpty) {
          List<String> treatments =
              List<String>.from(treatmentData['treatments']);

          contentWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  treatments.join('、'),
                  style: const TextStyle(fontSize: 14.0),
                ),
              ],
            ),
          );
        } else if (treatmentData.containsKey('treatmentTypes')) {
          final List<dynamic> treatmentTypes = treatmentData['treatmentTypes'];
          contentWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  treatmentTypes.map((item) => item.toString()).join('、'),
                  style: const TextStyle(fontSize: 14.0),
                ),
              ],
            ),
          );
        }

        treatmentContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets.isEmpty
              ? [const Text('无治疗项目', style: TextStyle(fontSize: 14.0))]
              : contentWidgets,
        );
      } else if (treatmentData is List) {
        // 处理旧格式 - 只有治疗项目列表
        treatmentContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              treatmentData.map((item) => item.toString()).join('、'),
              style: const TextStyle(fontSize: 14.0),
            ),
          ],
        );
      } else {
        // 处理单个字符串的情况
        treatmentContent = Text(
          treatmentData.toString(),
          style: const TextStyle(fontSize: 14.0),
        );
      }
    } catch (e) {
      // 处理无法解析JSON的情况 - 显示原始治疗类型
      treatmentContent = Text(
        _appointment!.treatment_type ?? '无治疗项目',
        style: const TextStyle(fontSize: 14.0),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DentalColors.divider.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.medical_services_rounded,
                  size: 18,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  '治疗项目',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: DentalColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(0),
              child: treatmentContent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DentalColors.divider.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: DentalColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DentalColors.primary.withOpacity(0.2)),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: DentalColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '患者信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DentalColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _patient!.gender == '女'
                        ? const Color(0xFFFCE4EC)
                        : const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _patient!.name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _patient!.gender == '女'
                            ? Colors.pink.shade600
                            : Colors.blue.shade600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _patient!.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: DentalColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // 基本信息chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: DentalColors.info.withOpacity(0.5)),
                            ),
                            child: Text(
                              '${_patient!.age}岁 | ${_patient!.gender} | ${_patient!.phone}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: DentalColors.info,
                              ),
                            ),
                          ),
                          // 病历号紧随其后同一行展示
                          if (_patient!.medical_record_number != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: DentalColors.primary.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_rounded, size: 14, color: DentalColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '病历号 ${_patient!.medical_record_number}',
                                    style: TextStyle(fontSize: 12, color: DentalColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          // 地址同一行展示（过长会在Wrap中换行）
                          if (_patient!.address != null && _patient!.address!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: DentalColors.onSurfaceVariant.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: DentalColors.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    _patient!.address!,
                                    style: TextStyle(fontSize: 12, color: DentalColors.onSurfaceVariant, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.info_outline_rounded,
                    color: DentalColors.primary,
                  ),
                  tooltip: '查看患者详情',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PatientDetailScreen(patient: _patient!),
                      ),
                    );
                  },
                ),
              ],
            ),
            // 去掉下方额外信息区域，患者信息仅保留一行紧凑显示
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String status, Color color) {
    final isCurrentStatus = _appointment!.status == status;

    // 获取状态对应的转换后状态文本
    String statusText;
    switch (status) {
      case '已预约':
        statusText = '已预约';
        break;
      case '已完成':
        statusText = '已完成';
        break;
      case '已取消':
        statusText = '已取消';
        break;
      case '未到诊':
        statusText = '未到诊';
        break;
      default:
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      child: InkWell(
        onTap: isCurrentStatus ? null : () => _changeAppointmentStatus(status),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrentStatus ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(isCurrentStatus ? 1.0 : 0.6),
              width: 1,
            ),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: isCurrentStatus ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DentalColors.divider.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: DentalColors.primary.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: DentalColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: DentalColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: DentalColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: DentalColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
