import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import '../theme/app_theme.dart';
import '../providers/database_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/user_provider.dart';
import '../models/patient.dart';
import '../providers/app_state.dart';
import './patient_detail_screen.dart';
import './patient_form_dialog.dart';
import '../widgets/dental_icons.dart';
import '../widgets/patient_export_dialog.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../widgets/success_toast.dart';
import '../widgets/unified_search_field.dart';
import '../utils/permission_utils.dart';

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
    // 检查患者提供者中的刷新标志
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
    if (patientProvider.patientsNeedRefresh) {
      // 如果患者数据需要刷新，则重新加载
      _loadPatients();
      // 重置刷新标志
      patientProvider.resetPatientsRefreshFlag();
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
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);

      // 判断是否正在使用高级搜索
      if (_currentAdvancedCriteria != null &&
          _currentAdvancedCriteria!.isNotEmpty) {
        await _loadPatientsWithAdvancedSearch();
        return;
      }

      // 原有的加载逻辑
      Map<String, dynamic> patientsData = await patientProvider.getPatientsPage(
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
      print('加载患者数据错误: $e');
      
      // 检查是否是数据库连接问题
      if (e.toString().contains('database_closed') || 
          e.toString().contains('DatabaseException')) {
        // 显示数据库连接错误的提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('数据库连接异常，正在尝试重新连接...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // 延迟后重试
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _loadPatients();
            }
          });
        }
      } else {
        // 其他错误，显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('加载患者数据失败: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          
          setState(() {
            _isLoading = false;
          });
        }
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

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
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
    final now = DateTime.now();
    final DateTime initialStart = _startDate ?? DateTime(now.year, now.month, 1);
    final DateTime initialEnd = _endDate ?? now;
    final picked = await ReusableDateRangePicker.show(context, start: initialStart, end: initialEnd, title: '选择日期范围');
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
      _loadPatients();
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade500,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  void _addPatient() {
    // 所有登录用户都可以添加患者
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
      // 患者已经在PatientFormDialog中保存过了，这里只需要刷新数据
      
      // 标记患者数据需要刷新
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      patientProvider.markPatientsNeedRefresh();

      // 刷新数据
      await _loadPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  patient.id != null ? '患者信息更新成功' : '患者添加成功',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '添加患者失败: $e',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade500,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
    }
  }

  void _viewPatientDetails(Patient patient) {
    // 打开患者详情页面
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patient: patient),
      ),
    )
        .then((result) {
      // 只有在有数据变动时才刷新（result为true表示有变动）
      if (result == true) {
        _loadPatients();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 计算总页数
    final int totalPages = (_totalPatients / _patientsPerPage).ceil();
    // 确保总页数至少为1
    final int displayTotalPages = totalPages > 0 ? totalPages : 1;

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
                Icons.people_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '患者管理',
              style: TextStyle(
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
              color: DentalColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.success.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.file_download_rounded,
                color: DentalColors.success,
              ),
              onPressed: () => _showExportDialog(context),
              tooltip: '导出患者数据',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: _addPatient,
              tooltip: '添加患者',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
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
              onPressed: () async {
                await _loadPatients();
                if (!mounted) return;
                SuccessToastManager.show(context, message: '刷新数据成功');
              },
              tooltip: '刷新数据',
            ),
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
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryColor.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _addPatient,
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text(
                                  '添加患者',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                              ),
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
          ? SizedBox(
              width: 56,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _addPatient,
                  backgroundColor: Colors.transparent,
                  heroTag: 'patients_add_button',
                  elevation: 0,
                  child: const Icon(
                    Icons.add,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 第一排：搜索 + 按钮
            Row(
              children: [
                // 搜索（统一样式）
                Expanded(
                  child: UnifiedSearchField(
                    controller: _searchController,
                    hintText: '快速搜索患者姓名、拼音、电话、地址等',
                    prefixIcon: DentalIcons.hospitalUser,
                    searchQuery: _searchQuery,
                    onChanged: (v) { setState(() { _searchQuery = v; _currentPage = 1; }); _searchPatients(); },
                    onClear: () { _searchController.clear(); setState(() { _searchQuery = ''; _currentPage = 1; }); _loadPatients(); },
                  ),
                ),
                const SizedBox(width: 12),
                // 高级筛选（图标按钮）
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withOpacity(0.06))),
                  child: IconButton(
                    icon: Icon(Icons.tune, color: (_showAdvancedSearch) ? DentalColors.warning : DentalColors.info),
                    tooltip: _showAdvancedSearch ? '收起筛选' : '高级筛选',
                    onPressed: () {
                      setState(() {
                        _showAdvancedSearch = !_showAdvancedSearch;
                        if (_showAdvancedSearch) {
                          _searchController.clear();
                        } else {
                          _clearAdvancedSearch();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // 添加患者
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withOpacity(0.06))),
                  child: IconButton(
                    icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.green),
                    tooltip: '添加患者',
                    onPressed: _addPatient,
                  ),
                ),
              ],
            ),
            if (_showAdvancedSearch) _buildAdvancedSearchFields(),
          ],
        ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
        _buildSortButton('更新时间', 'updated_at'),
        const SizedBox(width: 6),
        _buildSortButton('姓名', 'name'),
        const SizedBox(width: 6),
        _buildSortButton('年龄', 'age'),
        const SizedBox(width: 6),
        _buildSortButton('病历号', 'medical_record_number'),
        const Spacer(),
        // 总患者数显示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                '总患者数: $_totalPatients',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortButton(String label, String field) {
    final bool isActive = _sortField == field;

    return InkWell(
      onTap: () => _changeSort(field),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
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
                fontSize: 13,
                color: isActive ? AppTheme.primaryColor : AppTheme.secondaryText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          // 左侧：标签
          const Icon(Icons.filter_alt, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            _searchQuery.isEmpty ? '筛选类型' : '结果筛选',
            style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          // 首诊时间
          _buildFilterTypeChip('首诊时间', 'first_visit_date'),
          const SizedBox(width: 6),
          // 更新时间
          _buildFilterTypeChip('更新时间', 'updated_at'),
          const Spacer(),
          // 日期范围按钮（扁平化）
          InkWell(
            onTap: _selectDateRange,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('yyyy-MM-dd').format(_startDate!)} 至 ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                        : '选择日期范围',
                    style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          if (_startDate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.clear, size: 18, color: AppTheme.errorColor),
              onPressed: _clearFilters,
              tooltip: '清除筛选',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTypeChip(String label, String value) {
    final bool active = _dateFilterType == value;
    return InkWell(
      onTap: () {
        setState(() => _dateFilterType = value);
        if (_startDate != null && _endDate != null) _loadPatients();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppTheme.primaryColor : Colors.grey.shade300, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value == 'first_visit_date' ? Icons.event_note : Icons.update,
                size: 14, color: active ? Colors.white : AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppTheme.primaryColor)),
          ],
        ),
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

        // 根据性别决定头像背景和图标颜色
        final Color avatarBgColor = patientGender == '女'
            ? Color(0xFFF48FB1).withOpacity(0.2)
            : Colors.blue.withOpacity(0.1);
        final Color avatarTextColor =
            patientGender == '女' ? Color(0xFFEC407A) : Colors.blue;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            elevation: isPurpleTheme ? 0 : 1,
            borderRadius: BorderRadius.circular(12),
            shadowColor: isPurpleTheme ? AppTheme.purpleColor.withOpacity(0.1) : null,
            color: isPurpleTheme ? AppTheme.purpleCardBackground : Colors.white,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isPurpleTheme
                    ? Border.all(
                        color: AppTheme.purpleLightColor.withOpacity(0.3), width: 1)
                    : null,
                gradient: isPurpleTheme 
                    ? null 
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.grey.shade50.withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: InkWell(
                onTap: () => _viewPatientDetails(patient),
                borderRadius: BorderRadius.circular(12),
                hoverColor: DentalColors.primary.withOpacity(0.1),
                splashColor: DentalColors.primary.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                  children: [
                    // 左侧：头像
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            avatarBgColor,
                            avatarBgColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: avatarTextColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          patientName.isNotEmpty ? patientName[0] : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: avatarTextColor,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // 中间：患者信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 第一行：姓名 + 性别年龄标签
                          Row(
                            children: [
                              Text(
                                patientName,
                                style: const TextStyle(
                                  fontSize: 15,
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
                                  color: avatarBgColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: avatarTextColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      patientGender == '女' ? Icons.female : Icons.male,
                                      size: 11,
                                      color: avatarTextColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${patient.age}岁',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: avatarTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // 第二行：病历号 + 电话 + 首诊时间 + 地址
                          Row(
                            children: [
                              // 病历号
                              if (patient.medical_record_number != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.badge,
                                        size: 11,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${patient.medical_record_number}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              
                              // 电话
                              Flexible(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 11,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          _getDisplayPhone(patient.phone),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 6),
                              
                              // 首诊时间
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event,
                                      size: 11,
                                      color: AppTheme.accentColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      DateFormat('yyyy-MM-dd').format(patient.first_visit_date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // 地址（如果有）
                              if (patient.address != null && patient.address!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 11,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            patient.address ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange.shade700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 右侧：操作按钮
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 查看按钮
                        _buildCompactPatientActionButton(
                          icon: Icons.visibility_outlined,
                          color: AppTheme.primaryColor,
                          tooltip: '查看',
                          onPressed: () => _viewPatientDetails(patient),
                        ),
                        
                        const SizedBox(width: 4),
                        
                        // 编辑按钮
                        PermissionUtils.canEditDoctor(context, patient.doctor)
                          ? _buildCompactPatientActionButton(
                              icon: Icons.edit_outlined,
                              color: AppTheme.accentColor,
                              tooltip: '编辑',
                              onPressed: () => _editPatient(patient),
                            )
                          : _buildCompactPatientActionButton(
                              icon: Icons.lock,
                              color: Colors.grey,
                              tooltip: '权限不足',
                              onPressed: () => PermissionUtils.showPermissionDeniedDialog(
                                context,
                                message: '您只能编辑自己医生的患者。',
                              ),
                            ),
                        
                        const SizedBox(width: 4),
                        
                        // 删除按钮
                        PermissionUtils.canDeleteDoctor(context, patient.doctor)
                          ? _buildCompactPatientActionButton(
                              icon: Icons.delete_outlined,
                              color: AppTheme.errorColor,
                              tooltip: '删除',
                              onPressed: () => _confirmDeletePatient(patient),
                            )
                          : _buildCompactPatientActionButton(
                              icon: Icons.lock,
                              color: Colors.grey,
                              tooltip: '权限不足',
                              onPressed: () => PermissionUtils.showPermissionDeniedDialog(
                                context,
                                message: '您只能删除自己医生的患者。',
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
                  ),
                ),
              ),
            ),
        );
      },
    );
  }

  // 紧凑型患者操作按钮
  Widget _buildCompactPatientActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    // 统一风格：每页X条 · 共N条 / M页
    final String resultText = '每页 $_patientsPerPage 条 · 共 $_totalPatients 条 / $totalPages 页';

    print(
        '构建分页: 搜索词="$_searchQuery", 日期筛选=${_startDate != null}, 总记录数=$_totalPatients, 总页数=$totalPages');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 2),
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
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 0,
                  child: InkWell(
                    onTap: isCurrentPage
                        ? null
                        : () {
                            setState(() {
                              _currentPage = pageNumber;
                            });
                            _loadPatients();
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isCurrentPage
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryColor.withOpacity(0.8),
                                ],
                              )
                            : null,
                        color: isCurrentPage ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrentPage
                            ? null
                            : Border.all(
                                color: AppTheme.dividerColor.withOpacity(0.3),
                                width: 1.5,
                              ),
                        boxShadow: isCurrentPage
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Text(
                        '$pageNumber',
                        style: TextStyle(
                          color: isCurrentPage
                              ? Colors.white
                              : AppTheme.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
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

          const SizedBox(width: 16),

          // 首页按钮
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.8),
                  AppTheme.primaryColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentPage = 1;
                  });
                  _loadPatients();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.home,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // 页面信息与跳转组
          Container(
            margin: const EdgeInsets.only(left: 32),
            child: Row(
              children: [
                // 页面信息（带图标与色块强调）
                Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor.withOpacity(0.9)),
                      const SizedBox(width: 6),
                      Text(
                        resultText,
                        style: TextStyle(
                          color: AppTheme.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  )
                : null,
            color: isActive ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive 
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : AppTheme.dividerColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : AppTheme.primaryColor.withOpacity(0.7),
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
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '请输入1到$totalPages之间的页码',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade600,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '请输入有效的页码',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          );
        }
      }
    }

    return Container(
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.dividerColor.withOpacity(0.3),
          width: 1.5,
        ),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 转到 文字
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
            child: Text(
              '转到',
              style: TextStyle(
                fontSize: 14, 
                color: AppTheme.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 输入框
          Container(
            width: 72,
            height: 42,
            color: Colors.white,
            child: TextField(
              controller: _jumpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '页码',
                hintStyle: TextStyle(
                  color: AppTheme.secondaryText.withOpacity(0.6),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              onSubmitted: (_) => _jumpToPage(),
            ),
          ),

          // 跳转按钮
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _jumpToPage,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Text(
                  '确定',
                  style: TextStyle(
                    color: Colors.white,
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
    // 所有医生都可以编辑任何患者，但编辑权限在表单内部控制
    
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);

    // 从数据库获取最新的患者信息，确保包含完整的牙齿状况数据
    Patient? freshPatient;
    try {
      if (patient.id != null) {
        print('编辑前获取最新患者数据: ID ${patient.id}');
        freshPatient = await patientProvider.getPatient(patient.id!);
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
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);

      // 更新患者
      await patientProvider.updatePatient(updatedPatient);

      // 明确标记患者数据需要刷新
      patientProvider.markPatientsNeedRefresh();

      // 刷新列表
      await _loadPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '患者信息已更新',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '更新患者信息失败: $e',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade500,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
    }
  }

  // 添加确认删除患者的方法
  Future<void> _confirmDeletePatient(Patient patient) async {
    final confirmed = await DeleteConfirmDialogManager.showPatientDelete(
      context,
      patientName: patient.name,
    );

    if (confirmed) {
      await _deletePatient(patient);
    }
  }

  // 添加删除患者的方法
  Future<void> _deletePatient(Patient patient) async {
    // 检查删除权限
    if (!PermissionUtils.canDeleteDoctor(context, patient.doctor)) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能删除自己医生的患者。',
      );
      return;
    }
    
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);

      // 删除患者
      if (patient.id != null) {
        await patientProvider.deletePatient(patient.id!);
      }

      // 明确标记患者数据需要刷新
      patientProvider.markPatientsNeedRefresh();

      // 刷新列表
      await _loadPatients();

      if (!mounted) return;
      DeleteSuccessToastManager.show(context, message: '患者已删除');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '删除患者失败: $e',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade500,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical:12),
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
          searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
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
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.updateAllPatientsPinyin();

      // 重新加载患者数据
      await _loadPatients();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '拼音数据已更新',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '更新拼音数据失败: $e',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade500,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    // 获取显示的电话号码(如果是JSON格式,显示第一个)
    final displayPhone = _getDisplayPhone(patient.phone);

    // 为每个患者生成一个稳定的随机颜色,基于姓名
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

    return _HoverablePatientCard(
      isPurpleTheme: isPurpleTheme,
      onTap: () => _viewPatientDetails(patient),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 现代化患者头像
                  DentalAvatar(
                    gender: patient.gender,
                    name: patient.name,
                    size: 52,
                  ),
                  const SizedBox(width: 16),
                  // 患者基本信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                patient.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: DentalColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DentalStatusIndicator(
                              status: patient.gender,
                              color: patient.gender == '女' 
                                ? DentalColors.femalePink 
                                : DentalColors.maleBlue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              size: 16,
                              color: DentalColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${patient.age}岁',
                              style: TextStyle(
                                fontSize: 14,
                                color: DentalColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: DentalColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                displayPhone,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: DentalColors.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 患者详细信息卡片
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      DentalColors.surface.withOpacity(0.5),
                      DentalColors.surface.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DentalColors.primary.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    if (patient.medical_record_number != null)
                      _buildInfoRow(
                        Icons.badge_outlined,
                        '病历号',
                        patient.medical_record_number.toString(),
                        DentalColors.info,
                      ),
                    if (patient.doctor != null && patient.doctor!.isNotEmpty)
                      _buildInfoRow(
                        Icons.medical_services_outlined,
                        '主治医生',
                        patient.doctor ?? '',
                        DentalColors.success,
                      ),
                    if (patient.address != null && patient.address!.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        '地址',
                        patient.address ?? '',
                        DentalColors.secondary,
                        maxLines: 2,
                      ),
                    _buildInfoRow(
                      Icons.event_outlined,
                      '首诊日期',
                      DateFormat('yyyy-MM-dd').format(patient.first_visit_date),
                      DentalColors.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 操作按钮区域
              Row(
                children: [
                  Expanded(
                    child: DentalGradientButton(
                      onPressed: () => _viewPatientDetails(patient),
                      gradient: LinearGradient(
                        colors: [
                          DentalColors.info,
                          DentalColors.info.withOpacity(0.8),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '查看详情',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PermissionUtils.canEditDoctor(context, patient.doctor) 
                      ? DentalGradientButton(
                          onPressed: () => _editPatient(patient),
                          gradient: LinearGradient(
                            colors: [
                              DentalColors.warning,
                              DentalColors.warning.withOpacity(0.8),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '编辑',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : DentalGradientButton(
                          onPressed: () => PermissionUtils.showPermissionDeniedDialog(
                            context,
                            message: '您只能编辑自己医生的患者。',
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.withOpacity(0.7),
                              Colors.grey.withOpacity(0.5),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '权限不足',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                  const SizedBox(width: 12),
                  PermissionUtils.canDeleteDoctor(context, patient.doctor)
                    ? Container(
                        decoration: BoxDecoration(
                          color: DentalColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: DentalColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _deletePatient(patient),
                          icon: Icon(
                            Icons.delete_outline,
                            color: DentalColors.error,
                            size: 20,
                          ),
                          tooltip: '删除患者',
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => PermissionUtils.showPermissionDeniedDialog(
                            context,
                            message: '您只能删除自己医生的患者。',
                          ),
                          icon: Icon(
                            Icons.lock,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          tooltip: '权限不足',
                        ),
                      ),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
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
                    fontSize: 12,
                    color: DentalColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: DentalColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayPhone(dynamic phone) {
    if (phone == null || phone.toString().isEmpty) {
      return "未设置";
    }
    
    String phoneStr = phone.toString();

    // 判断是否为JSON格式
    if (phoneStr.startsWith('[') && phoneStr.endsWith(']')) {
      try {
        // 尝试解析JSON
        List<dynamic> phones = jsonDecode(phoneStr);
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
        String content = phoneStr.substring(1, phoneStr.length - 1);

        // 尝试匹配引号中的内容
        final RegExp regex = RegExp(r'"([^"]*)"');
        final matches = regex.allMatches(content);
        List<String> parts = [];

        if (matches.isNotEmpty) {
          for (final match in matches) {
            final group = match.group(1);
            if (group != null && group.isNotEmpty) {
              parts.add(group);
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

        return phoneStr;
      }
    } else if (phoneStr.contains(',')) {
      // 处理逗号分隔的电话号码
      List<String> parts = phoneStr.split(',');
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

    return phoneStr;
  }

  // 执行高级搜索
  Future<void> _performAdvancedSearch() async {
    setState(() {
      _isSearching = true;
      _isAdvancedSearchVisible = true;
      _currentPage = 1; // 重置到第一页
    });

    // 构造高级筛选条件（不包含医生字段）
    final advancedCriteria = <String, String>{
      if (_nameSearchController.text.trim().isNotEmpty)
        'name': _nameSearchController.text.trim(),
      if (_addressSearchController.text.trim().isNotEmpty)
        'address': _addressSearchController.text.trim(),
      if (_phoneSearchController.text.trim().isNotEmpty)
        'phone': _phoneSearchController.text.trim(),
      if (_medicalRecordSearchController.text.trim().isNotEmpty)
        'medical_record': _medicalRecordSearchController.text.trim(),
    };

    if (advancedCriteria.isEmpty) {
      _showMessage('请至少输入一个搜索条件');
      setState(() {
        _currentAdvancedCriteria = null;
        _isSearching = false;
      });
      await _loadPatients();
      return;
    }

    _currentAdvancedCriteria = advancedCriteria;
    await _loadPatientsWithAdvancedSearch();
  }
  // 添加一个方法加载高级搜索的结果，支持分页
  Future<void> _loadPatientsWithAdvancedSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);

      // 调用搜索方法
      final patients = await patientProvider.searchPatients(
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPurpleTheme ? AppTheme.purpleCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isPurpleTheme ? AppTheme.purpleLightColor : AppTheme.primaryColor).withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactSearchField(
              controller: _nameSearchController,
              labelText: '姓名',
              hintText: '姓名/拼音/首字母',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactSearchField(
              controller: _addressSearchController,
              labelText: '地址',
              hintText: '地址/拼音',
              icon: Icons.location_on_outlined,
            ),
          ),
          const SizedBox(width: 8),
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
          // 重置按钮（轻量）
          TextButton.icon(
            onPressed: _clearAdvancedSearch,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重置'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(width: 6),
          // 搜索按钮（主色）
          ElevatedButton.icon(
            onPressed: _performAdvancedSearch,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('搜索'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPurpleTheme ? AppTheme.purpleColor : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
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
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isPurpleTheme ? AppTheme.purpleColor : AppTheme.primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isPurpleTheme
                  ? AppTheme.purpleColor
                  : AppTheme.primaryColor,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (isPurpleTheme ? AppTheme.purpleColor : AppTheme.primaryColor).withOpacity(0.7),
                ),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: (isPurpleTheme ? AppTheme.purpleSecondaryText : AppTheme.secondaryText).withOpacity(0.6),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              keyboardType: keyboardType,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade500 : Colors.blue.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}

// 可悬浮的患者卡片组件
class _HoverablePatientCard extends StatefulWidget {
  final bool isPurpleTheme;
  final VoidCallback onTap;
  final Widget child;

  const _HoverablePatientCard({
    Key? key,
    required this.isPurpleTheme,
    required this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  State<_HoverablePatientCard> createState() => _HoverablePatientCardState();
}

class _HoverablePatientCardState extends State<_HoverablePatientCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        print('鼠标进入卡片');
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        print('鼠标离开卡片');
        setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _isHovered 
              ? DentalColors.primary.withOpacity(0.1)
              : (widget.isPurpleTheme
                  ? AppTheme.purpleCardBackground
                  : AppTheme.cardBackground),
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: DentalColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                ]
              : widget.isPurpleTheme
                  ? [
                      BoxShadow(
                        color: AppTheme.purpleColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : AppTheme.cardShadow,
          border: Border.all(
            color: _isHovered
                ? DentalColors.primary
                : (widget.isPurpleTheme
                    ? AppTheme.purpleLightColor.withOpacity(0.3)
                    : Colors.transparent),
            width: _isHovered ? 3 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
