import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/models/database_models.dart';

class AppointmentFormSheet extends StatefulWidget {
  final Appointment? appointment;
  final Function(bool isSuccess, String message) onSaved;
  final DateTime? initialDate;

  const AppointmentFormSheet({
    super.key,
    this.appointment,
    required this.onSaved,
    this.initialDate,
  });

  @override
  State<AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<AppointmentFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // 表单数据
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  int? _selectedPatientId;
  String _status = 'scheduled';
  String _treatmentType = '';
  String _notes = '';
  double _cost = 0.0;

  // 患者列表
  List<Patient> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();

    // 如果是编辑模式，初始化表单数据
    if (widget.appointment != null) {
      final appointment = widget.appointment!;
      _selectedDate = appointment.appointmentDate;
      _selectedTime = TimeOfDay.fromDateTime(appointment.appointmentDate);
      _selectedPatientId = appointment.patientId;
      _status = appointment.status;
      _treatmentType = appointment.treatmentType ?? '';
      _notes = appointment.notes ?? '';
      _cost = appointment.cost;
    } else {
      // 如果有初始日期参数，使用它
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
        _selectedTime = const TimeOfDay(hour: 9, minute: 0); // 默认上午9点
      } else {
        // 新建预约，默认为当前时间后一小时，向上取整到30分钟
        final now = DateTime.now();
        final minutes = now.minute;
        final roundedMinutes = (minutes / 30).ceil() * 30;
        _selectedDate = now;
        _selectedTime = TimeOfDay(
          hour: (now.hour + (roundedMinutes >= 60 ? 1 : 0)) % 24,
          minute: roundedMinutes % 60,
        );
      }
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final patients = await dbProvider.getAllPatients();

      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      print('加载患者数据错误: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择患者'), duration: Duration(seconds: 2)),
      );
      return;
    }

    // 设置加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 合并日期和时间
      final appointmentDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final appointment = Appointment(
        id: widget.appointment?.id,
        patientId: _selectedPatientId!,
        appointmentDate: appointmentDate,
        status: _status,
        treatmentType: _treatmentType.isEmpty ? null : _treatmentType,
        notes: _notes.isEmpty ? null : _notes,
        cost: _cost,
      );

      if (widget.appointment == null) {
        // 新建预约
        await dbProvider.addAppointment(appointment);
      } else {
        // 更新预约
        await dbProvider.updateAppointment(appointment);
      }

      // 重置加载状态
      setState(() {
        _isLoading = false;
      });

      // 先关闭表单
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // 通知父组件刷新并显示成功消息
      widget.onSaved(true, widget.appointment == null ? '预约创建成功' : '预约更新成功');
    } catch (e) {
      // 重置加载状态
      setState(() {
        _isLoading = false;
      });

      // 通知父组件显示错误消息
      widget.onSaved(false, '保存失败: $e');
      print('保存预约错误: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accentColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    // 当前选择的小时和分钟
    int hour = _selectedTime.hour;
    int minute = _selectedTime.minute;

    // 用于手动输入的控制器
    final hourController = TextEditingController(
      text: hour.toString().padLeft(2, '0'),
    );
    final minuteController = TextEditingController(
      text: minute.toString().padLeft(2, '0'),
    );

    // 显示自定义24小时制时间选择对话框
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择时间'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              // 更新文本框的值
              void updateTextFieldsFromValues() {
                hourController.text = hour.toString().padLeft(2, '0');
                minuteController.text = minute.toString().padLeft(2, '0');
              }

              // 从文本框更新值
              void updateValuesFromTextFields() {
                final h = int.tryParse(hourController.text);
                final m = int.tryParse(minuteController.text);

                if (h != null && h >= 0 && h < 24) {
                  hour = h;
                }
                if (m != null && m >= 0 && m < 60) {
                  minute = m;
                }
              }

              return SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 手动输入时间
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 小时输入
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: hourController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                hintText: '时',
                              ),
                              onChanged: (value) {
                                final h = int.tryParse(value);
                                if (h != null && h >= 0 && h < 24) {
                                  setState(() {
                                    hour = h;
                                  });
                                }
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // 分钟输入
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: minuteController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                hintText: '分',
                              ),
                              onChanged: (value) {
                                final m = int.tryParse(value);
                                if (m != null && m >= 0 && m < 60) {
                                  setState(() {
                                    minute = m;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),

                      // 小时选择器
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              '小时',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            height: 120,
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 6,
                                    childAspectRatio: 1.2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                              itemCount: 24,
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (context, index) {
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      hour = index;
                                      updateTextFieldsFromValues();
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          hour == index
                                              ? AppTheme.accentColor
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        color:
                                            hour == index
                                                ? Colors.white
                                                : AppTheme.primaryText,
                                        fontWeight:
                                            hour == index
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 分钟选择器
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              '分钟',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children:
                                [
                                  0,
                                  5,
                                  10,
                                  15,
                                  20,
                                  25,
                                  30,
                                  35,
                                  40,
                                  45,
                                  50,
                                  55,
                                ].map((m) {
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        minute = m;
                                        updateTextFieldsFromValues();
                                      });
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            minute == m
                                                ? AppTheme.accentColor
                                                : Colors.transparent,
                                        border: Border.all(
                                          color:
                                              minute == m
                                                  ? AppTheme.accentColor
                                                  : Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        m.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          color:
                                              minute == m
                                                  ? Colors.white
                                                  : AppTheme.primaryText,
                                          fontWeight:
                                              minute == m
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentColor,
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    ).then((value) {
      if (value == true) {
        final newTime = TimeOfDay(hour: hour, minute: minute);
        if (newTime != _selectedTime) {
          setState(() {
            _selectedTime = newTime;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.padding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏和关闭按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.appointment == null ? '新建预约' : '编辑预约',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.secondaryText,
                      iconSize: 24,
                    ),
                  ],
                ),
                const Divider(height: 24),

                // 患者选择
                _buildSectionTitle('患者信息', Icons.person),
                const SizedBox(height: 8),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.smallBorderRadius,
                        ),
                        side: BorderSide(
                          color: AppTheme.dividerColor.withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: DropdownButtonFormField<int>(
                          value: _selectedPatientId,
                          decoration: const InputDecoration(
                            hintText: '选择患者',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          items:
                              _patients.map((patient) {
                                return DropdownMenuItem<int>(
                                  value: patient.id,
                                  child: Text(
                                    '${patient.name} (${_getDisplayPhone(patient.phone)})',
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPatientId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return '请选择患者';
                            }
                            return null;
                          },
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 20),

                // 日期和时间选择
                _buildSectionTitle('预约时间', Icons.calendar_today),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.smallBorderRadius,
                          ),
                          side: BorderSide(
                            color: AppTheme.dividerColor.withOpacity(0.3),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          borderRadius: BorderRadius.circular(
                            AppTheme.smallBorderRadius,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(_selectedDate),
                                  style: const TextStyle(
                                    color: AppTheme.primaryText,
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.smallBorderRadius,
                          ),
                          side: BorderSide(
                            color: AppTheme.dividerColor.withOpacity(0.3),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _selectTime(context),
                          borderRadius: BorderRadius.circular(
                            AppTheme.smallBorderRadius,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedTime.format(context),
                                  style: const TextStyle(
                                    color: AppTheme.primaryText,
                                  ),
                                ),
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 状态选择
                _buildSectionTitle('预约状态', Icons.bookmark),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.smallBorderRadius,
                    ),
                    side: BorderSide(
                      color: AppTheme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        hintText: '选择状态',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      items: [
                        _buildDropdownMenuItem(
                          'scheduled',
                          '已预约',
                          AppTheme.infoColor,
                        ),
                        _buildDropdownMenuItem(
                          'completed',
                          '已完成',
                          AppTheme.successColor,
                        ),
                        _buildDropdownMenuItem(
                          'cancelled',
                          '已取消',
                          AppTheme.errorColor,
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value!;
                        });
                      },
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 治疗信息
                _buildSectionTitle('治疗信息', Icons.medical_services),
                const SizedBox(height: 8),
                _buildTextField(
                  initialValue: _treatmentType,
                  hint: '治疗项目',
                  icon: Icons.healing,
                  onChanged: (value) {
                    _treatmentType = value;
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  initialValue: _cost.toString(),
                  hint: '费用',
                  icon: Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) {
                    _cost = double.tryParse(value) ?? 0.0;
                  },
                ),
                const SizedBox(height: 20),

                // 备注
                _buildSectionTitle('备注信息', Icons.note),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.smallBorderRadius,
                    ),
                    side: BorderSide(
                      color: AppTheme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextFormField(
                      initialValue: _notes,
                      decoration: const InputDecoration(
                        hintText: '输入备注信息',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      maxLines: 3,
                      style: const TextStyle(color: AppTheme.primaryText),
                      onChanged: (value) {
                        _notes = value;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 保存按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.secondaryText,
                          side: const BorderSide(color: AppTheme.secondaryText),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.smallBorderRadius,
                            ),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveAppointment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.smallBorderRadius,
                            ),
                          ),
                        ),
                        child: Text(
                          widget.appointment == null ? '创建预约' : '更新预约',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建标题部分
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryText,
          ),
        ),
      ],
    );
  }

  // 构建文本字段
  Widget _buildTextField({
    required String initialValue,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required Function(String) onChanged,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: TextFormField(
          initialValue: initialValue,
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            icon: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.primaryText),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // 构建下拉菜单项
  DropdownMenuItem<String> _buildDropdownMenuItem(
    String value,
    String text,
    Color color,
  ) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  // 从JSON格式中获取显示电话号码
  String _getDisplayPhone(String phone) {
    if (phone.startsWith('[') && phone.endsWith(']')) {
      try {
        List<dynamic> phones = jsonDecode(phone);
        if (phones.isNotEmpty) {
          return phones[0].toString();
        }
      } catch (e) {
        print('解析电话号码JSON失败: $e');
      }
    }
    return phone;
  }
}
