import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/patient_provider.dart';
import '../models/patient.dart';
import './patient_detail_screen.dart';
import '../features/patients/widgets/patient_form_dialog.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../widgets/success_toast.dart';
import '../utils/permission_utils.dart';
import '../features/patients/services/patient_list_query_service.dart';
import '../features/patients/services/patient_list_state_service.dart';
import '../features/patients/services/patient_operation_feedback_service.dart';
import '../features/patients/services/patient_search_criteria_service.dart';
import '../features/patients/widgets/patient_screen_components.dart';
import '../theme/theme_context_extensions.dart';
import '../utils/log_manager.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({Key? key}) : super(key: key);

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
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
  final String _dateFilterType = 'first_visit_date'; // 默认按首诊时间筛选

  // 高级搜索相关变量
  bool _showAdvancedSearch = false;
  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _addressSearchController =
      TextEditingController();
  final TextEditingController _phoneSearchController = TextEditingController();
  final TextEditingController _medicalRecordSearchController =
      TextEditingController();

  // 页面状态变量
  bool _isSearching = false;

  // 添加一个变量来存储当前的高级搜索条件
  Map<String, String>? _currentAdvancedCriteria;

  bool get _hasAdvancedSearch {
    final criteria = _currentAdvancedCriteria;
    return criteria != null && criteria.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查患者提供者中的刷新标志
    final patientProvider = Provider.of<PatientProvider>(
      context,
      listen: false,
    );
    if (patientProvider.patientsNeedRefresh) {
      // 如果患者数据需要刷新，则重新加载
      _loadPatients();
      // 重置刷新标志
      patientProvider.resetPatientsRefreshFlag();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    // 释放高级搜索控制器
    _nameSearchController.dispose();
    _addressSearchController.dispose();
    _phoneSearchController.dispose();
    _medicalRecordSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      // 判断是否正在使用高级搜索
      if (_hasAdvancedSearch) {
        await _loadPatientsWithAdvancedSearch();
        return;
      }

      final patientsData = await PatientListQueryService.loadPage(
        patientProvider: patientProvider,
        page: _currentPage,
        pageSize: _patientsPerPage,
        searchQuery: _searchQuery,
        sortField: _sortField,
        sortAscending: _sortAscending,
        startDate: _startDate,
        endDate: _endDate,
        dateFilterType: _dateFilterType,
      );

      _applyListState(
        PatientListStateService.fromPageResult(
          result: patientsData,
          searchQuery: _searchQuery,
          isSearching: _isSearching,
        ),
      );
    } catch (e) {
      LogManager.e('PatientsScreen', '加载患者数据错误', error: e);

      // 检查是否是数据库连接问题
      if (e.toString().contains('database_closed') ||
          e.toString().contains('DatabaseException')) {
        // 显示数据库连接错误的提示
        if (mounted) {
          PatientSnackBars.showSimple(
            context,
            message: '数据库连接异常，正在尝试重新连接...',
            backgroundColor: context.tokens.warning,
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
          PatientSnackBars.showSimple(
            context,
            message: '加载患者数据失败: $e',
            backgroundColor: context.tokens.error,
          );

          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = query.trim();
      _currentPage = 1;
      if (_searchQuery.isNotEmpty) {
        _totalPatients = 0;
      }
    });
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadPatients();
      }
    });
  }

  void _changeSort(String field) {
    final sortChange = PatientListStateService.computeSortChange(
      currentField: _sortField,
      clickedField: field,
      currentAscending: _sortAscending,
    );
    setState(() {
      _sortField = sortChange.sortField;
      _sortAscending = sortChange.sortAscending;
      _currentPage = 1;
    });
    _loadPatients();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
      // 不清除搜索状态，以便在搜索结果上进行操作
    });
    _loadPatients();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final DateTime initialStart =
        _startDate ?? DateTime(now.year, now.month, 1);
    final DateTime initialEnd = _endDate ?? now;
    final picked = await ReusableDateRangePicker.show(
      context,
      start: initialStart,
      end: initialEnd,
      title: '选择日期范围',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
      _loadPatients();
    }
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
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      patientProvider.markPatientsNeedRefresh();

      // 刷新数据
      await _loadPatients();

      if (!mounted) return;
      _showOperationFeedback(
        PatientOperationFeedbackService.saveSuccess(patient),
      );
    } catch (e) {
      if (!mounted) return;
      _showOperationFeedback(PatientOperationFeedbackService.saveFailure(e));
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
    return PatientScreenScaffold(
      title: const PatientAppBarTitle(),
      actions: PatientAppBarActions(
        onExport: () => _showExportDialog(context),
        onAddPatient: _addPatient,
        onShowStatistics: _showStatisticsDialog,
        onRefresh: () async {
          await _loadPatients();
          if (!context.mounted) return;
          AppToastManager.showSuccess(context, message: '刷新数据成功');
        },
      ),
      body: PatientScreenBody(
        searchController: _searchController,
        searchQuery: _searchQuery,
        showAdvancedSearch: _showAdvancedSearch,
        advancedSearchFields:
            _showAdvancedSearch ? _buildAdvancedSearchFields() : null,
        searchReadOnly: _hasAdvancedSearch,
        onSearchChanged: (v) {
          _scheduleSearch(v);
        },
        onSearchCleared: () {
          final hasAdvancedSearch = _hasAdvancedSearch;
          if (hasAdvancedSearch) {
            _clearAdvancedSearch();
            return;
          }

          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _currentPage = 1;
          });
          _loadPatients();
        },
        onAdvancedSearchToggled: () {
          setState(() {
            _showAdvancedSearch = !_showAdvancedSearch;
            if (_showAdvancedSearch) {
              _searchController.clear();
            } else {
              _clearAdvancedSearch();
            }
          });
        },
        onAddPatient: _addPatient,
        sortField: _sortField,
        sortAscending: _sortAscending,
        totalPatients: _totalPatients,
        onSortChanged: _changeSort,
        startDate: _startDate,
        endDate: _endDate,
        onSelectDateRange: _selectDateRange,
        onClearFilters: _clearFilters,
        isLoading: _isLoading,
        hasPatients: _patients.isNotEmpty,
        patientsList: _buildPatientsList(),
        currentPage: _currentPage,
        patientsPerPage: _patientsPerPage,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
          _loadPatients();
        },
      ),
      floatingActionButton: _patients.isNotEmpty
          ? PatientFloatingAddButton(onPressed: _addPatient)
          : null,
    );
  }

  Widget _buildPatientsList() {
    return PatientListView(
      patients: _patients,
      canEditPatient: (patient) =>
          PermissionUtils.canEditDoctor(context, patient.doctor),
      canDeletePatient: (patient) => PermissionUtils.canDeleteDoctor(
        context,
        patient.doctor,
      ),
      onView: _viewPatientDetails,
      onEdit: _editPatient,
      onDelete: _confirmDeletePatient,
      onEditPermissionDenied: () => PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能编辑自己医生的患者。',
      ),
      onDeletePermissionDenied: () =>
          PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能删除自己医生的患者。',
      ),
    );
  }

  // 添加编辑患者的方法
  void _editPatient(Patient patient) async {
    // 所有医生都可以编辑任何患者，但编辑权限在表单内部控制

    final patientProvider = Provider.of<PatientProvider>(
      context,
      listen: false,
    );

    // 从数据库获取最新的患者信息，确保包含完整的牙齿状况数据
    final freshPatient = await PatientListStateService.fetchFreshPatient(
      patientProvider: patientProvider,
      patient: patient,
    );

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
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      // 更新患者
      await patientProvider.updatePatient(updatedPatient);

      // 明确标记患者数据需要刷新
      patientProvider.markPatientsNeedRefresh();

      // 刷新列表
      await _loadPatients();

      if (!mounted) return;
      _showOperationFeedback(PatientOperationFeedbackService.updateSuccess());
    } catch (e) {
      if (!mounted) return;
      _showOperationFeedback(PatientOperationFeedbackService.updateFailure(e));
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
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      // 删除患者
      if (patient.id != null) {
        final patientId = patient.id;
        if (patientId != null) {
          await patientProvider.deletePatient(patientId);
        }
      }

      // 明确标记患者数据需要刷新
      patientProvider.markPatientsNeedRefresh();

      // 刷新列表
      await _loadPatients();

      if (!mounted) return;
      AppToastManager.showDelete(context, message: '患者已删除');
    } catch (e) {
      if (!mounted) return;
      _showOperationFeedback(PatientOperationFeedbackService.deleteFailure(e));
    }
  }

  // 显示统计图表对话框
  Future<void> _showStatisticsDialog() async {
    // 加载患者数据用于统计（根据当前搜索条件）
    try {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      final hasAdvancedSearch = _hasAdvancedSearch;
      final allPatients = hasAdvancedSearch
          ? await patientProvider.searchPatients(
              '',
              sortField: _sortField,
              sortAscending: _sortAscending,
              startDate: _startDate,
              endDate: _endDate,
              dateFilterType: _dateFilterType,
              advancedCriteria: _currentAdvancedCriteria,
            )
          : await PatientListQueryService.loadAllPages(
              patientProvider: patientProvider,
              searchQuery: _searchQuery,
              sortField: _sortField,
              sortAscending: _sortAscending,
              startDate: _startDate,
              endDate: _endDate,
              dateFilterType: _dateFilterType,
            );

      if (!mounted) return;

      await PatientStatisticsNavigation.open(
        context,
        patients: allPatients,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        initialStartDate: _startDate,
        initialEndDate: _endDate,
        dateFilterType: _dateFilterType,
      );
    } catch (e) {
      LogManager.e('PatientsScreen', '加载患者统计数据错误', error: e);
      if (!mounted) return;
      PatientSnackBars.showSimple(
        context,
        message: '加载统计数据失败: $e',
        backgroundColor: context.tokens.error,
      );
    }
  }

  // 显示导出对话框
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PatientExportDialog(
          searchQuery: _hasAdvancedSearch
              ? null
              : (_searchController.text.isNotEmpty
                  ? _searchController.text
                  : null),
          advancedCriteria:
              _hasAdvancedSearch ? _currentAdvancedCriteria : null,
          sortField: _sortField,
          sortAscending: _sortAscending,
          startDate: _startDate,
          endDate: _endDate,
          dateFilterType: _dateFilterType,
        );
      },
    );
  }

  // 执行高级搜索
  Future<void> _performAdvancedSearch() async {
    setState(() {
      _isSearching = true;
      _currentPage = 1; // 重置到第一页
    });

    final advancedCriteria = PatientSearchCriteriaService.buildAdvancedCriteria(
      name: _nameSearchController.text,
      address: _addressSearchController.text,
      phone: _phoneSearchController.text,
      medicalRecord: _medicalRecordSearchController.text,
    );

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
    final searchSummary = _buildAdvancedSearchSummary(advancedCriteria);
    _searchController.value = TextEditingValue(
      text: searchSummary,
      selection: TextSelection.collapsed(offset: searchSummary.length),
    );
    await _loadPatientsWithAdvancedSearch();
  }

  // 添加一个方法加载高级搜索的结果，支持分页
  Future<void> _loadPatientsWithAdvancedSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      final patientsData = await PatientListQueryService.loadAdvancedSearch(
        patientProvider: patientProvider,
        advancedCriteria: _currentAdvancedCriteria,
        page: _currentPage,
        pageSize: _patientsPerPage,
        sortField: _sortField,
        sortAscending: _sortAscending,
        startDate: _startDate,
        endDate: _endDate,
        dateFilterType: _dateFilterType,
      );

      _applyListState(
        PatientListStateService.fromAdvancedSearchResult(
          result: patientsData,
          searchQuery: _searchController.text,
        ),
      );

      if (patientsData.patients.isEmpty && mounted) {
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
    _searchController.clear();
    _nameSearchController.clear();
    _addressSearchController.clear();
    _phoneSearchController.clear();
    _medicalRecordSearchController.clear();

    setState(() {
      _searchQuery = '';
      _currentPage = 1;
      _currentAdvancedCriteria = null; // 清除高级搜索条件
    });

    _loadPatients();
  }

  String _buildAdvancedSearchSummary(Map<String, String>? criteria) {
    if (criteria == null || criteria.isEmpty) {
      return '';
    }

    final labels = <String, String>{
      'name': '姓名',
      'address': '地址',
      'phone': '电话',
      'medical_record': '病历号',
    };

    final parts = <String>[];
    for (final entry in labels.entries) {
      final value = criteria[entry.key];
      if (value != null && value.isNotEmpty) {
        parts.add('${entry.value}：$value');
      }
    }

    return parts.join('，');
  }

  // 高级搜索表单
  Widget _buildAdvancedSearchFields() {
    return PatientAdvancedSearchFields(
      nameController: _nameSearchController,
      addressController: _addressSearchController,
      phoneController: _phoneSearchController,
      medicalRecordController: _medicalRecordSearchController,
      onReset: _clearAdvancedSearch,
      onSearch: _performAdvancedSearch,
    );
  }

  // 显示消息的辅助方法
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    PatientSnackBars.showMessage(
      context,
      message: message,
      isError: isError,
    );
  }

  void _applyListState(PatientListStateResult state) {
    setState(() {
      _patients = state.patients;
      _totalPatients = state.totalPatients;
      _isLoading = state.isLoading;
      _isSearching = state.isSearching;
      _searchQuery = state.searchQuery;
    });
  }

  void _showOperationFeedback(PatientOperationFeedback feedback) {
    PatientSnackBars.showStatus(
      context,
      message: feedback.message,
      icon: feedback.type == PatientOperationFeedbackType.success
          ? Icons.check_circle_outline
          : Icons.error_outline,
      backgroundColor: feedback.type == PatientOperationFeedbackType.success
          ? context.tokens.success
          : context.tokens.error,
      duration: feedback.duration,
    );
  }
}
