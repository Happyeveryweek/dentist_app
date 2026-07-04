import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/patient.dart';
import '../providers/financial_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/app_state.dart';
import '../widgets/mysql_connection_warning.dart';
import '../widgets/success_toast.dart';
import '../features/financial/widgets/financial_search_bar.dart';
import '../utils/pinyin_util.dart';
import '../features/financial/widgets/financial_form_dialog.dart';
import 'financial_detail_screen.dart';
import '../features/financial/widgets/financial_statistics_dialog.dart';
import '../features/financial/widgets/financial_record_edit_dialog.dart';
import '../features/financial/widgets/financial_card.dart';
import '../features/financial/widgets/financial_item_card.dart';
import '../features/financial/widgets/financial_advanced_filter_dialog.dart';
import '../features/financial/helpers/financial_calculation_helper.dart';
import '../features/financial/helpers/financial_pagination_helper.dart';
import '../features/financial/helpers/patient_calculation_helper.dart';
import '../features/financial/helpers/financial_data_filter_helper.dart';
import '../features/financial/helpers/financial_data_aggregator.dart';
import '../features/financial/helpers/financial_items_mapper.dart';
import '../features/financial/services/financial_statistics_service.dart';
import '../features/financial/widgets/financial_date_range_selector.dart';
import '../features/financial/services/patient_cache_service.dart';
import '../features/financial/widgets/financial_empty_state.dart';
import '../features/financial/widgets/financial_records_list_view.dart';
import '../utils/log_manager.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({Key? key}) : super(key: key);

  @override
  State<FinancialManagementScreen> createState() =>
      _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen> {
  List<FinancialRecord> _financialRecords = [];
  List<Patient> _patients = [];
  Map<int, List<FinancialItem>> _recordItemsMap = {};
  List<Map<String, dynamic>> _financialItemsWithDetails = []; // 按收费记录显示模式的数据
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageJumpController = TextEditingController();

  // Route B 支持：按患者聚合后的日期覆盖（由后端聚合直接提供）
  final Map<int, DateTime> _patientLatestChargeDateMap = {}; // key: patientId
  final Map<int, DateTime> _patientLastUpdatedMap = {}; // key: patientId
  final Map<int, double> _patientReceivableSumMap = {}; // 后端合计: 应收
  final Map<int, double> _patientReceivedSumMap = {}; // 后端合计: 已收
  final Map<int, double> _patientProcessingSumMap = {}; // 后端合计: 加工费
  bool _patientServerPaged = false; // 是否使用后端已分页的患者模式

  // 显示模式相关变量
  String _displayMode = 'patient'; // 'patient' 或 'record'

  // 排序相关变量
  String _sortBy =
      'charge_date'; // 可选: 'updated_at' | 'charge_date' | 'receivable' | 'received' | 'processing_fee'
  bool _sortAscending = false; // true为升序, false为降序

  // 时间范围选择相关变量
  DateTime? _startDate;
  DateTime? _endDate;

  // 高级筛选（收费项目/金额区间）
  String _chargeItemQuery = '';
  double? _receivableMin;
  double? _receivableMax;
  double? _receivedMin;
  double? _receivedMax;
  double? _processingMin;
  double? _processingMax;

  // 分页相关变量
  int _currentPage = 1;
  final int _recordsPerPage = 10;
  int _totalRecords = 0;
  int _totalPages = 0;

  // 页面数据缓存
  final Map<int, List<Map<String, dynamic>>> _pageCache = {};

  // 患者缓存服务
  late PatientCacheService _patientCacheService;

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // 初始化患者缓存服务
    final patientProvider =
        Provider.of<PatientProvider>(context, listen: false);
    _patientCacheService = PatientCacheService(patientProvider);

    // 延迟加载数据，给Provider足够的时间进行初始化
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_hasInitialized) {
        _hasInitialized = true;
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // 高级筛选（收费项目/金额区间）

  @override
  void dispose() {
    _searchController.dispose();
    _pageJumpController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // 时间范围选择方法
  Future<void> _showCustomDateRangePicker() async {
    await FinancialDateRangeSelector.showCustomDateRangePicker(
      context: context,
      startDate: _startDate,
      endDate: _endDate,
      onDateRangeSelected: (start, end) {
        if (mounted) {
          setState(() {
            _startDate = start;
            _endDate = end;
          });
          _filterFinancialData();
        }
      },
    );
  }

  bool get _hasAdvancedFilter =>
      _chargeItemQuery.isNotEmpty ||
      _receivableMin != null ||
      _receivableMax != null ||
      _receivedMin != null ||
      _receivedMax != null ||
      _processingMin != null ||
      _processingMax != null;

  String _formatFilterValue(double value) {
    final text = NumberFormat('0.##').format(value);
    return text;
  }

  String _buildRangeLabel(String label, double? min, double? max) {
    if (min == null && max == null) {
      return '';
    }
    if (min != null && max != null) {
      return '$label ${_formatFilterValue(min)}~${_formatFilterValue(max)}';
    }
    if (min != null) {
      return '$label ≥${_formatFilterValue(min)}';
    }
    return max != null ? '$label ≤${_formatFilterValue(max)}' : '';
  }

  String _buildAdvancedFilterSummary() {
    final parts = <String>[];

    if (_chargeItemQuery.isNotEmpty) {
      parts.add('收费项目: $_chargeItemQuery');
    }

    final receivable = _buildRangeLabel('应收', _receivableMin, _receivableMax);
    if (receivable.isNotEmpty) parts.add(receivable);

    final received = _buildRangeLabel('已收', _receivedMin, _receivedMax);
    if (received.isNotEmpty) parts.add(received);

    final processing = _buildRangeLabel('加工费', _processingMin, _processingMax);
    if (processing.isNotEmpty) parts.add(processing);

    return parts.join(' | ');
  }

  void _syncSearchControllerText() {
    final displayText =
        _hasAdvancedFilter ? _buildAdvancedFilterSummary() : _searchQuery;
    if (_searchController.text == displayText) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: displayText,
      selection: TextSelection.collapsed(offset: displayText.length),
    );
  }

  void _clearAdvancedFilters() {
    setState(() {
      _chargeItemQuery = '';
      _receivableMin = null;
      _receivableMax = null;
      _receivedMin = null;
      _receivedMax = null;
      _processingMin = null;
      _processingMax = null;
    });
    _syncSearchControllerText();
    _currentPage = 1;
    _loadData();
  }

  String _resolveFinancialPatientsDataSource([
    FinancialProvider? financialProvider,
  ]) {
    final provider = financialProvider ??
        Provider.of<FinancialProvider>(context, listen: false);
    return provider.dataSourceType;
  }

  List<Patient> _decoratePatients(List<Patient> patients) {
    return patients
        .map((patient) => patient.copyWith(
              namePinyin: PinyinUtil.toPinyin(patient.name),
              nameInitials: PinyinUtil.getInitials(patient.name),
            ))
        .toList();
  }

  DateTime _parseDateTime(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? (fallback ?? DateTime.now());
  }

  FinancialRecord _buildFallbackRepresentativeRecordFromRow(
      Map<String, dynamic> row) {
    final patientId = row['patient_id'] as int;
    return FinancialRecord(
      id: patientId,
      patientId: patientId,
      totalQuantity: 0,
      notes: null,
      createdAt: _parseDateTime(row['latest_charge_date']),
      updatedAt: _parseDateTime(row['last_updated']),
    );
  }

  void _applyPatientAggregateMaps(Iterable<Map<String, dynamic>> rows) {
    _patientLatestChargeDateMap
      ..clear()
      ..addEntries(rows.map<MapEntry<int, DateTime>>((row) {
        final pid = row['patient_id'] as int;
        return MapEntry(pid, _parseDateTime(row['latest_charge_date']));
      }));
    _patientLastUpdatedMap
      ..clear()
      ..addEntries(rows.map<MapEntry<int, DateTime>>((row) {
        final pid = row['patient_id'] as int;
        return MapEntry(pid, _parseDateTime(row['last_updated']));
      }));
    _patientReceivableSumMap
      ..clear()
      ..addEntries(rows.map<MapEntry<int, double>>((row) {
        return MapEntry(row['patient_id'] as int,
            (row['receivable_sum'] as num?)?.toDouble() ?? 0.0);
      }));
    _patientReceivedSumMap
      ..clear()
      ..addEntries(rows.map<MapEntry<int, double>>((row) {
        return MapEntry(row['patient_id'] as int,
            (row['received_sum'] as num?)?.toDouble() ?? 0.0);
      }));
    _patientProcessingSumMap
      ..clear()
      ..addEntries(rows.map<MapEntry<int, double>>((row) {
        return MapEntry(row['patient_id'] as int,
            (row['processing_sum'] as num?)?.toDouble() ?? 0.0);
      }));
  }

  List<Map<String, dynamic>> _buildPatientSummaryData(
      Iterable<FinancialRecord> records) {
    final result = <Map<String, dynamic>>[];
    for (final record in records) {
      final patient = _getPatientById(record.patientId);
      result.add({
        'patient': patient ??
            Patient.placeholderForFinancialRecord(
              patientId: record.patientId,
              recordId: record.id,
              createdAt: record.createdAt,
            ),
        'record': record,
        'totalCost': _getPatientTotalReceivable(record.patientId),
        'lastFinancialUpdateDate':
            _getPatientLastFinancialUpdateDate(record.patientId),
      });
    }
    return result;
  }

  List<Map<String, dynamic>> _buildPatientServerPagedData(
      Iterable<FinancialRecord> records) {
    final result = <Map<String, dynamic>>[];
    for (final record in records) {
      final patient = _getPatientById(record.patientId);
      final pid = record.patientId;
      result.add({
        'patient': patient ??
            Patient.placeholderForFinancialRecord(
              patientId: pid,
              recordId: record.id,
              createdAt: record.createdAt,
            ),
        'record': record,
        'totalCost': _patientReceivableSumMap[pid] ?? 0.0,
        'receivedSum': _patientReceivedSumMap[pid] ?? 0.0,
        'processingSum': _patientProcessingSumMap[pid] ?? 0.0,
        'lastFinancialUpdateDate': _patientLastUpdatedMap[pid],
      });
    }
    return result;
  }

  Future<List<FinancialRecord>> _buildRepresentativeRecords(
    FinancialProvider financialProvider,
    Iterable<Map<String, dynamic>> rows,
  ) async {
    final result = <FinancialRecord>[];
    for (final row in rows) {
      final pid = row['patient_id'] as int;
      final record = await financialProvider.getLatestRecordForPatient(pid);
      result.add(record ?? _buildFallbackRepresentativeRecordFromRow(row));
    }
    return result;
  }

  // 获取分页后的数据（根据显示模式）
  List<Map<String, dynamic>> _getPagedData() {
    // 如果是患者模式且已使用后端分页，则不再做二次分页，直接将当前页代表记录映射为UI数据
    if (_displayMode == 'patient' && _patientServerPaged) {
      return _buildPatientServerPagedData(_financialRecords);
    }

    // 其余情况（记录模式或旧患者模式前端聚合）：按原逻辑分页
    final filteredData = _filteredFinancialData;
    final startIndex = (_currentPage - 1) * _recordsPerPage;
    final endIndex = startIndex + _recordsPerPage;

    final pagedData = filteredData.sublist(
      startIndex.clamp(0, filteredData.length),
      endIndex.clamp(0, filteredData.length),
    );

    if (_displayMode == 'patient') {
      return _buildPatientSummaryData(
        pagedData.map((data) => data['record'] as FinancialRecord),
      );
    }

    // 记录模式
    return pagedData;
  }

  // 跳转到指定页面
  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
      });
      _loadData(); // 重新从后端加载数据
    } else {}
  }

  // 跳转到上一页
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _goToPage(_currentPage - 1);
    }
  }

  // 跳转到下一页
  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      _goToPage(_currentPage + 1);
    } else {
      LogManager.e('FinancialManagementScreen', '⚠️ 已经是最后一页，无法继续下一页');
    }
  }

  // 加载数据
  Future<void> _loadData({bool showLoading = true}) async {
    if (!mounted) return;

    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final financialProvider =
          Provider.of<FinancialProvider>(context, listen: false);
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final patientsDataSource =
          _resolveFinancialPatientsDataSource(financialProvider);

      // 若有搜索词，先在SQLite中查患者ID；否则不限制
      List<int>? filterPatientIds;
      if (_searchQuery.isNotEmpty) {
        try {
          filterPatientIds = await patientProvider.searchPatientIds(
            _searchQuery,
            effectiveDataSourceType: patientsDataSource,
          );
        } catch (e) {
          LogManager.e('FinancialManagementScreen', '搜索患者ID失败', error: e);
          filterPatientIds = [];
        }
      }

      if (!mounted) return;

      if (_searchQuery.isNotEmpty &&
          filterPatientIds != null &&
          filterPatientIds.isEmpty) {
        setState(() {
          _financialRecords = [];
          _patients = [];
          _recordItemsMap = {};
          _financialItemsWithDetails = [];
          _totalRecords = 0;
          _totalPages = 0;
          _isLoading = false;
          _patientServerPaged = _displayMode == 'patient';
          _patientLatestChargeDateMap.clear();
          _patientLastUpdatedMap.clear();
          _patientReceivableSumMap.clear();
          _patientReceivedSumMap.clear();
          _patientProcessingSumMap.clear();
          _pageCache.clear();
        });
        return;
      }

      if (_displayMode == 'patient') {
        // Route B：由 Provider 后端聚合并分页
        final String sortKey = () {
          switch (_sortBy) {
            case 'charge_date':
              return 'charge_date';
            case 'updated_at':
              return 'updated_at';
            case 'received':
              return 'received_sum';
            case 'receivable':
              return 'receivable_sum';
            case 'debt':
              return 'debt_sum';
            default:
              return 'updated_at';
          }
        }();
        final agg = await financialProvider.getPatientAggregatesPage(
          page: _currentPage,
          pageSize: _recordsPerPage,
          sortBy: sortKey,
          sortOrder: _sortAscending ? 'ASC' : 'DESC',
          patientIds: filterPatientIds,
          startDate: _startDate,
          endDate: _endDate,
        );
        final int total = (agg['total'] as int? ?? 0);
        final rows =
            (agg['rows'] as List? ?? const []).cast<Map<String, dynamic>>();
        final pagePatientIds =
            rows.map<int>((r) => r['patient_id'] as int).toList();

        // 预加载患者信息
        final fetchedPatients = await patientProvider.getPatientsByIds(
          pagePatientIds,
          effectiveDataSourceType: patientsDataSource,
        );
        final patients = _decoratePatients(fetchedPatients);

        // 检查是否有患者ID查不到
        final fetchedIds = fetchedPatients.map((p) => p.id).toSet();
        final missingIds =
            pagePatientIds.where((id) => !fetchedIds.contains(id)).toList();
        if (missingIds.isNotEmpty) {}

        final repRecords =
            await _buildRepresentativeRecords(financialProvider, rows);

        _applyPatientAggregateMaps(rows);

        if (!mounted) return;
        setState(() {
          _financialRecords = repRecords; // 仅一页代表记录
          _patients = patients;
          _recordItemsMap = {}; // 不再逐条加载明细
          _financialItemsWithDetails = [];
          _totalRecords = total;
          _totalPages = FinancialPaginationHelper.calculateTotalPages(
              _totalRecords, _recordsPerPage);
          _isLoading = false;
          _patientCacheService.clearCache();
          _patientServerPaged = true;

          // 缓存当前页数据
          _pageCache[_currentPage] = rows;
        });
      } else {
        // 按收费记录显示模式：按 financial_items 分页
        final results = await Future.wait([
          financialProvider.getFinancialItemsCount(
            startDate: _startDate,
            endDate: _endDate,
            patientIds: filterPatientIds,
            chargeItemQuery:
                _chargeItemQuery.isNotEmpty ? _chargeItemQuery : null,
            receivableMin: _receivableMin,
            receivableMax: _receivableMax,
            receivedMin: _receivedMin,
            receivedMax: _receivedMax,
            processingMin: _processingMin,
            processingMax: _processingMax,
          ),
          // 记录模式下将UI排序键映射到financial_items真实列名
          financialProvider.getFinancialItemsWithDetails(
            page: _currentPage,
            pageSize: _recordsPerPage,
            sortBy: (() {
              switch (_sortBy) {
                case 'receivable':
                  return 'item_price';
                case 'received':
                  return 'total_price';
                case 'processing_fee':
                  return 'processing_fee';
                case 'charge_date':
                  return 'charge_date';
                case 'updated_at':
                default:
                  return 'updated_at';
              }
            })(),
            sortOrder: _sortAscending ? 'ASC' : 'DESC',
            startDate: _startDate,
            endDate: _endDate,
            patientIds: filterPatientIds,
            chargeItemQuery:
                _chargeItemQuery.isNotEmpty ? _chargeItemQuery : null,
            receivableMin: _receivableMin,
            receivableMax: _receivableMax,
            receivedMin: _receivedMin,
            receivedMax: _receivedMax,
            processingMin: _processingMin,
            processingMax: _processingMax,
          ),
        ]);

        if (!mounted) return;

        final totalRecords = results[0] as int;
        final itemsWithDetails = results[1] as List<Map<String, dynamic>>;

        // 提取当前页患者ID并在SQLite中批量查询
        final pagePatientIds = itemsWithDetails
            .map((data) => data['patient_id'] as int)
            .toSet()
            .toList();

        final fetchedPatients = await patientProvider.getPatientsByIds(
          pagePatientIds,
          effectiveDataSourceType: patientsDataSource,
        );
        final patients = _decoratePatients(fetchedPatients);

        setState(() {
          _financialRecords = [];
          _recordItemsMap = {};
          _financialItemsWithDetails = itemsWithDetails;
          _patients = patients;
          _totalRecords = totalRecords;
          _totalPages = FinancialPaginationHelper.calculateTotalPages(
              _totalRecords, _recordsPerPage);
          _isLoading = false;

          // 清空缓存，因为患者列表已更新
          _patientCacheService.clearCache();

          // 首次加载时不设置日期范围，显示所有数据
          // 用户可以手动选择日期范围进行过滤
        });
      }
    } catch (e) {
      LogManager.e('FinancialManagementScreen', '❌ 加载数据失败', error: e);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // 获取患者信息（带缓存）
  Future<Patient?> _getPatientByIdAsync(int patientId) async {
    final patientsDataSource = _resolveFinancialPatientsDataSource();

    return _patientCacheService.getPatientById(
      patientId,
      preloadedPatients: _patients,
      effectiveDataSourceType: patientsDataSource,
      onPatientAdded: (patient) {
        if (!_patients.any((p) => p.id == patientId)) {
          _patients.add(patient);
        }
      },
    );
  }

  // 同步获取患者信息（仅用于已缓存的情况）
  Patient? _getPatientById(int patientId) {
    return _patientCacheService.getPatientByIdSync(patientId, _patients);
  }

  // 获取患者的应收费总额
  double _getPatientTotalReceivable(int patientId) {
    return PatientCalculationHelper.getPatientTotalReceivable(
      patientId,
      _financialRecords,
      _recordItemsMap,
    );
  }

  // 获取患者最近财务更新时间（最近财务记录的updatedAt）
  DateTime? _getPatientLastFinancialUpdateDate(int patientId) {
    return PatientCalculationHelper.getPatientLastFinancialUpdateDate(
      patientId,
      _financialRecords,
    );
  }

  // 过滤后的财务数据（支持时间范围筛选和搜索）
  List<Map<String, dynamic>> get _filteredFinancialData {
    final List<Map<String, dynamic>> sourceData;

    if (_displayMode == 'patient') {
      sourceData = _getFinancialData();
    } else {
      sourceData = _getAllFinancialItemsData();
    }

    return FinancialDataFilterHelper.filterAndSortFinancialData(
      displayMode: _displayMode,
      sourceData: sourceData,
      sortBy: _sortBy,
      sortAscending: _sortAscending,
      searchQuery: _searchQuery,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  List<Map<String, dynamic>> _getFinancialData() {
    return FinancialDataAggregator.getFinancialData(
      financialRecords: _financialRecords,
      recordItemsMap: _recordItemsMap,
      patientLatestChargeDateMap: _patientLatestChargeDateMap,
      patientLastUpdatedMap: _patientLastUpdatedMap,
      sortBy: _sortBy,
      sortAscending: _sortAscending,
      getPatientById: _getPatientById,
    );
  }

  List<Map<String, dynamic>> _getAllFinancialItemsData() {
    return FinancialItemsMapper.getAllFinancialItemsData(
      financialRecords: _financialRecords,
      recordItemsMap: _recordItemsMap,
      getPatientById: _getPatientById,
    );
  }

  // 过滤财务数据（触发UI更新）
  void _filterFinancialData() {
    setState(() {
      _currentPage = 1; // 重置到第一页
      _pageCache.clear(); // 清除缓存
    });
    _loadData(showLoading: false); // 重新从后端加载数据
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
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '财务管理',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: context.tokens.shellBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          // 显示模式切换按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _displayMode == 'patient'
                  ? context.tokens.primaryAccent.withValues(alpha: 0.1)
                  : context.tokens.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _displayMode == 'patient'
                    ? context.tokens.primaryAccent.withValues(alpha: 0.3)
                    : context.tokens.border,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.people_rounded,
                color: _displayMode == 'patient'
                    ? context.tokens.primaryAccent
                    : context.tokens.textMuted,
              ),
              onPressed: () {
                setState(() {
                  _displayMode = 'patient';
                  _currentPage = 1;
                  _sortBy = 'charge_date';
                  _sortAscending = false;
                  // 患者模式允许的排序字段：最近更新/收费日期/应收费/已收费/欠费
                  const allowed = [
                    'updated_at',
                    'charge_date',
                    'receivable',
                    'received',
                    'debt'
                  ];
                  if (!allowed.contains(_sortBy)) {
                    _sortBy = 'charge_date';
                  }
                });
                _filterFinancialData();
              },
              tooltip: '按患者显示',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _displayMode == 'record'
                  ? context.tokens.primaryAccent.withValues(alpha: 0.1)
                  : context.tokens.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _displayMode == 'record'
                    ? context.tokens.primaryAccent.withValues(alpha: 0.3)
                    : context.tokens.border,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.list_alt_rounded,
                color: _displayMode == 'record'
                    ? context.tokens.primaryAccent
                    : context.tokens.textMuted,
              ),
              onPressed: () {
                setState(() {
                  _displayMode = 'record';
                  _currentPage = 1;
                  _sortBy = 'charge_date';
                  _sortAscending = false;
                });
                _filterFinancialData();
              },
              tooltip: '按收费记录显示',
            ),
          ),
          // 添加收费记录按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: context.tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () async {
                final changed = await _showFinancialRecordDialog();
                if (changed && mounted) {
                  await _loadData(showLoading: false);
                }
              },
              tooltip: '添加收费记录',
            ),
          ),
          // 收费图表统计按钮
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: context.tokens.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.tokens.success.withValues(alpha: 0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.bar_chart_rounded,
                color: context.tokens.success,
              ),
              onPressed: _showFinancialStatistics,
              tooltip: '收费图表统计',
            ),
          ),
          // 刷新按钮（移到最右侧）
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: context.tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () async {
                final financialProvider =
                    Provider.of<FinancialProvider>(context, listen: false);
                financialProvider.clearCache();
                await _loadData(showLoading: false);
                if (!context.mounted) return;
                AppToastManager.showSuccess(context, message: '刷新数据成功');
              },
              tooltip: '刷新数据',
            ),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return Consumer<FinancialProvider>(
            builder: (context, financialProvider, child) {
              if (financialProvider.financialsNeedRefresh) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _loadData(showLoading: false);
                    financialProvider.resetFinancialsRefreshFlag();
                  }
                });
              }

              return Column(
                children: [
                  // MySQL连接失败警告（如果有）
                  const MySQLConnectionWarning(moduleName: '财务管理'),

                  // 搜索栏 + 工具条（紧凑白底圆角容器）
                  FinancialSearchBar(
                    displayMode: _displayMode,
                    searchController: _searchController,
                    searchQuery: _hasAdvancedFilter
                        ? _buildAdvancedFilterSummary()
                        : _searchQuery,
                    sortBy: _sortBy,
                    sortAscending: _sortAscending,
                    startDate: _startDate,
                    endDate: _endDate,
                    hasAdvancedFilter: _hasAdvancedFilter,
                    searchReadOnly: _hasAdvancedFilter,
                    onSearchChanged: (value) {
                      if (_hasAdvancedFilter) {
                        return;
                      }
                      setState(() {
                        _searchQuery = value;
                      });
                      _currentPage = 1;
                      _loadData(showLoading: false);
                    },
                    onSearchCleared: () {
                      if (_hasAdvancedFilter) {
                        _clearAdvancedFilters();
                        return;
                      }
                      setState(() {
                        _searchQuery = '';
                      });
                      _syncSearchControllerText();
                      _currentPage = 1;
                      _loadData(showLoading: false);
                    },
                    onSortChanged: (String value) {
                      setState(() {
                        if (_sortBy == value) {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortBy = value;
                          _sortAscending = false;
                        }
                      });
                      _filterFinancialData();
                    },
                    onDateRangeTap: () async {
                      await _showCustomDateRangePicker();
                    },
                    onDateRangeCleared: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _filterFinancialData();
                    },
                    onAdvancedFilterTap: _showAdvancedFilterDialog,
                  ),
                  // 内容区域
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _totalRecords == 0
                            ? FinancialEmptyState(
                                searchQuery: _searchQuery,
                                onAddRecord: () async {
                                  final changed =
                                      await _showFinancialRecordDialog();
                                  if (changed && mounted) {
                                    await _loadData(showLoading: false);
                                  }
                                },
                              )
                            : Column(
                                children: [
                                  Expanded(child: _buildRecordsList()),
                                ],
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 构建统计信息区域

  // 构建统计项组件

  // 构建记录列表
  // 滚动控制器
  final ScrollController _horizontalScrollController = ScrollController();

  // 构建表头

  // 构建表头单元格

  // 构建记录卡片

  // 显示财务详情（弹窗形式）
  void _showFinancialDetail(Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 800,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            minHeight: 500,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FinancialDetailScreen(
              patient: patient,
            ),
          ),
        ),
      ),
    ).then((result) {
      // 只有在有数据变动时才刷新（result为true表示有变动）
      if (result == true && mounted) {
        _loadData(showLoading: false);
      }
    });
  }

  // 删除患者所有财务记录
  Future<void> _deleteAllFinancialRecordsByPatient(
      FinancialRecord record) async {
    final patientName = _getPatientById(record.patientId)?.name ?? '未知';
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '确认删除',
      message: '确定要删除患者 $patientName 的所有财务记录吗？\n\n删除后无法恢复！',
      confirmText: '删除',
      cancelText: '取消',
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final financialProvider =
            Provider.of<FinancialProvider>(context, listen: false);

        // 获取该患者的所有财务记录
        final patientRecords = _financialRecords
            .where((r) => r.patientId == record.patientId)
            .toList();

        // 删除所有相关记录
        for (final patientRecord in patientRecords) {
          final recordId = patientRecord.id;
          if (recordId == null) continue;

          final items = _recordItemsMap[recordId] ?? [];
          for (final item in items) {
            final itemId = item.id;
            if (itemId != null) {
              await financialProvider.deleteFinancialItem(itemId);
            }
          }
          await financialProvider.deleteFinancialRecord(recordId);
        }

        if (!mounted) return;
        AppToastManager.showDelete(
          context,
          message: '患者财务记录删除成功',
        );
        await _loadData(showLoading: false);
      } catch (e) {
        if (!mounted) return;
        AppToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }

  // 显示财务统计图表（改为基于当前筛选从数据源获取全量明细）
  Future<void> _showFinancialStatistics() async {
    try {
      final data = await FinancialStatisticsService.getStatisticsData(
        context: context,
        searchQuery: _searchQuery,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
        startDate: _startDate,
        endDate: _endDate,
        chargeItemQuery: _chargeItemQuery,
        receivableMin: _receivableMin,
        receivableMax: _receivableMax,
        receivedMin: _receivedMin,
        receivedMax: _receivedMax,
        processingMin: _processingMin,
        processingMax: _processingMax,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 5 / 6,
              height: MediaQuery.of(context).size.height * 5 / 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FinancialStatsDialog(
                  financialRecords: data.financialRecords,
                  financialItems: data.financialItems,
                  patients: data.patients,
                  searchQuery: data.searchQuery,
                  initialStartDate: data.initialStartDate,
                  initialEndDate: data.initialEndDate,
                  chargeItemQuery: data.chargeItemQuery,
                  onRefresh: () => FinancialStatisticsService.getStatisticsData(
                    context: context,
                    searchQuery: _searchQuery,
                    sortBy: _sortBy,
                    sortAscending: _sortAscending,
                    startDate: _startDate,
                    endDate: _endDate,
                    chargeItemQuery: _chargeItemQuery,
                    receivableMin: _receivableMin,
                    receivableMax: _receivableMax,
                    receivedMin: _receivedMin,
                    receivedMax: _receivedMax,
                    processingMin: _processingMin,
                    processingMax: _processingMax,
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载统计数据失败: $e')),
      );
    }
  }

  // 显示添加/编辑财务记录对话框

  // 显示编辑财务记录对话框（专用方法）
  // 这是专门用于财务管理列表编辑按钮的方法，显示收费信息列表并允许编辑备注

  // 构建财务卡片 - 紧凑版

  // 紧凑型财务标签

  // 紧凑型财务操作按钮

  // 构建紧凑信息项组件

  // 计算已收金额
  double _calculateTotalCollected(FinancialRecord record) {
    return FinancialCalculationHelper.calculateTotalCollected(
        record, _recordItemsMap);
  }

  // 计算加工费总额
  double _calculateTotalProcessingFee(FinancialRecord record) {
    return FinancialCalculationHelper.calculateTotalProcessingFee(
        record, _recordItemsMap);
  }

  // 构建收费记录卡片（按收费记录显示模式）

  // 构建数据单元格

  // 构建日期单元格

  // 构建金额单元格

  // 构建操作按钮

  // 编辑收费记录明细项
  Future<void> _editFinancialItem(
      FinancialRecord record, FinancialItem item, Patient patient) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FinancialFormDialog(
        record: record,
        contextPatient: patient,
        item: item,
        showNotesField: false,
        notifyOnSave: false,
      ),
    );
    if (result == true) {
      await _loadData(showLoading: false);
    }
  }

  // 删除收费记录明细项
  Future<void> _deleteFinancialItem(
      FinancialRecord record, FinancialItem item, Patient patient) async {
    final recordId = record.id;
    final itemId = item.id;
    if (recordId == null || itemId == null) {
      AppToastManager.showError(context, message: '财务记录或收费项目 ID 为空');
      return;
    }

    final financialProvider =
        Provider.of<FinancialProvider>(context, listen: false);
    final recordItems =
        await financialProvider.getFinancialItemsByRecordId(recordId);
    final isLastItem = recordItems.length <= 1;

    if (!mounted) return;
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '确认删除',
      message: '确定要删除患者 "${patient.name}" 的这条收费明细项吗？\n\n'
          '收费项目: ${item.itemName}\n'
          '收费日期: ${DateFormat('yyyy-MM-dd').format(item.chargeDate)}\n'
          '${isLastItem ? '\n这是该患者这条财务记录的最后一条收费记录，删除后会连带删除整条财务记录。\n' : '\n'}'
          '删除后无法恢复！',
      confirmText: '删除',
      cancelText: '取消',
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final success =
            await financialProvider.deleteFinancialItemAndCleanupRecord(
          itemId: itemId,
          recordId: recordId,
        );

        if (success) {
          if (!mounted) return;
          AppToastManager.showDelete(
            context,
            message: isLastItem
                ? '已删除患者 "${patient.name}" 的最后一条收费记录，并同步删除财务记录'
                : '已删除患者 "${patient.name}" 的收费明细项',
          );
        } else {
          if (!mounted) return;
          AppToastManager.showError(
            context,
            message: '删除失败',
          );
        }
      } catch (e) {
        if (!mounted) return;
        AppToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }

  // 构建记录列表
  Widget _buildRecordsList() {
    return FinancialRecordsListView(
      displayMode: _displayMode,
      financialItemsWithDetails: _financialItemsWithDetails,
      horizontalScrollController: _horizontalScrollController,
      totalRecords: _totalRecords,
      currentPage: _currentPage,
      totalPages: _totalPages,
      recordsPerPage: _recordsPerPage,
      pageJumpController: _pageJumpController,
      onGoToPage: _goToPage,
      onGoToPreviousPage: _goToPreviousPage,
      onGoToNextPage: _goToNextPage,
      getPagedData: _getPagedData,
      getPatientByIdAsync: _getPatientByIdAsync,
      getPatientTotalReceivable: _getPatientTotalReceivable,
      getPatientLastFinancialUpdateDate: _getPatientLastFinancialUpdateDate,
      buildFinancialCard: _buildFinancialCard,
      buildFinancialItemCard: _buildFinancialItemCard,
    );
  }

  // 构建财务卡片
  Widget _buildFinancialCard(
    Patient patient,
    FinancialRecord record,
    double totalCost,
    DateTime? lastFinancialUpdateDate, {
    double? receivedSum,
    double? processingSum,
  }) {
    // 计算财务数据
    final fee = processingSum ?? _calculateTotalProcessingFee(record);
    final received = receivedSum ?? _calculateTotalCollected(record);
    final debt = totalCost - received;

    return FinancialCard(
      patient: patient,
      record: record,
      totalCost: totalCost,
      lastFinancialUpdateDate: lastFinancialUpdateDate,
      receivedSum: receivedSum,
      processingSum: processingSum,
      fee: fee,
      received: received,
      debt: debt,
      onTap: () => _showFinancialDetail(patient),
      onEdit: () async {
        return await _showEditFinancialRecordDialog(patient, record);
      },
      onDelete: () => _deleteAllFinancialRecordsByPatient(record),
    );
  }

  // 构建财务项目卡片
  Widget _buildFinancialItemCard(
      Patient patient, FinancialRecord record, FinancialItem item) {
    return FinancialItemCard(
      patient: patient,
      record: record,
      item: item,
      onEdit: () => _editFinancialItem(record, item, patient),
      onDelete: () => _deleteFinancialItem(record, item, patient),
    );
  }

  // 显示高级筛选对话框
  Future<void> _showAdvancedFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FinancialAdvancedFilterDialog(
        initialChargeItemQuery: _chargeItemQuery,
        initialReceivableMin: _receivableMin,
        initialReceivableMax: _receivableMax,
        initialReceivedMin: _receivedMin,
        initialReceivedMax: _receivedMax,
        initialProcessingMin: _processingMin,
        initialProcessingMax: _processingMax,
      ),
    );

    if (result != null) {
      if (result['cleared'] == true) {
        setState(() {
          _chargeItemQuery = '';
          _receivableMin = null;
          _receivableMax = null;
          _receivedMin = null;
          _receivedMax = null;
          _processingMin = null;
          _processingMax = null;
        });
      } else {
        setState(() {
          _chargeItemQuery = result['chargeItemQuery'] as String;
          _receivableMin = result['receivableMin'] as double?;
          _receivableMax = result['receivableMax'] as double?;
          _receivedMin = result['receivedMin'] as double?;
          _receivedMax = result['receivedMax'] as double?;
          _processingMin = result['processingMin'] as double?;
          _processingMax = result['processingMax'] as double?;
        });
      }
      _syncSearchControllerText();
      _filterFinancialData();
    }
  }

  // 显示财务记录对话框
  Future<bool> _showFinancialRecordDialog(
      [FinancialRecord? record, Patient? contextPatient]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FinancialFormDialog(
        record: record,
        contextPatient: contextPatient,
      ),
    );

    return result ?? false;
  }

  // 显示编辑财务记录对话框
  Future<bool> _showEditFinancialRecordDialog(
      Patient patient, FinancialRecord record) async {
    try {
      // 显示完整的编辑对话框，包含收费信息列表和备注编辑
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => FinancialRecordEditDialog(
          patient: patient,
          record: record,
        ),
      );

      return result ?? false;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('编辑财务记录失败: $e'),
          backgroundColor: context.tokens.error,
          duration: const Duration(seconds: 3),
        ),
      );

      // 记录错误日志
      LogManager.e('FinancialManagementScreen', '编辑财务记录时发生错误', error: e);
      return false;
    }
  }
}
