import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import '../theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../models/patient.dart';
import '../providers/app_state.dart';
import './patient_detail_screen.dart';
import '../widgets/patient_form_dialog.dart';
import '../widgets/patient_export_dialog.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({Key? key}) : super(key: key);

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Patient> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentPage = 1;
  final int _patientsPerPage = 10;
  int _totalPatients = 0;

  // 排序相关变量
  String _sortField = 'updated_at'; // 默认按更新时间排序
  bool _sortAscending = false; // 默认倒序排序（最新的在前面）

  // 日期过滤相关变量
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showDateFilter = false;
  String _dateFilterType = 'first_visit_date'; // 默认按首诊时间筛选

  // 高级搜索相关变量
  bool _showAdvancedSearch = false;
  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _addressSearchController =
      TextEditingController();
  final TextEditingController _phoneSearchController = TextEditingController();
  final TextEditingController _doctorSearchController = TextEditingController();
  final TextEditingController _medicalRecordSearchController =
      TextEditingController();

  // 页面状态变量
  bool _isSearching = false;
  bool _hasSearchResults = false;
  bool _isAdvancedSearchVisible = false;

  // 添加一个变量来存储当前的高级搜索条件
  Map<String, String>? _currentAdvancedCriteria;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查数据库提供者中的刷新标志
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    if (dbProvider.patientsNeedRefresh) {
      // 如果患者数据需要刷新，则重新加载
      _loadPatients();
      // 重置刷新标志
      dbProvider.resetPatientsRefreshFlag();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // 释放高级搜索控制器
    _nameSearchController.dispose();
    _addressSearchController.dispose();
    _phoneSearchController.dispose();
    _doctorSearchController.dispose();
    _medicalRecordSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 判断是否正在使用高级搜索
      if (_currentAdvancedCriteria != null &&
          _currentAdvancedCriteria!.isNotEmpty) {
        await _loadPatientsWithAdvancedSearch();
        return;
      }

      // 原有的加载逻辑
      Map<String, dynamic> patientsData = await dbProvider.getPatientsPage(
        page: _currentPage,
        pageSize: _patientsPerPage,
        searchQuery: _searchQuery,
        sortField: _sortField,
        sortAscending: _sortAscending,
        startDate: _startDate,
        endDate: _endDate,
        dateFilterType: _dateFilterType,
      );

      setState(() {
        _patients = patientsData['patients'];
        _totalPatients = patientsData['totalCount'];
        _isLoading = false;
        _hasSearchResults = _searchQuery.isNotEmpty;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载患者数据失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _searchPatients() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _currentPage = 1;
      // 重置总记录数，等待搜索完成后更新
      if (_searchQuery.isNotEmpty) {
        _totalPatients = 0;
      }
    });
    _loadPatients();
  }

  void _changeSort(String field) {
    setState(() {
      if (_sortField == field) {
        // 如果点击的是当前排序字段，则切换排序方向
        _sortAscending = !_sortAscending;
      } else {
        // 否则更改排序项并设置为降序
        _sortField = field;
        _sortAscending = false;
      }
      _currentPage = 1; // 重置到第一页
    });
    _loadPatients();
    // 仅在客户端排序时使用
    // _sortPatients();
    // _debugSortIssue();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _showDateFilter = false;
      _currentPage = 1;
      // 不清除搜索状态，以便在搜索结果上进行操作
    });
    _loadPatients();
  }

  Future<void> _selectDateRange() async {
    // 使用自定义对话框代替系统日期选择器
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (BuildContext context) {
        DateTime startDate =
            _startDate ?? DateTime.now().subtract(const Duration(days: 30));
        DateTime endDate = _endDate ?? DateTime.now();

        return AlertDialog(
          title: Text(
              '选择${_dateFilterType == 'first_visit_date' ? '首诊' : '更新'}时间范围${_searchQuery.isNotEmpty ? " (应用于搜索结果)" : ""}'),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        label: '开始日期',
                        initialDate: startDate,
                        onDateSelected: (date) {
                          startDate = date;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateField(
                        label: '结束日期',
                        initialDate: endDate,
                        onDateSelected: (date) {
                          endDate = date;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // 确保结束日期不早于开始日期
                if (endDate.isBefore(startDate)) {
                  endDate = startDate;
                }
                Navigator.of(context).pop({
                  'startDate': startDate,
                  'endDate': endDate,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _startDate = result['startDate'];
        _endDate = result['endDate'];
        _currentPage = 1; // 重置到第一页
      });
      _loadPatients();
    }
  }

  // 构建日期输入字段
  Widget _buildDateField({
    required String label,
    required DateTime initialDate,
    required Function(DateTime) onDateSelected,
  }) {
    final TextEditingController controller = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(initialDate),
    );

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 18),
          onPressed: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (BuildContext context, Widget? child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppTheme.primaryColor,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              controller.text = DateFormat('yyyy-MM-dd').format(picked);
              onDateSelected(picked);
            }
          },
        ),
      ),
      readOnly: true, // 不允许直接编辑，只能通过日期选择器选择
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          controller.text = DateFormat('yyyy-MM-dd').format(picked);
          onDateSelected(picked);
        }
      },
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  void _addPatient() {
    // 打开添加患者对话框
    showDialog(
      context: context,
      builder: (context) => PatientFormDialog(
        onSave: (Patient patient) {
          // 添加新患者到数据库
          _savePatient(patient);
        },
      ),
    );
  }

  // 保存患者数据
  Future<void> _savePatient(Patient patient) async {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 添加患者
      await dbProvider.addPatient(patient);

      // 标记患者数据需要刷新
      dbProvider.markPatientsNeedRefresh();

      // 刷新数据
      await _loadPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('患者添加成功'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加患者失败: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _viewPatientDetails(Patient patient) {
    // 打开患者详情页面
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patientId: patient.id!),
      ),
    )
        .then((_) {
      // 返回后刷新数据
      _loadPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = (_totalPatients / _patientsPerPage).ceil();

    // 确保总页数至少为1
    final int displayTotalPages = totalPages > 0 ? totalPages : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('患者管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _showExportDialog(context),
            tooltip: '导出患者数据',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatients,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          if (_showDateFilter) _buildDateFilterChip(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 64,
                              color: AppTheme.lightText,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? '暂无患者记录' : '未找到匹配的搜索结果',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _addPatient,
                              icon: const Icon(Icons.add),
                              label: const Text('添加患者'),
                              style: AppTheme.primaryButtonStyle,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: _buildPatientsList(),
                          ),
                          // 总是显示分页，但确保至少有一页
                          _buildPagination(displayTotalPages),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: _patients.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addPatient,
              backgroundColor: AppTheme.primaryColor,
              heroTag: 'patients_add_button',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _searchPatients(),
                    decoration: InputDecoration(
                      hintText: '快速搜索患者姓名、拼音、电话、地址等',
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.secondaryText),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                                _loadPatients();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAdvancedSearch = !_showAdvancedSearch;
                    // 切换高级搜索时清空搜索框
                    if (_showAdvancedSearch) {
                      _searchController.clear();
                    } else {
                      _clearAdvancedSearch();
                    }
                  });
                },
                icon: Icon(_showAdvancedSearch
                    ? Icons.arrow_upward
                    : Icons.filter_list),
                label: Text(_showAdvancedSearch ? '收起高级搜索' : '高级搜索'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addPatient,
                icon: const Icon(Icons.add),
                label: const Text('添加患者'),
                style: AppTheme.primaryButtonStyle,
              ),
            ],
          ),
          if (_showAdvancedSearch) _buildAdvancedSearchFields(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPurpleTheme ? AppTheme.purpleCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isPurpleTheme
            ? Border.all(
                color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
            : null,
        boxShadow: isPurpleTheme
            ? [
                BoxShadow(
                  color: AppTheme.purpleColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSortOptions(),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showDateFilter = !_showDateFilter;
                    if (!_showDateFilter) {
                      _startDate = null;
                      _endDate = null;
                      _loadPatients();
                    }
                  });
                },
                icon:
                    Icon(_showDateFilter ? Icons.date_range : Icons.filter_alt),
                label: Text(_showDateFilter
                    ? '隐藏时间筛选'
                    : '时间筛选${_searchQuery.isNotEmpty ? " (搜索结果)" : ""}'),
                style: TextButton.styleFrom(
                  foregroundColor: isPurpleTheme
                      ? AppTheme.purpleColor
                      : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortOptions() {
    return Row(
      children: [
        const Text('排序方式：', style: TextStyle(color: AppTheme.secondaryText)),
        const SizedBox(width: 8),
        _buildSortButton('更新时间 ↓', 'updated_at'),
        const SizedBox(width: 8),
        _buildSortButton('姓名', 'name'),
        const SizedBox(width: 8),
        _buildSortButton('年龄', 'age'),
        const SizedBox(width: 8),
        _buildSortButton('病历号', 'medical_record_number'),
      ],
    );
  }

  Widget _buildSortButton(String label, String field) {
    final bool isActive = _sortField == field;

    return InkWell(
      onTap: () => _changeSort(field),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    isActive ? AppTheme.primaryColor : AppTheme.secondaryText,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: AppTheme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          // 添加时间筛选类型选择
          Row(
            children: [
              Text(
                _searchQuery.isEmpty ? '按:' : '搜索结果筛选:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('首诊时间'),
                selected: _dateFilterType == 'first_visit_date',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _dateFilterType = 'first_visit_date');
                    if (_startDate != null && _endDate != null) {
                      _loadPatients();
                    }
                  }
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _dateFilterType == 'first_visit_date'
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryText,
                  fontWeight: _dateFilterType == 'first_visit_date'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('更新时间'),
                selected: _dateFilterType == 'updated_at',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _dateFilterType = 'updated_at');
                    if (_startDate != null && _endDate != null) {
                      _loadPatients();
                    }
                  }
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _dateFilterType == 'updated_at'
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryText,
                  fontWeight: _dateFilterType == 'updated_at'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('yyyy-MM-dd').format(_startDate!)} 至 ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                              : '选择日期范围',
                          style: TextStyle(
                            color: _startDate != null
                                ? AppTheme.primaryText
                                : AppTheme.secondaryText,
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              if (_startDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearFilters,
                  tooltip: '清除筛选',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsList() {
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return ListView.builder(
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        final patientName = patient.name;
        final patientGender = patient.gender;
        final patientCondition = patient.dental_condition;
        final patientTreatment = patient.treatment_items;

        // 根据性别决定头像背景和图标颜色
        final Color avatarBgColor = patientGender == '女'
            ? Color(0xFFF48FB1).withOpacity(0.2)
            : Colors.blue.withOpacity(0.1);
        final Color avatarTextColor =
            patientGender == '女' ? Color(0xFFEC407A) : Colors.blue;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: isPurpleTheme ? 0 : 1, // 紫色主题下不使用默认阴影
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isPurpleTheme
                ? BorderSide(
                    color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
                : BorderSide.none,
          ),
          shadowColor:
              isPurpleTheme ? AppTheme.purpleColor.withOpacity(0.1) : null,
          color: isPurpleTheme ? AppTheme.purpleCardBackground : null,
          child: InkWell(
            onTap: () => _viewPatientDetails(patient),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 患者头像 - 根据性别设置颜色
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: avatarBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        patientName.isNotEmpty ? patientName[0] : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: avatarTextColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 姓名和基本信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: avatarBgColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${patient.age}岁 ${patient.gender}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: avatarTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 病历号和首诊时间
                        Row(
                          children: [
                            if (patient.medical_record_number != null) ...[
                              Icon(
                                Icons.assignment_ind,
                                size: 16,
                                color: AppTheme.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '病历号: ${patient.medical_record_number}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Icon(
                              Icons.event,
                              size: 16,
                              color: AppTheme.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '首诊: ${DateFormat('yyyy-MM-dd').format(patient.first_visit_date)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 联系方式和地址
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: AppTheme.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getDisplayPhone(patient.phone),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                            if (patient.address != null &&
                                patient.address!.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppTheme.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  patient.address!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.secondaryText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 操作按钮
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        tooltip: '查看',
                        onPressed: () => _viewPatientDetails(patient),
                        color: AppTheme.primaryColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 36,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: '编辑',
                        onPressed: () => _editPatient(patient),
                        color: AppTheme.accentColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 36,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outlined, size: 20),
                        tooltip: '删除',
                        onPressed: () => _confirmDeletePatient(patient),
                        color: AppTheme.errorColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination(int totalPages) {
    // 确保底部条始终显示正确的结果数和页数
    final String resultText;
    if (_searchQuery.isEmpty && _startDate == null) {
      // 没有搜索和日期筛选
      resultText = '共 $_totalPatients 条记录，$totalPages 页';
    } else if (_searchQuery.isNotEmpty && _startDate == null) {
      // 只有搜索，没有日期筛选
      resultText = '搜索结果：$_totalPatients 条记录，$totalPages 页';
    } else if (_searchQuery.isEmpty && _startDate != null) {
      // 只有日期筛选，没有搜索
      resultText = '筛选结果：$_totalPatients 条记录，$totalPages 页';
    } else {
      // 既有搜索又有日期筛选
      resultText = '筛选后结果：$_totalPatients 条记录，$totalPages 页';
    }

    print(
        '构建分页: 搜索词="$_searchQuery", 日期筛选=${_startDate != null}, 总记录数=$_totalPatients, 总页数=$totalPages');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭头
          _buildPaginationButton(
            icon: Icons.keyboard_arrow_left,
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                    _loadPatients();
                  }
                : null,
            isActive: _currentPage > 1,
          ),

          const SizedBox(width: 8),

          // 页码
          ...List.generate(
            totalPages > 5 ? 5 : totalPages,
            (index) {
              int pageNumber;
              if (totalPages <= 5) {
                pageNumber = index + 1;
              } else {
                if (_currentPage <= 3) {
                  pageNumber = index + 1;
                } else if (_currentPage >= totalPages - 2) {
                  pageNumber = totalPages - 4 + index;
                } else {
                  pageNumber = _currentPage - 2 + index;
                }
              }

              bool isCurrentPage = pageNumber == _currentPage;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: isCurrentPage ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  elevation: isCurrentPage ? 2 : 0,
                  child: InkWell(
                    onTap: isCurrentPage
                        ? null
                        : () {
                            setState(() {
                              _currentPage = pageNumber;
                            });
                            _loadPatients();
                          },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: isCurrentPage
                            ? null
                            : Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Text(
                        '$pageNumber',
                        style: TextStyle(
                          color: isCurrentPage
                              ? Colors.white
                              : AppTheme.primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          // 右箭头
          _buildPaginationButton(
            icon: Icons.keyboard_arrow_right,
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                    _loadPatients();
                  }
                : null,
            isActive: _currentPage < totalPages,
          ),

          // 页面信息与跳转组
          Container(
            margin: const EdgeInsets.only(left: 24),
            child: Row(
              children: [
                // 页面信息
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Text(
                    resultText,
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ),

                // 页码跳转
                if (totalPages > 5) // 只在页数较多时显示
                  _buildPageJumper(totalPages),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建分页按钮
  Widget _buildPaginationButton({
    required IconData icon,
    required Function()? onPressed,
    required bool isActive,
  }) {
    return Material(
      color: isActive ? Colors.white : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(6),
      elevation: isActive ? 1 : 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppTheme.dividerColor : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? AppTheme.primaryColor : AppTheme.lightText,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildPageJumper(int totalPages) {
    final TextEditingController _jumpController = TextEditingController();

    void _jumpToPage() {
      if (_jumpController.text.isNotEmpty) {
        try {
          int targetPage = int.parse(_jumpController.text);
          if (targetPage > 0 && targetPage <= totalPages) {
            setState(() {
              _currentPage = targetPage;
            });
            _loadPatients();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('请输入1到$totalPages之间的页码')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入有效的页码')),
          );
        }
      }
    }

    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.dividerColor),
        color: Colors.white,
      ),
      child: Row(
        children: [
          // 转到 文字
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: 38,
            alignment: Alignment.center,
            child: const Text(
              '转到',
              style: TextStyle(fontSize: 14, color: AppTheme.secondaryText),
            ),
          ),

          // 输入框
          Container(
            width: 55,
            height: 38,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.dividerColor),
                right: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            child: TextField(
              controller: _jumpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '页码',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (_) => _jumpToPage(),
            ),
          ),

          // 跳转按钮
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _jumpToPage,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(5),
                bottomRight: Radius.circular(5),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 38,
                alignment: Alignment.center,
                child: Text(
                  '确定',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(Patient patient) {
    if (patient.total_cost != null && patient.total_cost > 0) {
      return AppTheme.successColor;
    } else {
      return AppTheme.warningColor;
    }
  }

  String _getStatusText(Patient patient) {
    if (patient.total_cost != null && patient.total_cost > 0) {
      return '已治疗';
    } else {
      return '待治疗';
    }
  }

  // 添加编辑患者的方法
  void _editPatient(Patient patient) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // 从数据库获取最新的患者信息，确保包含完整的牙齿状况数据
    Patient? freshPatient;
    try {
      if (patient.id != null) {
        print('编辑前获取最新患者数据: ID ${patient.id}');
        freshPatient = await dbProvider.getPatient(patient.id!);
        if (freshPatient == null) {
          print('无法获取最新患者数据，使用列表中的患者数据');
          freshPatient = patient;
        } else {
          print(
              '成功获取最新患者数据，包含牙齿状况: ${freshPatient.dental_condition?.substring(0, 50)}...');
        }
      } else {
        freshPatient = patient;
      }
    } catch (e) {
      print('获取最新患者数据失败: $e，使用列表中的患者数据');
      freshPatient = patient;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => PatientFormDialog(
        patient: freshPatient,
        onSave: (updatedPatient) {
          // 更新患者数据
          _updatePatient(updatedPatient);
        },
      ),
    );
  }

  // 处理患者更新
  Future<void> _updatePatient(Patient updatedPatient) async {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 更新患者
      await dbProvider.updatePatient(updatedPatient);

      // 明确标记患者数据需要刷新
      dbProvider.markPatientsNeedRefresh();

      // 刷新列表
      await _loadPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('患者信息已更新'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新患者信息失败: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // 添加确认删除患者的方法
  Future<void> _confirmDeletePatient(Patient patient) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除患者 ${patient.name} 的记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deletePatient(patient);
    }
  }

  // 添加删除患者的方法
  Future<void> _deletePatient(Patient patient) async {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 删除患者
      await dbProvider.deletePatient(patient.id!);

      // 明确标记患者数据需要刷新
      dbProvider.markPatientsNeedRefresh();

      // 刷新列表
      await _loadPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('患者已删除'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除患者失败: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // 显示导出对话框
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PatientExportDialog(
          searchQuery: _searchQuery,
          sortField: _sortField,
          sortAscending: _sortAscending,
          startDate: _startDate,
          endDate: _endDate,
          dateFilterType: _dateFilterType,
        );
      },
    );
  }

  // 在界面右上角的操作栏中添加导出按钮
  Widget _buildActions() {
    return Row(
      children: [
        // 导出按钮
        IconButton(
          icon: const Icon(Icons.file_download),
          tooltip: '导出患者数据',
          onPressed: () => _showExportDialog(context),
        ),
        // 添加新患者按钮
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '添加新患者',
          onPressed: _addPatient,
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.secondaryText,
          ),
        ),
      ],
    );
  }

  void _sortPatients() {
    setState(() {
      switch (_sortField) {
        case 'name':
          _patients.sort(
            (a, b) => _sortAscending
                ? a.name.compareTo(b.name)
                : b.name.compareTo(a.name),
          );
          break;
        case 'age':
          _patients.sort(
            (a, b) => _sortAscending
                ? a.age.compareTo(b.age)
                : b.age.compareTo(a.age),
          );
          break;
        case 'first_visit_date':
          _patients.sort(
            (a, b) => _sortAscending
                ? a.first_visit_date.compareTo(b.first_visit_date)
                : b.first_visit_date.compareTo(a.first_visit_date),
          );
          break;
        case 'medical_record_number':
          // 确保按数值而非字符串排序病历号
          _patients.sort(
            (a, b) {
              // 如果病历号为空，则排在最后
              if (a.medical_record_number == null)
                return _sortAscending ? 1 : -1;
              if (b.medical_record_number == null)
                return _sortAscending ? -1 : 1;

              // 数值比较
              int aNum = a.medical_record_number!;
              int bNum = b.medical_record_number!;
              return _sortAscending
                  ? aNum.compareTo(bNum)
                  : bNum.compareTo(aNum);
            },
          );
          break;
        case 'updated_at':
        default:
          // 确保使用更新时间字段
          _patients.sort(
            (a, b) => _sortAscending
                ? a.updated_at.compareTo(b.updated_at)
                : b.updated_at.compareTo(a.updated_at),
          );
          break;
      }
    });

    // 调试打印排序结果
    if (_sortField == 'medical_record_number' && _patients.isNotEmpty) {
      print('按病历号排序结果:');
      for (int i = 0; i < math.min(10, _patients.length); i++) {
        print(
            '病历号[$i]: ${_patients[i].medical_record_number ?? "空"}, 姓名: ${_patients[i].name}');
      }
    }
  }

  // 添加调试方法，帮助排查排序问题
  void _debugSortIssue() {
    if (_patients.isEmpty) return;

    print('排序字段: $_sortField, 升序: $_sortAscending, 患者数量: ${_patients.length}');

    // 打印前5个患者的关键信息
    for (int i = 0; i < math.min(5, _patients.length); i++) {
      final patient = _patients[i];
      print(
          '患者[$i]: 姓名=${patient.name}, ID=${patient.id}, 更新时间=${patient.updated_at}');
    }
  }

  // 修改排序选项对话框
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    '排序选项',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按修改日期排序',
                  icon: Icons.update,
                  isSelected: _sortField == 'updated_at',
                  isAscending: _sortAscending,
                  onTap: () {
                    _changeSort('updated_at');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按姓名排序',
                  icon: Icons.person,
                  isSelected: _sortField == 'name',
                  isAscending: _sortAscending,
                  onTap: () {
                    _changeSort('name');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按年龄排序',
                  icon: Icons.sort,
                  isSelected: _sortField == 'age',
                  isAscending: _sortAscending,
                  onTap: () {
                    _changeSort('age');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按首诊日期排序',
                  icon: Icons.date_range,
                  isSelected: _sortField == 'first_visit_date',
                  isAscending: _sortAscending,
                  onTap: () {
                    _changeSort('first_visit_date');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isAscending,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryText,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Icon(
        isAscending ? Icons.arrow_upward : Icons.arrow_downward,
        size: 16,
        color: AppTheme.secondaryText,
      ),
      onTap: onTap,
    );
  }

  // 刷新拼音数据
  Future<void> _refreshPinyinData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      await dbProvider.updateAllPatientsPinyin();

      // 重新加载患者数据
      await _loadPatients();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('拼音数据已更新'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新拼音数据失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFilterCard() {
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: isPurpleTheme ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isPurpleTheme
            ? BorderSide(
                color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      shadowColor: isPurpleTheme ? AppTheme.purpleColor.withOpacity(0.1) : null,
      color: isPurpleTheme ? AppTheme.purpleCardBackground : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        // 其余部分保持不变...
      ),
    );
  }

  Widget _buildPatientStatsBar() {
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPurpleTheme ? AppTheme.purpleCardBackground : Colors.white,
        border: isPurpleTheme
            ? Border.all(
                color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
            : null,
        boxShadow: isPurpleTheme
            ? [
                BoxShadow(
                  color: AppTheme.purpleColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            _searchQuery.isNotEmpty
                ? '共找到 $_totalPatients 位患者'
                : '共有 $_totalPatients 位患者',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPurpleTheme
                  ? AppTheme.purplePrimaryText
                  : AppTheme.primaryText,
            ),
          ),
          const Spacer(),
          if (_totalPatients > 0 && _patientsPerPage < _totalPatients)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                          _loadPatients();
                        }
                      : null,
                  splashRadius: 20,
                  color: isPurpleTheme
                      ? AppTheme.purpleColor
                      : AppTheme.primaryColor,
                  disabledColor: isPurpleTheme
                      ? AppTheme.purpleLightColor.withOpacity(0.3)
                      : Colors.grey.shade300,
                ),
                Text(
                  '第 $_currentPage 页',
                  style: TextStyle(
                    fontSize: 14,
                    color: isPurpleTheme
                        ? AppTheme.purpleSecondaryText
                        : AppTheme.secondaryText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed:
                      _currentPage < (_totalPatients / _patientsPerPage).ceil()
                          ? () {
                              setState(() {
                                _currentPage++;
                              });
                              _loadPatients();
                            }
                          : null,
                  splashRadius: 20,
                  color: isPurpleTheme
                      ? AppTheme.purpleColor
                      : AppTheme.primaryColor,
                  disabledColor: isPurpleTheme
                      ? AppTheme.purpleLightColor.withOpacity(0.3)
                      : Colors.grey.shade300,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Patient patient) {
    // 获取显示的电话号码（如果是JSON格式，显示第一个）
    final displayPhone = _getDisplayPhone(patient.phone);

    // 为每个患者生成一个稳定的随机颜色，基于姓名
    final int colorSeed = patient.name.hashCode;
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      AppTheme.infoColor,
      AppTheme.successColor,
      AppTheme.warningColor,
    ];
    final patientColor = colors[colorSeed % colors.length];

    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPurpleTheme
            ? AppTheme.purpleCardBackground
            : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        boxShadow: isPurpleTheme
            ? [
                BoxShadow(
                  color: AppTheme.purpleColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : AppTheme.cardShadow,
        border: isPurpleTheme
            ? Border.all(
                color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
            : null,
      ),
      child: InkWell(
        onTap: () {
          _viewPatientDetails(patient);
        },
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          // 其余部分保持不变...
        ),
      ),
    );
  }

  String _getDisplayPhone(String phone) {
    if (phone.isEmpty) {
      return "未设置";
    }

    // 判断是否为JSON格式
    if (phone.startsWith('[') && phone.endsWith(']')) {
      try {
        // 尝试解析JSON
        List<dynamic> phones = jsonDecode(phone);
        if (phones.isNotEmpty) {
          // 如果有多个号码，显示第一个并加上提示
          if (phones.length > 1) {
            return "${phones[0]} (+${phones.length - 1})";
          } else {
            return phones[0].toString();
          }
        } else {
          return "未设置";
        }
      } catch (e) {
        print('解析电话号码JSON失败: $e');
        // 如果解析失败，尝试简单处理去除方括号
        String content = phone.substring(1, phone.length - 1);

        // 尝试匹配引号中的内容
        final RegExp regex = RegExp(r'"([^"]*)"');
        final matches = regex.allMatches(content);
        List<String> parts = [];

        if (matches.isNotEmpty) {
          for (final match in matches) {
            if (match.group(1)?.isNotEmpty == true) {
              parts.add(match.group(1)!);
            }
          }
        }

        if (parts.isEmpty) {
          // 如果没有找到引号包围的内容，尝试直接按逗号分割
          parts = content.split(',').map((p) => p.trim()).toList();
          // 移除可能的引号
          parts = parts.map((p) {
            if ((p.startsWith('"') && p.endsWith('"')) ||
                (p.startsWith("'") && p.endsWith("'"))) {
              return p.substring(1, p.length - 1);
            }
            return p;
          }).toList();
        }

        if (parts.isNotEmpty) {
          if (parts.length > 1) {
            return "${parts[0]} (+${parts.length - 1})";
          } else {
            return parts[0];
          }
        }

        return phone;
      }
    } else if (phone.contains(',')) {
      // 处理逗号分隔的电话号码
      List<String> parts = phone.split(',');
      if (parts.isNotEmpty) {
        List<String> cleanParts =
            parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        if (cleanParts.isEmpty) {
          return "未设置";
        }

        if (cleanParts.length > 1) {
          return "${cleanParts[0]} (+${cleanParts.length - 1})";
        } else {
          return cleanParts[0];
        }
      }
    }

    return phone;
  }

  // 执行高级搜索
  Future<void> _performAdvancedSearch() async {
    setState(() {
      _isSearching = true;
      _isAdvancedSearchVisible = true;
      _currentPage = 1; // 重置到第一页
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 创建搜索条件Map
      Map<String, String> advancedCriteria = {
        if (_nameSearchController.text.isNotEmpty)
          'name': _nameSearchController.text,
        if (_addressSearchController.text.isNotEmpty)
          'address': _addressSearchController.text,
        if (_phoneSearchController.text.isNotEmpty)
          'phone': _phoneSearchController.text,
        if (_doctorSearchController.text.isNotEmpty)
          'doctor': _doctorSearchController.text,
        if (_medicalRecordSearchController.text.isNotEmpty)
          'medical_record': _medicalRecordSearchController.text,
      };

      // 检查是否有至少一个搜索条件
      if (advancedCriteria.isEmpty) {
        _showMessage('请至少输入一个搜索条件');
        await _loadPatients(); // 加载所有患者
        return;
      }

      // 保存当前的高级搜索条件，以便分页时使用
      _currentAdvancedCriteria = advancedCriteria;

      // 调用搜索方法
      await _loadPatientsWithAdvancedSearch();
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showMessage('搜索出错: $e');
    }
  }

  // 添加一个方法加载高级搜索的结果，支持分页
  Future<void> _loadPatientsWithAdvancedSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 调用搜索方法
      final patients = await dbProvider.searchPatients(
        '', // 普通搜索词为空，使用高级搜索
        advancedCriteria: _currentAdvancedCriteria,
        sortField: _sortField,
        sortAscending: _sortAscending,
        startDate: _startDate,
        endDate: _endDate,
        dateFilterType: _dateFilterType,
      );

      setState(() {
        _patients = patients;
        _totalPatients = patients.length;
        _isSearching = false;
        _hasSearchResults = true;
        _searchQuery = '高级搜索'; // 显示在搜索框中
        _isLoading = false;
      });

      if (patients.isEmpty && mounted) {
        _showMessage('未找到匹配的患者');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _isLoading = false;
      });
      _showMessage('搜索出错: $e');
    }
  }

  // 清除高级搜索条件
  void _clearAdvancedSearch() {
    _nameSearchController.clear();
    _addressSearchController.clear();
    _phoneSearchController.clear();
    _doctorSearchController.clear();
    _medicalRecordSearchController.clear();

    setState(() {
      _searchQuery = '';
      _currentPage = 1;
      _currentAdvancedCriteria = null; // 清除高级搜索条件
    });

    _loadPatients();
  }

  // 高级搜索表单
  Widget _buildAdvancedSearchFields() {
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isPurpleTheme ? AppTheme.purpleCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: isPurpleTheme
                ? AppTheme.purpleColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isPurpleTheme
              ? AppTheme.purpleLightColor.withOpacity(0.3)
              : AppTheme.primaryColor.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Row(
            children: [
              Icon(
                Icons.search_outlined,
                color: isPurpleTheme
                    ? AppTheme.purpleColor
                    : AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '多条件搜索',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPurpleTheme
                      ? AppTheme.purpleColor
                      : AppTheme.primaryColor,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearAdvancedSearch,
                icon: Icon(
                  Icons.refresh,
                  size: 16,
                  color: isPurpleTheme
                      ? AppTheme.purpleSecondaryText
                      : AppTheme.secondaryText,
                ),
                label: Text(
                  '重置',
                  style: TextStyle(
                    color: isPurpleTheme
                        ? AppTheme.purpleSecondaryText
                        : AppTheme.secondaryText,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 搜索字段 - 横向排列在一行，搜索按钮放在最后
          Row(
            children: [
              // 姓名搜索
              Expanded(
                child: _buildCompactSearchField(
                  controller: _nameSearchController,
                  labelText: '姓名',
                  hintText: '姓名/拼音/首字母',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 8),

              // 地址搜索
              Expanded(
                child: _buildCompactSearchField(
                  controller: _addressSearchController,
                  labelText: '地址',
                  hintText: '地址/拼音',
                  icon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(width: 8),

              // 电话搜索
              Expanded(
                child: _buildCompactSearchField(
                  controller: _phoneSearchController,
                  labelText: '电话',
                  hintText: '电话号码',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 8),

              // 医生搜索
              Expanded(
                child: _buildCompactSearchField(
                  controller: _doctorSearchController,
                  labelText: '医生',
                  hintText: '医生姓名',
                  icon: Icons.medical_services_outlined,
                ),
              ),
              const SizedBox(width: 8),

              // 病历号搜索
              Expanded(
                child: _buildCompactSearchField(
                  controller: _medicalRecordSearchController,
                  labelText: '病历号',
                  hintText: '病历号',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),

              // 搜索按钮 - 直接放在病历号后面
              ElevatedButton.icon(
                onPressed: _performAdvancedSearch,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('搜索'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPurpleTheme
                      ? AppTheme.purpleColor
                      : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  minimumSize: const Size(100, 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 紧凑型搜索字段构建辅助方法
  Widget _buildCompactSearchField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isPurpleTheme
            ? Colors.white.withOpacity(0.7)
            : AppTheme.backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPurpleTheme
              ? AppTheme.purpleDividerColor
              : AppTheme.dividerColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              icon,
              size: 18,
              color: isPurpleTheme
                  ? AppTheme.purpleSecondaryText
                  : AppTheme.secondaryText,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isPurpleTheme
                      ? AppTheme.purpleSecondaryText
                      : AppTheme.secondaryText,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                isDense: true,
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              keyboardType: keyboardType,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontSize: 13,
                color: isPurpleTheme
                    ? AppTheme.purplePrimaryText
                    : AppTheme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 显示消息的辅助方法
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isPurpleTheme
                ? AppTheme.purpleColor
                : AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
