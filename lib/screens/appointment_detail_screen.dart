import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/widgets/app_card.dart';
import 'package:dentist_app/widgets/appointment_form_sheet.dart';
import 'package:dentist_app/utils/toast_util.dart';
import 'package:dentist_app/utils/permission_utils.dart';

// 牙位映射表 - 从医生视角看患者牙齿
final Map<String, String> positionMap = {
  'topLeft': '右上',
  'topRight': '左上',
  'bottomLeft': '右下',
  'bottomRight': '左下',
};

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Patient? _patient;
  bool _isLoading = true;
  bool _dataUpdated = false; // 标记数据是否已更新

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final patient = await Provider.of<PatientProvider>(context, listen: false).getPatientById(
        widget.appointment.patientId,
      );

      setState(() {
        _patient = patient;
        _isLoading = false;
      });
    } catch (e) {
      print('加载患者数据错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 只有在数据更新时才返回true，否则返回null
        Navigator.of(context).pop(_dataUpdated ? true : null);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('预约详情'),
          centerTitle: true,
          backgroundColor: AppTheme.cardBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // 只有在数据更新时才返回true，否则返回null
              Navigator.of(context).pop(_dataUpdated ? true : null);
            },
          ),
        elevation: 0,
        actions: [
          // 编辑按钮
          FutureBuilder<String?>(
            future: _getAppointmentPatientDoctor(),
            builder: (context, snapshot) {
              final patientDoctor = snapshot.data;
              return PermissionWrapper(
                module: 'appointments',
                action: 'edit',
                recordDoctor: patientDoctor,
                onPermissionDenied: () {
                  PermissionUtils.showPermissionDeniedMessage(
                    context,
                    customMessage: '您只能编辑自己负责患者的预约',
                  );
                },
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                  onPressed: _showEditAppointment,
                  tooltip: '编辑预约',
                ),
              );
            },
          ),
          // 删除按钮
          FutureBuilder<String?>(
            future: _getAppointmentPatientDoctor(),
            builder: (context, snapshot) {
              final patientDoctor = snapshot.data;
              return PermissionWrapper(
                module: 'appointments',
                action: 'delete',
                recordDoctor: patientDoctor,
                onPermissionDenied: () {
                  PermissionUtils.showPermissionDeniedMessage(
                    context,
                    customMessage: '您只能删除自己负责患者的预约',
                  );
                },
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                  onPressed: _showDeleteConfirmation,
                  tooltip: '删除预约',
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAppointmentInfoCard(),
                    const SizedBox(height: 16),
                    _buildPatientInfoCard(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAppointmentInfoCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '预约信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              _buildStatusChip(widget.appointment.status),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(
            CupertinoIcons.calendar,
            '预约日期',
            DateFormat(
              'yyyy年MM月dd日',
            ).format(widget.appointment.appointmentDate),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            CupertinoIcons.clock,
            '预约时间',
            DateFormat('HH:mm').format(widget.appointment.appointmentDate),
          ),
          if (widget.appointment.treatmentType != null &&
              widget.appointment.treatmentType!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTreatmentTypeInfo(widget.appointment.treatmentType!),
          ],
          if (widget.appointment.cost > 0) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.money_dollar,
              '费用',
              '¥${widget.appointment.cost.toStringAsFixed(2)}',
              valueColor: AppTheme.accentColor,
            ),
          ],
          if (widget.appointment.notes != null &&
              widget.appointment.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.doc_text,
              '备注',
              widget.appointment.notes!,
              alignTop: true,
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            CupertinoIcons.time,
            '创建时间',
            DateFormat('yyyy-MM-dd HH:mm').format(widget.appointment.createdAt),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            CupertinoIcons.time,
            '更新时间',
            DateFormat('yyyy-MM-dd HH:mm').format(widget.appointment.updatedAt),
          ),
        ],
      ),
    );
  }

  // 解析和显示治疗类型信息
  Widget _buildTreatmentTypeInfo(String treatmentTypeJson) {
    try {
      // 尝试解析JSON数据
      final treatmentData = json.decode(treatmentTypeJson);

      // 构建显示内容
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.bandage,
                size: 18,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              const Text(
                '治疗信息:',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // 牙位信息
          if (treatmentData.containsKey('teethData') &&
              treatmentData['teethData'] is List &&
              (treatmentData['teethData'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 26),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '牙位情况:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: '从医生视角看患者：显示的是患者的实际牙位（右上、左上、右下、左下）',
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 两个牙位图并排显示
                  Row(
                    children: [
                      if ((treatmentData['teethData'] as List).isNotEmpty &&
                          _hasTeethData(treatmentData['teethData'][0]))
                        Expanded(
                          child: _buildTeethDataRow(treatmentData['teethData'][0], 1),
                        ),
                      if ((treatmentData['teethData'] as List).length > 1 &&
                          _hasTeethData(treatmentData['teethData'][1])) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTeethDataRow(treatmentData['teethData'][1], 2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],

          // 治疗项目
          if (treatmentData.containsKey('treatments') &&
              treatmentData['treatments'] is List &&
              (treatmentData['treatments'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '治疗项目: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (treatmentData['treatments'] as List).join('、'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    } catch (e) {
      // 如果解析失败，显示原始字符串
      print('解析治疗类型JSON失败: $e');
      return _buildInfoRow(CupertinoIcons.bandage, '治疗项目', treatmentTypeJson);
    }
  }

  // 检查是否包含有效的牙位数据
  bool _hasTeethData(Map<String, dynamic> teethData) {
    return teethData.entries.any(
      (entry) => entry.value != null && entry.value.toString().isNotEmpty,
    );
  }

  // 构建单组牙位数据行 - 使用十字图显示
  Widget _buildTeethDataRow(Map<String, dynamic> teethData, int groupNumber) {
    // 检查是否有数据
    if (!_hasTeethData(teethData)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '牙位 $groupNumber',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        _buildTeethCrossWidget(teethData),
      ],
    );
  }

  // 构建十字图组件
  Widget _buildTeethCrossWidget(Map<String, dynamic> teethData) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final centerX = width / 2;
          final centerY = height / 2;
          
          return CustomPaint(
            painter: _TeethCrossPainter(),
            child: Stack(
              children: [
                // 右上象限（topLeft - 从医生视角看患者的右上）
                Positioned(
                  top: 0,
                  left: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.only(right: 2, bottom: 1),
                    child: Text(
                      teethData['topLeft']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                // 左上象限（topRight - 从医生视角看患者的左上）
                Positioned(
                  top: 0,
                  right: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.only(left: 2, bottom: 1),
                    child: Text(
                      teethData['topRight']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                // 右下象限（bottomLeft - 从医生视角看患者的右下）
                Positioned(
                  bottom: 0,
                  left: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 2, top: 1),
                    child: Text(
                      teethData['bottomLeft']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                // 左下象限（bottomRight - 从医生视角看患者的左下）
                Positioned(
                  bottom: 0,
                  right: 0,
                  width: centerX - 2,
                  height: centerY - 2,
                  child: Container(
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.only(left: 2, top: 1),
                    child: Text(
                      teethData['bottomRight']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryText,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    if (_patient == null) {
      return const AppCard(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('无法加载患者信息')),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '患者信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      _patient!.gender == '男'
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _patient!.gender,
                  style: TextStyle(
                    color: _patient!.gender == '男' ? Colors.blue : Colors.pink,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(CupertinoIcons.person, '姓名', _patient!.name),
          const SizedBox(height: 12),
          _buildInfoRow(CupertinoIcons.number, '年龄', '${_patient!.age}岁'),
          const SizedBox(height: 12),
          _buildInfoRow(CupertinoIcons.phone, '联系电话', _patient!.phone),
          if (_patient!.medicalRecordNumber != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.doc_text,
              '病历号',
              _patient!.medicalRecordNumber.toString(),
            ),
          ],
          if (_patient!.doctor != null && _patient!.doctor!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(CupertinoIcons.person_2, '主治医生', _patient!.doctor!),
          ],
          if (_patient!.address != null && _patient!.address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.location,
              '地址',
              _patient!.address!,
              alignTop: true,
            ),
          ],
          if (_patient!.treatmentItems != null &&
              _patient!.treatmentItems!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '患者治疗项目',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                _patient!.treatmentItems!,
                style: const TextStyle(fontSize: 14, color: AppTheme.textColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool alignTop = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textColor,
              fontSize: 14,
              fontWeight:
                  valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'scheduled':
      case '已预约':
        color = AppTheme.infoColor;
        text = '已预约';
        break;
      case 'completed':
      case '已完成':
        color = AppTheme.successColor;
        text = '已完成';
        break;
      case 'cancelled':
      case '已取消':
        color = AppTheme.errorColor;
        text = '已取消';
        break;
      case 'missed':
      case 'no_show':
      case '未到诊':
        color = Colors.orange;
        text = '未到诊';
        break;
      default:
        color = AppTheme.secondaryText;
        text = status; // 显示原始状态
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _showEditAppointment() async {
    // 导航到编辑预约页面
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: AppointmentFormSheet(
              appointment: widget.appointment,
              onSaved: (isSuccess, message) {
                if (isSuccess) {
                  // 刷新页面数据
                  _loadPatientData();
                  ToastUtil.showSuccess(context, message);
                  // 标记数据已更新
                  setState(() {
                    _dataUpdated = true;
                  });
                  Navigator.of(context).pop(true);
                } else {
                  ToastUtil.showError(context, message);
                  Navigator.of(context).pop(false);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除此预约吗？此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.secondaryText,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 先关闭对话框
                  _deleteAppointment(); // 再执行删除操作
                },
                child: const Text('确认删除'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAppointment() async {
    if (widget.appointment.id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法删除：预约ID无效')));
      return;
    }

    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);
      await appointmentsProvider.deleteAppointment(widget.appointment.id!);

      // 返回上一页并通知更新
      if (!mounted) return;
      Navigator.of(context).pop(true); // 返回true表示数据已修改，需要刷新
      ToastUtil.showSuccess(context, '预约已成功删除');
    } catch (e) {
      print('删除预约错误: $e');
      if (!mounted) return;
      ToastUtil.showError(context, '删除预约失败: $e');
    }
  }

  // 获取状态信息
  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return AppTheme.infoColor;
      case 'completed':
      case '已完成':
        return AppTheme.successColor;
      case 'cancelled':
      case '已取消':
        return AppTheme.errorColor;
      case 'missed':
      case 'no_show':
      case '未到诊':
        return Colors.orange;
      default:
        return AppTheme.secondaryText;
    }
  }

  // 获取状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return '已预约';
      case 'completed':
      case '已完成':
        return '已完成';
      case 'cancelled':
      case '已取消':
        return '已取消';
      case 'missed':
      case 'no_show':
      case '未到诊':
        return '未到诊';
      default:
        return status; // 显示原始状态
    }
  }

  // 获取状态图标
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return Icons.schedule;
      case 'completed':
      case '已完成':
        return Icons.check_circle_outline;
      case 'cancelled':
      case '已取消':
        return Icons.cancel_outlined;
      case 'missed':
      case 'no_show':
      case '未到诊':
        return Icons.unpublished_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // 构建预约状态卡片
  Widget _buildAppointmentStatusCard() {
    final status = widget.appointment.status ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预约状态',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontSize: 16,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建操作按钮组
  Widget _buildActionButtons() {
    final status = widget.appointment.status ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '操作',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<String?>(
              future: _getAppointmentPatientDoctor(),
              builder: (context, snapshot) {
                final patientDoctor = snapshot.data;
                
                // 收集所有需要显示的按钮
                final List<Widget> buttons = [];
                
                if (status != '已预约' && status != 'scheduled') {
                  buttons.add(
                    PermissionWrapper(
                      module: 'appointments',
                      action: 'edit',
                      recordDoctor: patientDoctor,
                      onPermissionDenied: () {
                        PermissionUtils.showPermissionDeniedMessage(
                          context,
                          customMessage: '您只能修改自己负责患者的预约',
                        );
                      },
                      child: _buildActionButton(
                        '已预约',
                        AppTheme.infoColor,
                        Icons.schedule,
                        () => _changeAppointmentStatus('scheduled'),
                      ),
                    ),
                  );
                }
                
                if (status != '已完成' && status != 'completed') {
                  buttons.add(
                    PermissionWrapper(
                      module: 'appointments',
                      action: 'edit',
                      recordDoctor: patientDoctor,
                      onPermissionDenied: () {
                        PermissionUtils.showPermissionDeniedMessage(
                          context,
                          customMessage: '您只能修改自己负责患者的预约',
                        );
                      },
                      child: _buildActionButton(
                        '已完成',
                        AppTheme.successColor,
                        Icons.check_circle_outline,
                        () => _changeAppointmentStatus('completed'),
                      ),
                    ),
                  );
                }
                
                if (status != '已取消' && status != 'cancelled') {
                  buttons.add(
                    PermissionWrapper(
                      module: 'appointments',
                      action: 'edit',
                      recordDoctor: patientDoctor,
                      onPermissionDenied: () {
                        PermissionUtils.showPermissionDeniedMessage(
                          context,
                          customMessage: '您只能修改自己负责患者的预约',
                        );
                      },
                      child: _buildActionButton(
                        '已取消',
                        AppTheme.errorColor,
                        Icons.cancel_outlined,
                        () => _changeAppointmentStatus('cancelled'),
                      ),
                    ),
                  );
                }
                
                if (status != '未到诊' && status != 'missed' && status != 'no_show') {
                  buttons.add(
                    PermissionWrapper(
                      module: 'appointments',
                      action: 'edit',
                      recordDoctor: patientDoctor,
                      onPermissionDenied: () {
                        PermissionUtils.showPermissionDeniedMessage(
                          context,
                          customMessage: '您只能修改自己负责患者的预约',
                        );
                      },
                      child: _buildActionButton(
                        '未到诊',
                        Colors.orange,
                        Icons.unpublished_outlined,
                        () => _changeAppointmentStatus('missed'),
                      ),
                    ),
                  );
                }
                
                // 使用 Row 和 Expanded 平均分配宽度
                return Row(
                  children: buttons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final button = entry.value;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index < buttons.length - 1 ? 8 : 0,
                        ),
                        child: button,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButton(
    String text,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取预约关联患者的医生字段，用于权限检查
  Future<String?> _getAppointmentPatientDoctor() async {
    try {
      if (_patient != null) {
        return _patient!.doctor;
      }
      
      // 如果患者数据还没加载，尝试获取
      if (widget.appointment.patientId != null) {
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        final patient = await patientProvider.getPatientById(widget.appointment.patientId);
        return patient?.doctor;
      }
      
      return null;
    } catch (e) {
      print('获取预约患者医生信息失败: $e');
      return null;
    }
  }

  // 修改预约状态
  Future<void> _changeAppointmentStatus(String newStatus) async {
    try {
      final appointmentsProvider = Provider.of<AppointmentsProvider>(context, listen: false);

      // 创建更新后的预约对象
      final updatedAppointment = widget.appointment.copyWith(status: newStatus);

      // 更新预约状态
      await appointmentsProvider.updateAppointment(updatedAppointment);

      // 显示成功提示
      if (!mounted) return;
      ToastUtil.showSuccess(context, '预约状态已更新');

      // 标记数据已更新并返回上一页
      setState(() {
        _dataUpdated = true;
      });
      Navigator.of(context).pop(true); // 返回true表示数据已修改，需要刷新
    } catch (e) {
      print('更新预约状态错误: $e');
      if (!mounted) return;
      ToastUtil.showError(context, '更新预约状态失败: $e');
    }
  }
}

// 十字画笔 - 用于绘制牙位十字图
class _TeethCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 绘制水平线 - 占据整个宽度
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );

    // 绘制垂直线 - 占据整个高度
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
