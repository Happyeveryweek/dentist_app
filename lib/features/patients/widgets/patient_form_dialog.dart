import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../models/patient.dart';
import '../../../models/dental_chart.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/modern_date_picker.dart';
import '../models/patient_form_state.dart';
import 'patient_form_components.dart';
import '../../../utils/permission_utils.dart';

// 患者表单对话框组件
class PatientFormDialog extends StatefulWidget {
  final Function(Patient) onSave;
  final Patient? patient;

  const PatientFormDialog({
    Key? key,
    required this.onSave,
    this.patient,
  }) : super(key: key);

  @override
  State<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<PatientFormDialog> {
  late final PatientFormState _formState = PatientFormState();

  // Overlay 相关（保留在 State 中，与 Flutter Overlay 交互紧密）
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    
    _checkEditPermissions();
    
    if (widget.patient != null) {
      _loadPatientData();
    } else {
      _initializeDefaultValues();
      _setDefaultDoctor();
    }
    
    _formState.nameController.addListener(_onNameChanged);
  }
  
  @override
  void dispose() {
    _formState.nameController.removeListener(_onNameChanged);
    _formState.dispose();
    _hideExistingPatientOverlay();
    super.dispose();
  }

  void _onNameChanged() {
    if (_formState.nameController.text.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_formState.nameController.text.isNotEmpty && mounted) {
          _checkNameExists();
        }
      });
    }
  }

  Future<void> _initializeDefaultValues() async {
    _addNewDentalChartRow();
    await _getDefaultMedicalRecordNumber();
  }

  Future<void> _setDefaultDoctor() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser ?? await userProvider.getCurrentUser();
      
      if (currentUser != null && currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
        _formState.doctorController.text = currentUser.doctor!;
      } else if (currentUser != null && currentUser.role == 'doctor') {
        _formState.doctorController.text = currentUser.username;
      } else {
        _formState.doctorController.text = '';
      }
    } catch (e) {
      print('通过UserProvider设置默认医生时出错: $e');
      _formState.doctorController.text = '';
    }
  }

  Future<void> _getDefaultMedicalRecordNumber() async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      int defaultRecordNumber = 1;

      if (patientProvider.dataSourceType == 'sqlite') {
        final db = await patientProvider.database;
        final result = await db!.query(
          'patients',
          columns: ['medical_record_number'],
          where: 'medical_record_number IS NOT NULL',
          orderBy: 'medical_record_number DESC',
          limit: 1,
        );

        if (result.isNotEmpty) {
          var maxRecordNumber = result.first['medical_record_number'];
          if (maxRecordNumber != null) {
            if (maxRecordNumber is int) {
              defaultRecordNumber = maxRecordNumber + 1;
            } else if (maxRecordNumber is String) {
              defaultRecordNumber = int.tryParse(maxRecordNumber) ?? 1;
              defaultRecordNumber += 1;
            }
          }
        }
      } else {
        final results = await patientProvider.mysqlConnection!.query(
          'SELECT medical_record_number FROM patients WHERE medical_record_number IS NOT NULL ORDER BY medical_record_number + 0 DESC LIMIT 1',
        );

        if (results.isNotEmpty && results.first['medical_record_number'] != null) {
          var maxRecordNumber = results.first['medical_record_number'];
          if (maxRecordNumber != null) {
            if (maxRecordNumber is int) {
              defaultRecordNumber = maxRecordNumber + 1;
            } else if (maxRecordNumber is String) {
              defaultRecordNumber = int.tryParse(maxRecordNumber) ?? 1;
              defaultRecordNumber += 1;
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _formState.medicalRecordController.text = defaultRecordNumber.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formState.medicalRecordController.text = '1';
        });
      }
    }
  }

  void _loadPatientData() {
    if (widget.patient != null) {
      _formState.loadFromPatient(widget.patient!);

      // 处理电话号码
      try {
        List<String> phones = widget.patient!.phoneList;

        if (phones.isNotEmpty) {
          _formState.primaryPhoneController.text = phones[0];

          if (phones.length > 1) {
            _formState.backupPhoneController.text = phones[1];
            _formState.hasBackupPhone = true;
          }
        }
      } catch (e) {
        print('处理电话时出错: $e');

        if (widget.patient!.phone is String) {
          String phoneStr = widget.patient!.phone.toString();

          if (phoneStr.startsWith('[') && phoneStr.endsWith(']')) {
            try {
              var phoneJson = jsonDecode(phoneStr);
              if (phoneJson is List && phoneJson.isNotEmpty) {
                _formState.primaryPhoneController.text = phoneJson[0].toString();

                if (phoneJson.length > 1) {
                  _formState.backupPhoneController.text = phoneJson[1].toString();
                  _formState.hasBackupPhone = true;
                }
              }
            } catch (jsonError) {
              RegExp regex = RegExp(r'"([^"]*)"');
              var matches = regex.allMatches(phoneStr);
              List<String> extractedPhones =
                  matches.map((match) => match.group(1)!).toList();

              if (extractedPhones.isNotEmpty) {
                _formState.primaryPhoneController.text = extractedPhones[0];

                if (extractedPhones.length > 1) {
                  _formState.backupPhoneController.text = extractedPhones[1];
                  _formState.hasBackupPhone = true;
                }
              } else {
                _formState.primaryPhoneController.text = phoneStr;
              }
            }
          } else {
            _formState.primaryPhoneController.text = phoneStr;
          }
        }
      }

      _loadDentalCondition();
    }
  }

  void _loadDentalCondition() {
    if (widget.patient?.dental_condition == null ||
        widget.patient!.dental_condition!.isEmpty) {
      _addNewDentalChartRow();
      return;
    }

    try {
      _formState.dentalChartRows.clear();

      Map<String, dynamic> dentalCharts = widget.patient!.dentalCharts;

      if (dentalCharts.isEmpty) {
        _addNewDentalChartRow();
        return;
      }

      int rowCount = 0;
      for (String key in dentalCharts.keys) {
        if (key.startsWith('date-')) {
          int index = int.tryParse(key.split('-').last) ?? 0;
          rowCount = rowCount > index ? rowCount : index + 1;
        }
      }

      if (rowCount == 0) {
        _addNewDentalChartRow();
        return;
      }

      List<DentalChartRow> tempRows = [];

      for (int i = 0; i < rowCount; i++) {
        String dateStr = dentalCharts['date-$i'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        DateTime chartDate;
        try {
          if (dateStr.contains('-')) {
            chartDate = DateFormat('yyyy-MM-dd').parse(dateStr);
          } else if (dateStr.contains('/')) {
            chartDate = DateFormat('yyyy/MM/dd').parse(dateStr);
          } else {
            chartDate = DateTime.parse(dateStr);
          }
        } catch (e) {
          chartDate = DateTime.now();
        }

        String createdByDoctor = dentalCharts['created_by_doctor-$i'] ?? '';

        DentalChartRow row = DentalChartRow(
          index: i,
          date: chartDate,
          createdByDoctor: createdByDoctor,
        );

        row.chart1.topLeftController.text = dentalCharts['chart1-top-left-$i'] ?? '';
        row.chart1.topRightController.text = dentalCharts['chart1-top-right-$i'] ?? '';
        row.chart1.bottomLeftController.text = dentalCharts['chart1-bottom-left-$i'] ?? '';
        row.chart1.bottomRightController.text = dentalCharts['chart1-bottom-right-$i'] ?? '';
        row.chart1.noteController.text = dentalCharts['chart1-note-$i'] ?? '';

        row.chart2.topLeftController.text = dentalCharts['chart2-top-left-$i'] ?? '';
        row.chart2.topRightController.text = dentalCharts['chart2-top-right-$i'] ?? '';
        row.chart2.bottomLeftController.text = dentalCharts['chart2-bottom-left-$i'] ?? '';
        row.chart2.bottomRightController.text = dentalCharts['chart2-bottom-right-$i'] ?? '';
        row.chart2.noteController.text = dentalCharts['chart2-note-$i'] ?? '';

        row.chart3.topLeftController.text = dentalCharts['chart3-top-left-$i'] ?? '';
        row.chart3.topRightController.text = dentalCharts['chart3-top-right-$i'] ?? '';
        row.chart3.bottomLeftController.text = dentalCharts['chart3-bottom-left-$i'] ?? '';
        row.chart3.bottomRightController.text = dentalCharts['chart3-bottom-right-$i'] ?? '';
        row.chart3.noteController.text = dentalCharts['chart3-note-$i'] ?? '';

        tempRows.add(row);
      }

      tempRows.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() {
        _formState.dentalChartRows.addAll(tempRows);
      });

      if (_formState.dentalChartRows.isEmpty) {
        _addNewDentalChartRow();
      }
    } catch (e) {
      print('加载牙齿状况时出错: $e');
      _addNewDentalChartRow();
    }
  }

  Future<Patient> _savePatientAndGetId(Patient patient) async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      if (patient.id != null) {
        await patientProvider.updatePatient(patient);
        return patient;
      } else {
        final newId = await patientProvider.addPatient(patient);
        return patient.copyWith(id: newId);
      }
    } catch (e) {
      print('保存患者失败: $e');
      rethrow;
    }
  }

  void _addNewDentalChartRow() {
    setState(() {
      _formState.dentalChartRows.add(DentalChartRow(
        index: _formState.dentalChartRows.length,
        date: DateTime.now(),
        createdByDoctor: _getCurrentDoctorName(),
      ));
      _formState.dentalChartRows.sort((a, b) => b.date.compareTo(a.date));
      for (int i = 0; i < _formState.dentalChartRows.length; i++) {
        _formState.dentalChartRows[i].index = i;
      }
    });
  }

  String _generateDentalConditionJson() {
    Map<String, String> result = {};

    for (int i = 0; i < _formState.dentalChartRows.length; i++) {
      DentalChartRow row = _formState.dentalChartRows[i];

      result['date-$i'] = DateFormat('yyyy-MM-dd').format(row.date);
      result['created_by_doctor-$i'] = row.createdByDoctor ?? _getCurrentDoctorName();

      result['chart1-top-left-$i'] = row.chart1.topLeftController.text;
      result['chart1-top-right-$i'] = row.chart1.topRightController.text;
      result['chart1-bottom-left-$i'] = row.chart1.bottomLeftController.text;
      result['chart1-bottom-right-$i'] = row.chart1.bottomRightController.text;
      result['chart1-note-$i'] = row.chart1.noteController.text;

      result['chart2-top-left-$i'] = row.chart2.topLeftController.text;
      result['chart2-top-right-$i'] = row.chart2.topRightController.text;
      result['chart2-bottom-left-$i'] = row.chart2.bottomLeftController.text;
      result['chart2-bottom-right-$i'] = row.chart2.bottomRightController.text;
      result['chart2-note-$i'] = row.chart2.noteController.text;

      result['chart3-top-left-$i'] = row.chart3.topLeftController.text;
      result['chart3-top-right-$i'] = row.chart3.topRightController.text;
      result['chart3-bottom-left-$i'] = row.chart3.bottomLeftController.text;
      result['chart3-bottom-right-$i'] = row.chart3.bottomRightController.text;
      result['chart3-note-$i'] = row.chart3.noteController.text;
    }

    return jsonEncode(result);
  }

  String _getCurrentDoctorName() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser != null) {
        return currentUser.doctor?.isNotEmpty == true 
            ? currentUser.doctor! 
            : currentUser.username;
      }
    } catch (e) {
      print('获取当前医生姓名失败: $e');
    }
    return '';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ModernDatePickerDialog(
          initialDate: _formState.firstVisitDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
      },
    );

    if (picked != null && picked != _formState.firstVisitDate) {
      setState(() {
        _formState.firstVisitDate = picked;
      });
    }
  }

  Future<void> _selectChartDate(
      BuildContext context, DentalChartRow row) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return ModernDatePickerDialog(
          initialDate: row.date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
      },
    );

    if (picked != null && picked != row.date) {
      setState(() {
        row.date = picked;
        _formState.dentalChartRows.sort((a, b) => b.date.compareTo(a.date));
        for (int i = 0; i < _formState.dentalChartRows.length; i++) {
          _formState.dentalChartRows[i].index = i;
        }
      });
    }
  }

  void _loadExistingPatientData(Patient patient) {
    setState(() {
      _formState.editingExistingPatient = patient;
      
      _formState.nameController.text = patient.name;
      _formState.ageController.text = patient.age.toString();
      _formState.primaryPhoneController.text = patient.mainPhone;
      _formState.medicalRecordController.text = patient.medical_record_number?.toString() ?? '';
      _formState.addressController.text = patient.address ?? '';
      _formState.idNumberController.text = patient.identification_number ?? '';
      _formState.doctorController.text = patient.doctor ?? '';
      _formState.treatmentItemsController.text = patient.treatment_items ?? '';
      _formState.gender = patient.gender;
      _formState.firstVisitDate = patient.first_visit_date;
      
      // 加载备用电话
      if (patient.phone != null) {
        try {
          if (patient.phone is String) {
            try {
              final phoneData = json.decode(patient.phone);
              if (phoneData is Map && phoneData.containsKey('backup') && phoneData['backup'].isNotEmpty) {
                _formState.backupPhoneController.text = phoneData['backup'];
                _formState.hasBackupPhone = true;
              } else if (phoneData is List && phoneData.length > 1) {
                _formState.backupPhoneController.text = phoneData[1].toString();
                _formState.hasBackupPhone = true;
              }
            } catch (e) {
              // 不是JSON格式
            }
          }
        } catch (e) {
          print('解析电话数据失败: $e');
        }
      }
      
      // 加载牙齿状况数据
      if (patient.dental_condition != null && patient.dental_condition!.isNotEmpty) {
        try {
          _formState.dentalChartRows.clear();
          Map<String, dynamic> dentalCharts = patient.dentalCharts;

          if (dentalCharts.isEmpty) {
            _addNewDentalChartRow();
            return;
          }

          int rowCount = 0;
          for (String key in dentalCharts.keys) {
            if (key.startsWith('date-')) {
              int index = int.tryParse(key.split('-').last) ?? 0;
              rowCount = rowCount > index ? rowCount : index + 1;
            }
          }

          if (rowCount == 0) {
            _addNewDentalChartRow();
            return;
          }

          List<DentalChartRow> tempRows = [];

          for (int i = 0; i < rowCount; i++) {
            String dateStr = dentalCharts['date-$i'] ??
                DateFormat('yyyy-MM-dd').format(DateTime.now());

            DateTime chartDate;
            try {
              if (dateStr.contains('-')) {
                chartDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              } else if (dateStr.contains('/')) {
                chartDate = DateFormat('yyyy/MM/dd').parse(dateStr);
              } else {
                chartDate = DateTime.parse(dateStr);
              }
            } catch (e) {
              chartDate = DateTime.now();
            }

            String createdByDoctor = dentalCharts['created_by_doctor-$i'] ?? '';

            DentalChartRow row = DentalChartRow(
              index: i,
              date: chartDate,
              createdByDoctor: createdByDoctor,
            );

            row.chart1.topLeftController.text = dentalCharts['chart1-top-left-$i'] ?? '';
            row.chart1.topRightController.text = dentalCharts['chart1-top-right-$i'] ?? '';
            row.chart1.bottomLeftController.text = dentalCharts['chart1-bottom-left-$i'] ?? '';
            row.chart1.bottomRightController.text = dentalCharts['chart1-bottom-right-$i'] ?? '';
            row.chart1.noteController.text = dentalCharts['chart1-note-$i'] ?? '';

            row.chart2.topLeftController.text = dentalCharts['chart2-top-left-$i'] ?? '';
            row.chart2.topRightController.text = dentalCharts['chart2-top-right-$i'] ?? '';
            row.chart2.bottomLeftController.text = dentalCharts['chart2-bottom-left-$i'] ?? '';
            row.chart2.bottomRightController.text = dentalCharts['chart2-bottom-right-$i'] ?? '';
            row.chart2.noteController.text = dentalCharts['chart2-note-$i'] ?? '';

            row.chart3.topLeftController.text = dentalCharts['chart3-top-left-$i'] ?? '';
            row.chart3.topRightController.text = dentalCharts['chart3-top-right-$i'] ?? '';
            row.chart3.bottomLeftController.text = dentalCharts['chart3-bottom-left-$i'] ?? '';
            row.chart3.bottomRightController.text = dentalCharts['chart3-bottom-right-$i'] ?? '';
            row.chart3.noteController.text = dentalCharts['chart3-note-$i'] ?? '';

            tempRows.add(row);
          }

          tempRows.sort((a, b) => b.date.compareTo(a.date));
          
          for (int i = 0; i < tempRows.length; i++) {
            tempRows[i].index = i;
          }

          _formState.dentalChartRows.addAll(tempRows);

          if (_formState.dentalChartRows.isEmpty) {
            _addNewDentalChartRow();
          }
        } catch (e) {
          print('解析牙齿状况数据失败: $e');
          _formState.dentalChartRows = [];
          _addNewDentalChartRow();
        }
      } else {
        _formState.dentalChartRows = [];
        _addNewDentalChartRow();
      }
    });
  }

  void _checkNameExists() async {
    if (_formState.nameController.text.isEmpty) {
      return;
    }

    final patientProvider = Provider.of<PatientProvider>(context, listen: false);

    try {
      bool nameExists = await patientProvider.checkPatientNameExists(
          _formState.nameController.text, _formState.excludePatientId ?? widget.patient?.id);

      if (nameExists) {
        List<Patient> patients =
            await patientProvider.searchPatients(_formState.nameController.text);
        
        if (patients.isNotEmpty) {
          for (var patient in patients) {
            if (patient.name == _formState.nameController.text &&
                patient.id != (_formState.excludePatientId ?? widget.patient?.id)) {
              setState(() {
                _formState.existingPatient = patient;
              });
              _showExistingPatientOverlay();
              return;
            }
          }
        }
        
        await _tryDirectDatabaseQuery(_formState.nameController.text);
      } else {
        setState(() {
          _formState.existingPatient = null;
          _hideExistingPatientOverlay();
        });
      }
    } catch (e) {
      print('检查姓名时出错: $e');
    }
  }
  
  Future<void> _tryDirectDatabaseQuery(String name) async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      if (patientProvider.dataSourceType == 'sqlite') {
        final db = await patientProvider.database;
        if (db != null) {
          final result = await db.query(
            'patients',
            where: 'name = ?',
            whereArgs: [name],
          );
          
          if (result.isNotEmpty) {
            final patient = Patient.fromMap(result.first);
            setState(() {
              _formState.existingPatient = patient;
            });
            _showExistingPatientOverlay();
          }
        }
      } else if (patientProvider.dataSourceType == 'mysql') {
        try {
          final results = await patientProvider.mysqlConnection!.query(
            'SELECT * FROM patients WHERE name = ?',
            [name],
          );
          
          if (results.isNotEmpty) {
            final mysqlRow = results.first;
            final Map<String, dynamic> patientMap = {};
            
            for (var field in mysqlRow.fields.keys) {
              var value = mysqlRow[field];
              if (value is Uint8List) {
                try {
                  patientMap[field] = utf8.decode(value, allowMalformed: true);
                } catch (e) {
                  patientMap[field] = '';
                }
              } else if (value is List<int>) {
                try {
                  patientMap[field] = utf8.decode(value, allowMalformed: true);
                } catch (e) {
                  patientMap[field] = '';
                }
              } else {
                patientMap[field] = value;
              }
            }
           
            final patient = Patient.fromMap(patientMap);
            setState(() {
              _formState.existingPatient = patient;
            });
            _showExistingPatientOverlay();
          }
        } catch (mysqlError) {
          print('MySQL查询出错: $mysqlError');
        }
      }
    } catch (e) {
      print('直接查询数据库时出错: $e');
    }
  }

  void _showExistingPatientOverlay() {
    if (_formState.existingPatient == null) {
      return;
    }

    _hideExistingPatientOverlay();

    final overlay = Overlay.of(context);

    _overlayEntry = ExistingPatientOverlayBuilder.buildOverlayEntry(
      existingPatient: _formState.existingPatient!,
      nameFieldKey: _formState.nameFieldKey,
      context: context,
      onContinue: () {
        _hideExistingPatientOverlay();
        setState(() {
          _formState.editingExistingPatient = null;
        });
      },
      onLoadExisting: () {
        _hideExistingPatientOverlay();
        if (_formState.existingPatient != null) {
          _loadExistingPatientData(_formState.existingPatient!);
        }
      },
      onClose: _hideExistingPatientOverlay,
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideExistingPatientOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          gradient: DentalColors.backgroundGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: DentalColors.shadowMedium,
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: DentalColors.shadowLight,
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: DentalColors.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PatientFormHeader(
                isEditingExistingPatient: _formState.editingExistingPatient != null,
                isNewPatient: widget.patient == null,
                editingPatientName: _formState.editingExistingPatient?.name,
                onClose: () => Navigator.of(context).pop(),
              ),
              
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formState.formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_formState.canEditBasicInfo)
                          const PatientFormPermissionNotice(),
                        
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _formState.scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PatientFormBasicSection(
                                  medicalRecordController:
                                      _formState.medicalRecordController,
                                  nameController: _formState.nameController,
                                  ageController: _formState.ageController,
                                  doctorController: _formState.doctorController,
                                  nameFieldKey: _formState.nameFieldKey,
                                  canEditBasicInfo: _formState.canEditBasicInfo,
                                  gender: _formState.gender,
                                  firstVisitDate: _formState.firstVisitDate,
                                  onNameTap: () => _hideExistingPatientOverlay(),
                                  onNameSubmitted: (value) =>
                                      _checkNameExists(),
                                  onGenderChanged: (value) {
                                    if (value != null) {
                                      setState(() => _formState.gender = value);
                                    }
                                  },
                                  onSelectDate: () => _selectDate(context),
                                ),
                                const SizedBox(height: 12),

                                PatientFormContactSection(
                                  primaryPhoneController:
                                      _formState.primaryPhoneController,
                                  backupPhoneController:
                                      _formState.backupPhoneController,
                                  idNumberController: _formState.idNumberController,
                                  addressController: _formState.addressController,
                                  hasBackupPhone: _formState.hasBackupPhone,
                                  canEditBasicInfo: _formState.canEditBasicInfo,
                                  onToggleBackupPhone: () {
                                    setState(() {
                                      _formState.hasBackupPhone = !_formState.hasBackupPhone;
                                      if (!_formState.hasBackupPhone) {
                                        _formState.backupPhoneController.clear();
                                      }
                                    });
                                  },
                                ),

                                PatientFormDentalConditionSection(
                                  child: _buildDentalConditionSection(),
                                ),
                                const SizedBox(height: 16),

                                PatientFormTreatmentSection(
                                  treatmentItemsController:
                                      _formState.treatmentItemsController,
                                  canEditBasicInfo: _formState.canEditBasicInfo,
                                ),
                              ],
                            ),
                          ),
                        ),

                        PatientFormActions(
                          isLoading: _formState.isLoading,
                          isEditMode: widget.patient != null,
                          onCancel: () => Navigator.of(context).pop(),
                          onSave: _handleSave,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_formState.formKey.currentState!.validate()) {
      setState(() {
        _formState.isLoading = true;
      });

      try {
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        bool canProceed = true;

        // 检查病历号是否重复
        if (_formState.medicalRecordController.text.isNotEmpty) {
          int medicalRecordNumber =
              int.parse(_formState.medicalRecordController.text);
          bool medicalRecordExists =
              await patientProvider.checkMedicalRecordExists(
                  medicalRecordNumber, _formState.excludePatientId ?? widget.patient?.id);

          if (medicalRecordExists) {
            await showDialog(
              context: context,
              builder: (context) => const DuplicateMedicalRecordDialog(),
            );
            canProceed = false;
          }
        }

        // 检查姓名是否重复
        if (canProceed) {
          bool nameExists =
              await patientProvider.checkPatientNameExists(
                  _formState.nameController.text, _formState.excludePatientId ?? widget.patient?.id);

          if (nameExists) {
            List<Patient> existingPatients = await patientProvider.searchPatients(_formState.nameController.text);
            Patient? selectedPatient;

            for (var patient in existingPatients) {
              if (patient.name == _formState.nameController.text &&
                  patient.id != (_formState.excludePatientId ?? widget.patient?.id)) {
                selectedPatient = patient;
                break;
              }
            }

            if (selectedPatient != null) {
              final bool? shouldLoadExisting = await showDialog<bool>(
                context: context,
                builder: (context) =>
                    ExistingPatientChoiceDialog(patient: selectedPatient!),
              );

              if (shouldLoadExisting == true) {
                _loadExistingPatientData(selectedPatient);
                return;
              } else if (shouldLoadExisting == false) {
                setState(() {
                  _formState.editingExistingPatient = null;
                });
                canProceed = true;
              } else {
                canProceed = false;
              }
            } else {
              canProceed = false;
            }
          }
        }

        if (!canProceed) {
          return;
        }

        // 构建电话号码数据
        final phoneRawData = _formState.buildPhoneData();
        dynamic phoneData;
        if (phoneRawData is List) {
          phoneData = jsonEncode(phoneRawData);
        } else {
          phoneData = phoneRawData;
        }

        // 生成牙齿状况JSON
        String dentalCondition = _generateDentalConditionJson();

        // 创建患者对象
        final Patient patient = Patient(
          id: _formState.editingExistingPatient?.id ?? widget.patient?.id,
          name: _formState.nameController.text,
          name_pinyin: (_formState.editingExistingPatient ?? widget.patient)
              ?.name_pinyin,
          age: _formState.ageController.text.isNotEmpty
              ? int.parse(_formState.ageController.text)
              : 0,
          gender: _formState.gender,
          phone: phoneData,
          medical_record_number:
              _formState.medicalRecordController.text.isNotEmpty
                  ? int.parse(_formState.medicalRecordController.text)
                  : null,
          address: _formState.addressController.text.isNotEmpty
              ? _formState.addressController.text
              : null,
          address_pinyin: (_formState.editingExistingPatient ?? widget.patient)
              ?.address_pinyin,
          identification_number:
              _formState.idNumberController.text.isNotEmpty
                  ? _formState.idNumberController.text
                  : null,
          doctor: _formState.doctorController.text.isNotEmpty
              ? _formState.doctorController.text
              : null,
          dental_condition:
              dentalCondition.isNotEmpty ? dentalCondition : null,
          treatment_items:
              _formState.treatmentItemsController.text.isNotEmpty
                  ? _formState.treatmentItemsController.text
                  : null,
          first_visit_date: _formState.firstVisitDate,
          total_cost: (_formState.editingExistingPatient ?? widget.patient)?.total_cost ?? 0.0,
          created_at: (_formState.editingExistingPatient ?? widget.patient)?.created_at ??
              DateTime.now(),
          updated_at: DateTime.now(),
        );

        final savedPatient = await _savePatientAndGetId(patient);

        widget.onSave(savedPatient);

        Navigator.of(context).pop();
      } finally {
        setState(() {
          _formState.isLoading = false;
        });
      }
    }
  }

  Widget _buildDentalConditionSection() {
    return PatientFormDentalSection(
      rows: _formState.dentalChartRows,
      onAddRow: _addNewDentalChartRow,
      onSelectDate: (row) => _selectChartDate(context, row),
      onDeleteRow: (row) {
        setState(() {
          _formState.dentalChartRows.remove(row);
          for (int i = 0; i < _formState.dentalChartRows.length; i++) {
            _formState.dentalChartRows[i].index = i;
          }
        });
      },
      canEditRow: _canEditDentalChartRow,
      canDeleteRow: _canDeleteDentalChartRow,
    );
  }
  
  void _checkEditPermissions() {
    if (widget.patient != null) {
      _formState.canEditBasicInfo = PermissionUtils.canEditDoctor(context, widget.patient!.doctor);
    } else {
      _formState.canEditBasicInfo = true;
    }
  }

  bool _canEditDentalChartRow(DentalChartRow row) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        return false;
      }
      
      if (currentUser.role == 'admin') {
        return true;
      }
      
      if (row.createdByDoctor == null || row.createdByDoctor!.isEmpty) {
        return false;
      }
      
      String currentDoctorName = currentUser.doctor?.isNotEmpty == true 
          ? currentUser.doctor! 
          : currentUser.username;
      
      return row.createdByDoctor == currentDoctorName;
    } catch (e) {
      print('检查牙齿状况编辑权限时出错: $e');
      return false;
    }
  }

  bool _canDeleteDentalChartRow(DentalChartRow row) {
    return _canEditDentalChartRow(row);
  }

}
