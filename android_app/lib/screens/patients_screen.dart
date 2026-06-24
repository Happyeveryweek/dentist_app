import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/screens/patient_detail_screen.dart';
import 'package:dentist_app/features/patients/widgets/patient_form_sheet.dart';
import 'package:dentist_app/features/patients/widgets/patients_screen_body.dart';
import 'package:dentist_app/features/patients/widgets/patient_sort_options.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import 'package:dentist_app/utils/permission_utils.dart';
import '../utils/app_logger.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen>
    with SingleTickerProviderStateMixin {
  List<Patient> _patients = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String _currentSort = 'updated'; // 'updated', 'age', 'recent'
  bool _ascending = false;
  late AnimationController _animationController;

  // 分页控制
  int _currentPage = 1;
  final int _pageSize = 60;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  // 时间筛选相关状态
  bool _showTimeFilter = false;
  String _dateFilterType =
      'first_visit_date'; // 'first_visit_date', 'updated_at'
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeFiltering = false;

  // 数据库中的总患者数
  int _totalPatientsInDatabase = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 添加滚动监听
    _scrollController.addListener(_scrollListener);

    _loadPatients();
  }

  // 滚动监听器，用于检测何时需要加载更多数据
  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore &&
          _hasMoreData &&
          _searchQuery.isEmpty &&
          !_isDateRangeFiltering) {
        _loadMorePatients();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 只在第一次加载时获取数据，不再响应依赖变更
    // 所有数据刷新都由用户明确操作触发
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // 重置搜索和分页状态，重新加载数据
  Future<void> _loadPatients() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreData = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      AppLogger.info('加载患者列表，数据库类型: ${dbProvider.dbType}');

      // 确保PatientProvider已初始化
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (!patientProvider.initialized) {
        await patientProvider.initializeFromDatabase(dbProvider);
      }

      // 确保PatientProvider有UserProvider的引用用于权限过滤
      patientProvider.setUserProvider(userProvider);

      List<Patient> patients = [];

      if (_searchQuery.isEmpty && !_isDateRangeFiltering) {
        // 正常分页查询，并传递排序参数
        patients = await patientProvider.getPatientsPage(
          _currentPage,
          _pageSize,
          sortField: _currentSort,
          ascending: _ascending,
        );

        // 获取数据库中的总患者数
        _totalPatientsInDatabase = await patientProvider.getPatientCount();
      } else {
        if (_searchQuery.isEmpty) {
          patients = await patientProvider.getAllPatients();
          AppLogger.info('获取所有患者数据用于时间筛选: ${patients.length} 个患者');
        } else {
          patients = await patientProvider.searchPatients(_searchQuery);
          AppLogger.info('搜索 "$_searchQuery" 返回 ${patients.length} 个结果');
        }

        if (_isDateRangeFiltering && _startDate != null && _endDate != null) {
          patients = _applyTimeFilterToPatients(patients);
          AppLogger.info('应用时间筛选后剩余 ${patients.length} 个患者');
        }

        _totalPatientsInDatabase = patients.length;
        _sortPatientsInMemory(patients);
      }

      if (!mounted) return;
      setState(() {
        _patients = patients;
        _isLoading = false;
        if (_searchQuery.isEmpty && !_isDateRangeFiltering) {
          _hasMoreData = patients.length >= _pageSize;
        } else {
          // 搜索模式或时间筛选模式下不启用分页加载
          _hasMoreData = false;
        }
      });
    } catch (e) {
      AppLogger.info('加载患者数据错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 加载更多患者数据
  Future<void> _loadMorePatients() async {
    if (_isLoadingMore ||
        !_hasMoreData ||
        _searchQuery.isNotEmpty ||
        _isDateRangeFiltering) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newPatients = await Provider.of<PatientProvider>(
        context,
        listen: false,
      ).getPatientsPage(
        nextPage,
        _pageSize,
        sortField: _currentSort,
        ascending: _ascending,
      );

      if (mounted) {
        if (newPatients.isNotEmpty) {
          setState(() {
            _patients.addAll(newPatients);
            _currentPage = nextPage;
            _hasMoreData = newPatients.length >= _pageSize;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _hasMoreData = false;
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      AppLogger.info('加载更多患者数据错误: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // 重置搜索和分页状态，重新加载数据
  Future<void> _refreshPatients() async {
    if (!mounted) return;
    AppLogger.info('刷新患者列表...');

    // 强制清除数据库提供者中的缓存
    await Provider.of<PatientProvider>(
      context,
      listen: false,
    ).forceRefreshPatients();

    if (mounted) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _patients = [];
        // 保持时间筛选状态，不清除筛选条件
      });
    }

    await _loadPatients();

    if (mounted) {
      SuccessToastManager.show(context, message: '刷新成功');
    }

    AppLogger.info('患者列表刷新完成，加载了 ${_patients.length} 个患者');
  }

  // 在内存中对患者列表进行排序（不触发setState）
  void _sortPatientsInMemory(List<Patient> patients) {
    switch (_currentSort) {
      case 'name':
        patients.sort(
          (a, b) =>
              _ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name),
        );
        break;
      case 'age':
        patients.sort(
          (a, b) =>
              _ascending ? a.age.compareTo(b.age) : b.age.compareTo(a.age),
        );
        break;
      case 'medical_record':
        patients.sort((a, b) {
          // 处理null值情况
          final aRecord = a.medicalRecordNumber ?? 0;
          final bRecord = b.medicalRecordNumber ?? 0;
          return _ascending
              ? aRecord.compareTo(bRecord)
              : bRecord.compareTo(aRecord);
        });
        break;
      case 'updated':
        patients.sort(
          (a, b) =>
              _ascending
                  ? a.updatedAt.compareTo(b.updatedAt)
                  : b.updatedAt.compareTo(a.updatedAt),
        );
        break;
    }
  }

  void _changeSort(String sortType) {
    setState(() {
      if (_currentSort == sortType) {
        // 如果已经是当前排序项，则切换顺序
        _ascending = !_ascending;
      } else {
        // 否则更改排序项并设置为降序
        _currentSort = sortType;
        _ascending = false;
      }

      // 重置页码并重新加载患者数据
      _currentPage = 1;
      _loadPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: PatientsScreenBody(
        isLoading: _isLoading,
        patients: _patients,
        hasMoreData: _hasMoreData,
        totalPatientsInDatabase: _totalPatientsInDatabase,
        currentPage: _currentPage,
        searchQuery: _searchQuery,
        showTimeFilter: _showTimeFilter,
        dateFilterType: _dateFilterType,
        startDate: _startDate,
        endDate: _endDate,
        isDateRangeFiltering: _isDateRangeFiltering,
        searchController: _searchController,
        onSearch: (query) {
          setState(() {
            _searchQuery = query;
          });
          _loadPatients();
        },
        onClearSearch: () {
          setState(() {
            _searchQuery = '';
            _searchController.clear();
          });
          _loadPatients();
        },
        onToggleTimeFilter: (show) {
          setState(() {
            _showTimeFilter = show;
            if (!show) {
              _startDate = null;
              _endDate = null;
              _isDateRangeFiltering = false;
              _loadPatients();
            }
          });
        },
        onDateFilterTypeChange: (type) {
          setState(() {
            _dateFilterType = type;
          });
        },
        onStartDateChange: (date) {
          setState(() {
            _startDate = date;
          });
        },
        onEndDateChange: (date) {
          setState(() {
            _endDate = date;
          });
        },
        onApplyTimeFilter: _applyTimeFilter,
        onClearTimeFilter: _clearTimeFilter,
        onRefresh: _refreshPatients,
        scrollController: _scrollController,
        onAddPatient: () => _showPatientDialog(context),
        onShowPatientDetail: (patient) => _showPatientDetail(context, patient),
        onOpenSortOptions: () {
          PatientSortOptions.show(
            context,
            currentSort: _currentSort,
            ascending: _ascending,
            onSortChange: (sort) => _changeSort(sort),
          );
        },
        onEditPatient:
            (patient) => _showPatientDialog(context, patient: patient),
        onDeletePatient: (patient) => _confirmDeletePatient(context, patient),
      ),
      floatingActionButton: PermissionWrapper(
        module: 'patients',
        action: 'create',
        hideWhenDenied: true,
        child: FloatingActionButton(
          onPressed: () {
            _showPatientDialog(context);
          },
          backgroundColor: AppTheme.secondaryColor,
          tooltip: '添加新患者',
          heroTag: 'patient_add_button',
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  void _showPatientDetail(BuildContext context, Patient patient) {
    AppLogger.info(
      '查看患者详情: id=${patient.id}, name=${patient.name}, age=${patient.age}, gender=${patient.gender}',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patient: patient),
      ),
    ).then((result) {
      // 当从患者详情页返回时，刷新患者列表以获取最新数据
      if (result == true) {
        AppLogger.info('从患者详情页返回，刷新患者列表');
        _refreshPatients();
      }
    });
  }

  void _showPatientDialog(BuildContext context, {Patient? patient}) async {
    if (patient == null) {
      // 添加新患者 - 直接获取病历号，不显示加载提示

      try {
        // 先获取最大病历号 - 使用await等待操作完成
        final int maxMedicalRecordNumber =
            await Provider.of<PatientProvider>(
              context,
              listen: false,
            ).getMaxMedicalRecordNumber();
        final int nextMedicalRecordNumber = maxMedicalRecordNumber + 1;

        AppLogger.info('当前最大病历号: $maxMedicalRecordNumber');
        AppLogger.info('将使用默认病历号: $nextMedicalRecordNumber');

        // 移除提示条，直接设置病历号

        // 确保UI上下文仍然有效
        if (context.mounted) {
          // 使用 Navigator.push 打开全屏页面
          AppLogger.info('构建PatientFormSheet，传入初始病历号: $nextMedicalRecordNumber');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => Scaffold(
                    resizeToAvoidBottomInset: true,
                    body: SafeArea(
                      child: PatientFormSheet(
                        patient: null, // 确保表单知道这是添加新患者
                        initialMedicalRecordNumber:
                            nextMedicalRecordNumber, // 传递初始病历号
                        onSaved: (isSuccess, message) {
                          if (isSuccess) {
                            AppLogger.info('患者表单保存成功，直接刷新患者列表');
                            _loadPatients();
                            // 使用公共组件的成功提示
                            SuccessToastManager.show(context, message: message);
                          } else {
                            SuccessToastManager.showError(
                              context,
                              message: message,
                            );
                          }
                        },
                      ),
                    ),
                  ),
            ),
          );
        }
      } catch (error) {
        AppLogger.info('获取最大病历号出错: $error');
        // 出错时仍然打开表单，默认设置为1
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => Scaffold(
                    resizeToAvoidBottomInset: true,
                    body: SafeArea(
                      child: PatientFormSheet(
                        patient: null,
                        initialMedicalRecordNumber: 1, // 出错时默认设置为1
                        onSaved: (isSuccess, message) {
                          if (isSuccess) {
                            AppLogger.info('患者表单保存成功，直接刷新患者列表');
                            _loadPatients();
                            // 使用公共组件的成功提示
                            SuccessToastManager.show(context, message: message);
                          } else {
                            SuccessToastManager.showError(
                              context,
                              message: message,
                            );
                          }
                        },
                      ),
                    ),
                  ),
            ),
          );
        }
      }
    } else {
      // 编辑现有患者
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => Scaffold(
                resizeToAvoidBottomInset: true,
                body: SafeArea(
                  child: PatientFormSheet(
                    patient: patient,
                    // 编辑现有患者也需要传入病历号
                    initialMedicalRecordNumber: patient.medicalRecordNumber,
                    onSaved: (isSuccess, message) {
                      if (isSuccess) {
                        AppLogger.info('患者表单保存成功，直接刷新患者列表');
                        _loadPatients();
                        // 使用公共组件的成功提示
                        SuccessToastManager.show(context, message: message);
                      } else {
                        SuccessToastManager.showError(
                          context,
                          message: message,
                        );
                      }
                    },
                  ),
                ),
              ),
        ),
      );
    }
  }

  void _confirmDeletePatient(BuildContext context, Patient patient) async {
    // 使用新的公共组件显示删除确认对话框
    final confirmed = await ModernDeleteDialogManager.showPatientDelete(
      context,
      patientName: patient.name,
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      try {
        await Provider.of<PatientProvider>(
          context,
          listen: false,
        ).deletePatient(patient.id!);
        _loadPatients();

        // 使用新的成功提示组件
        if (context.mounted) {
          SuccessToastManager.show(context, message: '患者删除成功');
        }
      } catch (e) {
        if (context.mounted) {
          SuccessToastManager.showError(context, message: '删除失败: $e');
        }
      }
    }
  }

  // 应用时间筛选
  void _applyTimeFilter() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _isDateRangeFiltering = true;
        _currentPage = 1;
        _hasMoreData = true;
      });
      _loadPatients();
    }
  }

  // 清除时间筛选
  void _clearTimeFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeFiltering = false;
      _currentPage = 1;
      _hasMoreData = true;
    });
    _loadPatients();
  }

  // 应用时间筛选到患者列表
  List<Patient> _applyTimeFilterToPatients(List<Patient> patients) {
    if (!_isDateRangeFiltering || _startDate == null || _endDate == null) {
      return patients;
    }

    return patients.where((patient) {
      DateTime? patientDate;

      if (_dateFilterType == 'first_visit_date') {
        patientDate = patient.firstVisitDate;
      } else if (_dateFilterType == 'updated_at') {
        patientDate = patient.updatedAt;
      }

      if (patientDate == null) {
        return false;
      }

      // 检查日期是否在范围内（包含开始和结束日期）
      // 将患者日期标准化为当天的开始时间（00:00:00）
      final patientDateOnly = DateTime(
        patientDate.year,
        patientDate.month,
        patientDate.day,
      );
      final startDateOnly = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      final endDateOnly = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
      );

      // 使用 compareTo 进行日期比较，包含开始和结束日期
      return patientDateOnly.compareTo(startDateOnly) >= 0 &&
          patientDateOnly.compareTo(endDateOnly) <= 0;
    }).toList();
  }
}
