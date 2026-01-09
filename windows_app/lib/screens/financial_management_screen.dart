import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/patient.dart';
import '../providers/financial_provider.dart';
import '../providers/database_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/app_state.dart';
import '../widgets/mysql_connection_warning.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../widgets/unified_search_field.dart';
import '../widgets/modern_date_picker.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../widgets/success_toast.dart';
import '../widgets/success_toast.dart' show DeleteConfirmDialogManager;
import '../utils/pinyin_util.dart';
import 'financial_form_dialog.dart';
import 'financial_detail_screen.dart';
import 'financial_statistics_dialog.dart';
import 'financial_detail_form_dialog.dart';


class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({Key? key}) : super(key: key);

  @override
  State<FinancialManagementScreen> createState() => _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen> {
  List<FinancialRecord> _financialRecords = [];
  List<Patient> _patients = [];
  Map<int, List<FinancialItem>> _recordItemsMap = {};
  List<FinancialRecord> _displayedRecords = []; // 当前页面显示的记录
  List<Map<String, dynamic>> _financialItemsWithDetails = []; // 按收费记录显示模式的数据
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();
  TextEditingController _pageJumpController = TextEditingController();

  // Route B 支持：按患者聚合后的日期覆盖（由后端聚合直接提供）
  final Map<int, DateTime> _patientLatestChargeDateMap = {}; // key: patientId
  final Map<int, DateTime> _patientLastUpdatedMap = {}; // key: patientId
  final Map<int, double> _patientReceivableSumMap = {}; // 后端合计: 应收
  final Map<int, double> _patientReceivedSumMap = {};   // 后端合计: 已收
  final Map<int, double> _patientProcessingSumMap = {}; // 后端合计: 加工费
  bool _patientServerPaged = false; // 是否使用后端已分页的患者模式

  // 显示模式相关变量
  String _displayMode = 'patient'; // 'patient' 或 'record'

  // 排序相关变量
  String _sortBy = 'updated_at'; // 可选: 'updated_at' | 'charge_date' | 'receivable' | 'received' | 'processing_fee'
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

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
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
    // 只在已初始化后才检查刷新标志
    if (!_hasInitialized) return;
    
    // 检查财务提供者中的刷新标志
    final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
    if (financialProvider.financialsNeedRefresh) {
      // 如果财务数据需要刷新，则重新加载
      _loadData();
      // 重置刷新标志
      financialProvider.resetFinancialsRefreshFlag();
    }
  }

  // 高级筛选（收费项目/金额区间）
  Future<void> _showAdvancedFilterDialog() async {
    String tempCharge = _chargeItemQuery;
    String tempRecvMin = _receivableMin?.toString() ?? '';
    String tempRecvMax = _receivableMax?.toString() ?? '';
    String tempReceivedMin = _receivedMin?.toString() ?? '';
    String tempReceivedMax = _receivedMax?.toString() ?? '';
    String tempProcMin = _processingMin?.toString() ?? '';
    String tempProcMax = _processingMax?.toString() ?? '';

    await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: 420,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    const Text('高级筛选', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: '收费项目（模糊）', prefixIcon: Icon(Icons.receipt_long)),
                  controller: TextEditingController(text: tempCharge),
                  onChanged: (v) => tempCharge = v,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: '应收费最小值', prefixIcon: Icon(Icons.attach_money)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: TextEditingController(text: tempRecvMin),
                      onChanged: (v) => tempRecvMin = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: '应收费最大值', prefixIcon: Icon(Icons.attach_money)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: TextEditingController(text: tempRecvMax),
                      onChanged: (v) => tempRecvMax = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: '已收费最小值', prefixIcon: Icon(Icons.payments)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: TextEditingController(text: tempReceivedMin),
                      onChanged: (v) => tempReceivedMin = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: '已收费最大值', prefixIcon: Icon(Icons.payments)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: TextEditingController(text: tempReceivedMax),
                      onChanged: (v) => tempReceivedMax = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: '加工费最小值', prefixIcon: Icon(Icons.build)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: TextEditingController(text: tempProcMin),
                      onChanged: (v) => tempProcMin = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: '加工费最大值', prefixIcon: Icon(Icons.build)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      controller: TextEditingController(text: tempProcMax),
                      onChanged: (v) => tempProcMax = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _chargeItemQuery = '';
                          _receivableMin = null;
                          _receivableMax = null;
                          _receivedMin = null;
                          _receivedMax = null;
                          _processingMin = null;
                          _processingMax = null;
                        });
                        Navigator.of(context).pop(true);
                        _filterFinancialData();
                      },
                      child: const Text('清空'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        double? p(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());
                        setState(() {
                          _chargeItemQuery = tempCharge.trim();
                          _receivableMin = p(tempRecvMin);
                          _receivableMax = p(tempRecvMax);
                          _receivedMin = p(tempReceivedMin);
                          _receivedMax = p(tempReceivedMax);
                          _processingMin = p(tempProcMin);
                          _processingMax = p(tempProcMax);
                        });
                        Navigator.of(context).pop(true);
                        _filterFinancialData();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: DentalColors.primary),
                      child: const Text('应用筛选'),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageJumpController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // 时间范围选择方法
  Future<void> _showCustomDateRangePicker() async {
    final now = DateTime.now();
    final DateTime initialStart = _startDate ?? DateTime(now.year, now.month, 1);
    final DateTime initialEnd = _endDate ?? now;
    final picked = await ReusableDateRangePicker.show(context, start: initialStart, end: initialEnd, title: '选择日期范围');
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterFinancialData();
    }
  }

  // 应用预设时间范围
  void _applyPreset(String preset) {
    if (preset == 'all') {
      // 清空日期筛选，显示所有数据
      if (mounted) {
        setState(() {
          _startDate = null;
          _endDate = null;
        });
        _filterFinancialData();
      }
      return;
    }
    
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);
    if (preset == 'this_month') {
      start = DateTime(now.year, now.month, 1);
    } else if (preset == 'last_month') {
      final lastMonth = DateTime(now.year, now.month - 1);
      start = DateTime(lastMonth.year, lastMonth.month, 1);
      end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
    } else if (preset == '6m') {
      start = DateTime(now.year, now.month - 5, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == '1q') {
      start = DateTime(now.year, now.month - 2, 1);
    } else if (preset == '30d') {
      start = now.subtract(const Duration(days: 29));
    } else if (preset == '90d') {
      start = now.subtract(const Duration(days: 89));
    } else if (preset == '12m') {
      start = DateTime(now.year, now.month - 11, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == 'this_year') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == 'last_year') {
      start = DateTime(now.year - 1, 1, 1);
      end = DateTime(now.year - 1, 12, 31);
    } else {
      return;
    }

    if (mounted) {
      setState(() {
        _startDate = start;
        _endDate = end;
      });
      _filterFinancialData();
    }
  }

  // 检查日期是否在范围内
  bool _isWithinRange(DateTime date) {
    if (_startDate == null && _endDate == null) {
      return true; // 如果没有设置日期范围，则认为所有日期都有效
    }
    
    final d = DateTime(date.year, date.month, date.day);
    
    // 检查开始日期
    if (_startDate != null) {
      final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      if (d.isBefore(s)) {
        return false;
      }
    }
    
    // 检查结束日期
    if (_endDate != null) {
      final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      if (d.isAfter(e)) {
        return false;
      }
    }
    
    return true;
  }



  // 内部过滤方法，不更新分页信息
  List<FinancialRecord> _filterRecordsInternal() {
    if (_searchQuery.isEmpty) {
      return _financialRecords;
    } else {
      return _financialRecords.where((record) {
        final patient = _patients.firstWhere(
          (p) => p.id == record.patientId,
          orElse: () => Patient(
            id: 0,
            name: '未知患者',
            age: 0,
            gender: '未知',
            phone: '',
            medical_record_number: 0,
            first_visit_date: DateTime.now(),
            created_at: DateTime.now(),
            updated_at: DateTime.now(),
          ),
        );
      
        final query = _searchQuery.toLowerCase();
        final nameMatch = patient.name.toLowerCase().contains(query);
        final pinyinMatch = (patient.name_pinyin != null && patient.name_pinyin!.toLowerCase().contains(query));
        final pinyinInitialMatch = (patient.name_initials != null && patient.name_initials!.toLowerCase().contains(query));
        final medicalRecordMatch = patient.medical_record_number?.toString().contains(query) ?? false;
        final notesMatch = record.notes?.toLowerCase().contains(query) ?? false;
      
        return nameMatch || pinyinMatch || pinyinInitialMatch || medicalRecordMatch || notesMatch;
      }).toList();
    }
  }

  // 获取分页后的财务数据（包含患者信息）
  List<Map<String, dynamic>> _getPagedFinancialData() {
    final List<Map<String, dynamic>> result = [];
    
    for (final record in _displayedRecords) {
      final patient = _getPatientById(record.patientId);
      if (patient != null) {
        result.add({
          'patient': patient,
          'record': record,
          'totalCost': _getPatientTotalReceivable(record.patientId),
          'lastVisitDate': _getPatientLastVisitDate(record.patientId),
        });
      }
    }
    
    return result;
  }

  // 获取分页后的数据（根据显示模式）
  List<Map<String, dynamic>> _getPagedData() {
    // 如果是患者模式且已使用后端分页，则不再做二次分页，直接将当前页代表记录映射为UI数据
    if (_displayMode == 'patient' && _patientServerPaged) {
      final List<Map<String, dynamic>> result = [];
      for (final record in _financialRecords) {
        final patient = _getPatientById(record.patientId);
        if (patient == null) continue;
        final pid = record.patientId;
        result.add({
          'patient': patient,
          'record': record,
          'totalCost': _patientReceivableSumMap[pid] ?? 0.0,
          'receivedSum': _patientReceivedSumMap[pid] ?? 0.0,
          'processingSum': _patientProcessingSumMap[pid] ?? 0.0,
          // 最近更新：使用后端聚合提供的 financial_items.updated_at 最大值
          'lastVisitDate': _patientLastUpdatedMap[pid],
        });
      }
      return result;
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
      final List<Map<String, dynamic>> result = [];
      for (final data in pagedData) {
        final patient = data['patient'] as Patient;
        final record = data['record'] as FinancialRecord;
        result.add({
          'patient': patient,
          'record': record,
          'totalCost': _getPatientTotalReceivable(record.patientId),
          'lastVisitDate': _getPatientLastVisitDate(record.patientId),
        });
      }
      return result;
    }

    // 记录模式
    return pagedData;
  }

  // 跳转到指定页面
  void _goToPage(int page) {
    print('🔄 _goToPage 调试: 尝试跳转到第 $page 页');
    print('📑 总页数: $_totalPages');
    print('📍 当前页码: $_currentPage');
    
    if (page >= 1 && page <= _totalPages) {
      print('✅ 页码有效，执行跳转');
      
      // 检查缓存
      if (_pageCache.containsKey(page) && _displayMode == 'patient') {
        print('💾 使用缓存数据，页码: $page');
        _loadFromCache(page);
        return;
      }
      
      print('🔄 缓存未命中，从后端加载数据');
      setState(() {
        _currentPage = page;
      });
      _loadData(); // 重新从后端加载数据
    } else {
      print('❌ 页码无效，不执行跳转');
    }
  }

  // 从缓存加载数据
  Future<void> _loadFromCache(int page) async {
    final rows = _pageCache[page]!;
    final pagePatientIds = rows.map<int>((r) => r['patient_id'] as int).toList();
    
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    final String patientsDataSource = settingsProvider.dataSourceMode == 'modular'
        ? (settingsProvider.moduleDataSources['patients'] ?? settingsProvider.dataSourceType)
        : settingsProvider.dataSourceType;
    
    // 预加载患者信息
    final fetchedPatients = await patientProvider.getPatientsByIds(
      pagePatientIds,
      effectiveDataSourceType: patientsDataSource,
    );
    final patients = fetchedPatients
        .map((p) => p.copyWith(
              name_pinyin: PinyinUtil.toPinyin(p.name),
              name_initials: PinyinUtil.getInitials(p.name),
            ))
        .toList();
    
    // 构建代表记录
    final repRecords = <FinancialRecord>[];
    for (final row in rows) {
      final pid = row['patient_id'] as int;
      final latestChargeDate = row['latest_charge_date'] != null
          ? DateTime.parse(row['latest_charge_date'] as String)
          : DateTime.now();
      final lastUpdated = row['last_updated'] != null
          ? DateTime.parse(row['last_updated'] as String)
          : DateTime.now();
      
      _patientLatestChargeDateMap[pid] = latestChargeDate;
      _patientLastUpdatedMap[pid] = lastUpdated;
      _patientReceivableSumMap[pid] = (row['receivable_sum'] as num?)?.toDouble() ?? 0.0;
      _patientReceivedSumMap[pid] = (row['received_sum'] as num?)?.toDouble() ?? 0.0;
      _patientProcessingSumMap[pid] = (row['processing_sum'] as num?)?.toDouble() ?? 0.0;
      
      repRecords.add(FinancialRecord(
        id: pid,
        patientId: pid,
        totalQuantity: 0,
        notes: null,
        createdAt: lastUpdated,
        updatedAt: lastUpdated,
      ));
    }
    
    if (mounted) {
      setState(() {
        _currentPage = page;
        _financialRecords = repRecords;
        _patients = patients;
      });
    }
  }

  // 跳转到上一页
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _goToPage(_currentPage - 1);
    }
  }

  // 跳转到下一页
  void _goToNextPage() {
    print('🔄 _goToNextPage 调试: 当前页 $_currentPage, 总页数 $_totalPages');
    
    if (_currentPage < _totalPages) {
      _goToPage(_currentPage + 1);
    } else {
      print('⚠️ 已经是最后一页，无法继续下一页');
    }
  }

  // 加载数据
  Future<void> _loadData() async {
    if (!mounted) return;
    
    print('🔄 开始加载数据: 显示模式=$_displayMode, 当前页=$_currentPage');
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      // 依据设置确定“患者管理”实际使用的数据源
      final String patientsDataSource = settingsProvider.dataSourceMode == 'modular'
          ? (settingsProvider.moduleDataSources['patients'] ?? settingsProvider.dataSourceType)
          : settingsProvider.dataSourceType;

      // 若有搜索词，先在SQLite中查患者ID；否则不限制
      List<int>? filterPatientIds;
      if (_searchQuery.isNotEmpty) {
        try {
          filterPatientIds = await patientProvider.searchPatientIds(
            _searchQuery,
            effectiveDataSourceType: patientsDataSource,
          );
        } catch (e) {
          print('搜索患者ID失败: $e');
          filterPatientIds = [];
        }
      }

      if (!mounted) return;
      
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
        final List rows = (agg['rows'] as List? ?? const []);
        final pagePatientIds = rows.map<int>((r) => r['patient_id'] as int).toList();

        // 预加载患者信息
        final fetchedPatients = await patientProvider.getPatientsByIds(
          pagePatientIds,
          effectiveDataSourceType: patientsDataSource,
        );
        final patients = fetchedPatients
            .map((p) => p.copyWith(
                  name_pinyin: PinyinUtil.toPinyin(p.name),
                  name_initials: PinyinUtil.getInitials(p.name),
                ))
            .toList();

        // 代表记录：各患者最近更新的一条记录（用于跳转/显示）
        final List<FinancialRecord> repRecords = [];
        for (final pid in pagePatientIds) {
          final rec = await financialProvider.getLatestRecordForPatient(pid);
          if (rec != null) repRecords.add(rec);
        }

        // 覆盖患者级日期映射，供 _getFinancialData 使用
        _patientLatestChargeDateMap
          ..clear()
          ..addEntries(rows.map<MapEntry<int, DateTime>>((r) {
            final pid = r['patient_id'] as int;
            final s = (r['latest_charge_date']?.toString() ?? '');
            final dt = s.isNotEmpty ? DateTime.tryParse(s) : null;
            return MapEntry(pid, dt ?? DateTime.now());
          }));
        _patientLastUpdatedMap
          ..clear()
          ..addEntries(rows.map<MapEntry<int, DateTime>>((r) {
            final pid = r['patient_id'] as int;
            final s = (r['last_updated']?.toString() ?? '');
            final dt = s.isNotEmpty ? DateTime.tryParse(s) : null;
            return MapEntry(pid, dt ?? DateTime.now());
          }));
        _patientReceivableSumMap
          ..clear()
          ..addEntries(rows.map<MapEntry<int, double>>((r) => MapEntry(r['patient_id'] as int, (r['receivable_sum'] as num?)?.toDouble() ?? 0.0)));
        _patientReceivedSumMap
          ..clear()
          ..addEntries(rows.map<MapEntry<int, double>>((r) => MapEntry(r['patient_id'] as int, (r['received_sum'] as num?)?.toDouble() ?? 0.0)));
        _patientProcessingSumMap
          ..clear()
          ..addEntries(rows.map<MapEntry<int, double>>((r) => MapEntry(r['patient_id'] as int, (r['processing_sum'] as num?)?.toDouble() ?? 0.0)));

        if (!mounted) return;
        setState(() {
          _financialRecords = repRecords; // 仅一页代表记录
          _patients = patients;
          _recordItemsMap = {}; // 不再逐条加载明细
          _financialItemsWithDetails = [];
          _totalRecords = total;
          _totalPages = (_totalRecords / _recordsPerPage).ceil();
          _isLoading = false;
          _patientCache.clear();
          _patientServerPaged = true;
          
          // 缓存当前页数据
          _pageCache[_currentPage] = rows.cast<Map<String, dynamic>>();
        });
      } else {
        // 按收费记录显示模式：按 financial_items 分页
        final results = await Future.wait([
          financialProvider.getFinancialItemsCount(
            startDate: _startDate,
            endDate: _endDate,
            patientIds: filterPatientIds,
            chargeItemQuery: _chargeItemQuery.isNotEmpty ? _chargeItemQuery : null,
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
            chargeItemQuery: _chargeItemQuery.isNotEmpty ? _chargeItemQuery : null,
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
        
        print('✅ 按收费记录显示模式加载完成: 收费项数=${itemsWithDetails.length}, 总记录数=$totalRecords');
        
        // 提取当前页患者ID并在SQLite中批量查询
        final pagePatientIds = itemsWithDetails
            .map((data) => data['patient_id'] as int)
            .toSet()
            .toList();
        print('📋 需要查询的患者ID: $pagePatientIds');
        final fetchedPatients = await patientProvider.getPatientsByIds(
          pagePatientIds,
          effectiveDataSourceType: patientsDataSource,
        );
        final patients = fetchedPatients
            .map((p) => p.copyWith(
                  name_pinyin: PinyinUtil.toPinyin(p.name),
                  name_initials: PinyinUtil.getInitials(p.name),
                ))
            .toList();
        
        print('✅ 查询到 ${patients.length} 个患者信息');
        
        setState(() {
          _financialRecords = [];
          _recordItemsMap = {};
          _financialItemsWithDetails = itemsWithDetails;
          _patients = patients;
          _totalRecords = totalRecords;
          _totalPages = (_totalRecords / _recordsPerPage).ceil();
          _isLoading = false;
          
          // 清空缓存，因为患者列表已更新
          _patientCache.clear();
          
          // 首次加载时不设置日期范围，显示所有数据
          // 用户可以手动选择日期范围进行过滤
        });
      }
      
    } catch (e) {
      print('❌ 加载数据失败: $e');
      print('Stack trace: ${StackTrace.current}');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '加载数据时出错: $e';
      });
    }
  }

  // 患者缓存
  final Map<int, Patient?> _patientCache = {};

  // 获取患者信息（带缓存）
  Future<Patient?> _getPatientByIdAsync(int patientId) async {
    // 先从缓存中查找
    if (_patientCache.containsKey(patientId)) {
      return _patientCache[patientId];
    }
    
    // 从预加载的列表中查找
    try {
      final patient = _patients.firstWhere((p) => p.id == patientId);
      _patientCache[patientId] = patient;
      return patient;
    } catch (e) {
      // 如果预加载列表中没有，重新加载所有患者
      try {
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        final allPatients = await patientProvider.getAllPatients();
        
        // 查找目标患者
        try {
          final patient = allPatients.firstWhere((p) => p.id == patientId);
          final patientWithPinyin = patient.copyWith(
            name_pinyin: PinyinUtil.toPinyin(patient.name),
            name_initials: PinyinUtil.getInitials(patient.name),
          );
          
          // 更新患者列表和缓存
          if (!_patients.any((p) => p.id == patientId)) {
            _patients.add(patientWithPinyin);
          }
          _patientCache[patientId] = patientWithPinyin;
          
          print('✅ 从数据库查询到患者: ${patientWithPinyin.name} (ID=$patientId)');
          return patientWithPinyin;
        } catch (e) {
          print('❌ 患者不存在 ID=$patientId');
          _patientCache[patientId] = null;
          return null;
        }
      } catch (e) {
        print('❌ 查询患者失败 ID=$patientId: $e');
        _patientCache[patientId] = null;
        return null;
      }
    }
  }
  
  // 同步获取患者信息（仅用于已缓存的情况）
  Patient? _getPatientById(int patientId) {
    try {
      return _patients.firstWhere((patient) => patient.id == patientId);
    } catch (e) {
      return null;
    }
  }

  // 获取患者的应收费总额
  double _getPatientTotalReceivable(int patientId) {
    try {
      double totalReceivable = 0.0;
      for (final record in _financialRecords.where((record) => record.patientId == patientId)) {
        final items = _recordItemsMap[record.id] ?? [];
        totalReceivable += items.fold(0.0, (sum, item) => sum + (item.itemPrice * (item.quantity ?? 1)));
      }
      return totalReceivable;
    } catch (e) {
      return 0.0;
    }
  }

  // 获取患者的最近更新日期（最近财务记录的update_time）
  DateTime? _getPatientLastVisitDate(int patientId) {
    try {
      final records = _financialRecords
          .where((record) => record.patientId == patientId)
          .toList();
      if (records.isEmpty) return null;
      
      // 按更新时间排序，找到最近的财务记录
      records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // 返回最近财务记录的更新时间
      return records.first.updatedAt;
    } catch (e) {
      return null;
    }
  }

  // 过滤后的财务数据（支持时间范围筛选和搜索）
  List<Map<String, dynamic>> get _filteredFinancialData {
    final List<Map<String, dynamic>> sourceData;
    
    if (_displayMode == 'patient') {
      sourceData = _getFinancialData();
    } else {
      sourceData = _getAllFinancialItemsData();
    }
    
    // 先进行时间范围筛选
    List<Map<String, dynamic>> timeFilteredData = sourceData.where((data) {
      final record = data['record'] as FinancialRecord;
      final item = data['item'] as FinancialItem?;
      
      // 使用不同维度的日期作为过滤基准：
      // - 记录模式：用收费明细的 charge_date（没有明细时回退到记录 created_at）。
      // - 患者模式：用聚合后的 patientLatestChargeDate。
      DateTime dateToCheck;
      if (_displayMode == 'patient') {
        dateToCheck = (data['patientLatestChargeDate'] as DateTime?) ?? record.createdAt;
      } else if (item != null) {
        dateToCheck = item.chargeDate;
      } else {
        dateToCheck = record.createdAt;
      }
      
      return _isWithinRange(dateToCheck);
    }).toList();
    
    // 在搜索之前进行排序
    timeFilteredData.sort((a, b) {
      final recordA = a['record'] as FinancialRecord;
      final recordB = b['record'] as FinancialRecord;
      final itemA = a['item'] as FinancialItem?;
      final itemB = b['item'] as FinancialItem?;

      // 根据显示模式和排序字段决定比较值
      int compareNum(num va, num vb) => _sortAscending ? va.compareTo(vb) : vb.compareTo(va);
      int compareDate(DateTime da, DateTime db) => _sortAscending ? da.compareTo(db) : db.compareTo(da);

      // 患者模式：按患者聚合后的日期排序（已在 _getFinancialData() 中计算）
      if (_displayMode == 'patient') {
        final pa = a['patientLastUpdated'] as DateTime? ?? recordA.updatedAt;
        final pb = b['patientLastUpdated'] as DateTime? ?? recordB.updatedAt;
        if (_sortBy == 'charge_date') {
          final ca = a['patientLatestChargeDate'] as DateTime? ?? recordA.createdAt;
          final cb = b['patientLatestChargeDate'] as DateTime? ?? recordB.createdAt;
          return compareDate(ca, cb);
        }
        return compareDate(pa, pb);
      }

      // 记录模式：金额与日期皆可排序
      if (_sortBy == 'updated_at') {
        return compareDate(recordA.updatedAt, recordB.updatedAt);
      }
      if (_sortBy == 'charge_date') {
        final da = itemA?.chargeDate ?? recordA.createdAt;
        final db = itemB?.chargeDate ?? recordB.createdAt;
        return compareDate(da, db);
      }

      if (_displayMode == 'record') {
        final receivableA = itemA?.itemPrice ?? 0.0;
        final receivableB = itemB?.itemPrice ?? 0.0;
        final receivedA = itemA?.totalPrice ?? 0.0;
        final receivedB = itemB?.totalPrice ?? 0.0;
        final procA = itemA?.processingFee ?? 0.0;
        final procB = itemB?.processingFee ?? 0.0;

        switch (_sortBy) {
          case 'receivable':
            return compareNum(receivableA, receivableB);
          case 'received':
            return compareNum(receivedA, receivedB);
          case 'processing_fee':
            return compareNum(procA, procB);
        }
      } else {
        // 兜底（患者模式不会走到这里）
      }

      // 兜底：按更新时间
      return compareDate(recordA.updatedAt, recordB.updatedAt);
    });

    // 再进行搜索筛选
    if (_searchQuery.isEmpty) {
      return timeFilteredData;
    }

    final query = _searchQuery.toLowerCase();
    return timeFilteredData.where((data) {
      final patient = data['patient'] as Patient;
      final record = data['record'] as FinancialRecord;
      final item = data['item'] as FinancialItem?;
      
      final nameMatch = patient.name.toLowerCase().contains(query);
      final pinyinMatch = patient.name_pinyin?.toLowerCase().contains(query) ?? false;
      final pinyinInitialMatch = patient.name_initials?.toLowerCase().contains(query) ?? false;
      final medicalRecordMatch = patient.medical_record_number?.toString().contains(query) ?? false;
      final notesMatch = record.notes?.toLowerCase().contains(query) ?? false;
      
      // 如果是按收费记录显示模式，还要搜索收费项目名称
      bool itemNameMatch = false;
      if (item != null) {
        itemNameMatch = item.itemName.toLowerCase().contains(query);
      }

      return nameMatch || pinyinMatch || pinyinInitialMatch || medicalRecordMatch || notesMatch || itemNameMatch;
    }).toList();
  }

  // 获取财务数据（按患者去重，基于患者的“最新收费日期/最近更新”排序）
  List<Map<String, dynamic>> _getFinancialData() {
    // 聚合：key 为 patientId
    final Map<int, Map<String, dynamic>> agg = {};

    for (final record in _financialRecords) {
      final pid = record.patientId;
      final patient = _getPatientById(pid);
      if (patient == null) continue;

      // Route B：若后端已提供聚合日期，则直接使用；否则退回到记录/明细推算
      DateTime? patientLatestChargeFromAgg = _patientLatestChargeDateMap[pid];
      DateTime? patientLastUpdatedFromAgg = _patientLastUpdatedMap[pid];

      // 该记录自身的最新收费日期（若无明细则用记录创建时间）
      final items = _recordItemsMap[record.id] ?? [];
      final recordLatestCharge = items.isNotEmpty
          ? items.map((i) => i.chargeDate).reduce((a, b) => a.isAfter(b) ? a : b)
          : record.createdAt;

      if (!agg.containsKey(pid)) {
        agg[pid] = {
          'patient': patient,
          // 代表记录：先用当前记录，后续遇到“更新更晚”的记录替换
          'record': record,
          'patientLatestChargeDate': patientLatestChargeFromAgg ?? recordLatestCharge, // 优先用后端聚合
          'patientLastUpdated': patientLastUpdatedFromAgg ?? record.updatedAt,        // 优先用后端聚合
        };
      } else {
        final m = agg[pid]!;
        // 维护患者维度的最新收费日期（所有收费明细的最大 charge_date）
        final prevCharge = m['patientLatestChargeDate'] as DateTime;
        final candidateCharge = patientLatestChargeFromAgg ?? recordLatestCharge;
        if (candidateCharge.isAfter(prevCharge)) {
          m['patientLatestChargeDate'] = candidateCharge;
        }
        // 维护患者维度的最近更新时间（所有记录 updated_at 的最大值）
        final prevUpdated = m['patientLastUpdated'] as DateTime;
        final candidateUpdated = patientLastUpdatedFromAgg ?? record.updatedAt;
        if (candidateUpdated.isAfter(prevUpdated)) {
          m['patientLastUpdated'] = candidateUpdated;
          // 同时更新代表性记录为最近更新的这条
          m['record'] = record;
        }
      }
    }

    // 聚合后转列表并排序
    final List<Map<String, dynamic>> list = agg.values.toList();
    list.sort((a, b) {
      int compareDate(DateTime da, DateTime db) => _sortAscending ? da.compareTo(db) : db.compareTo(da);
      if (_sortBy == 'charge_date') {
        final da = a['patientLatestChargeDate'] as DateTime;
        final db = b['patientLatestChargeDate'] as DateTime;
        return compareDate(da, db);
      }
      final da = a['patientLastUpdated'] as DateTime;
      final db = b['patientLastUpdated'] as DateTime;
      return compareDate(da, db);
    });

    // 输出格式与调用方预期保持一致
    return list.map((m) {
      final patient = m['patient'] as Patient;
      final record = m['record'] as FinancialRecord;
      return {
        'patient': patient,
        'record': record,
        'totalCost': _getPatientTotalReceivable(record.patientId),
        'lastVisitDate': _getPatientLastVisitDate(record.patientId),
        // 暴露患者级最新日期，供后续排序使用
        'patientLatestChargeDate': m['patientLatestChargeDate'] as DateTime,
        'patientLastUpdated': m['patientLastUpdated'] as DateTime,
      };
    }).toList();
  }

  // 获取所有收费记录明细项数据（用于按收费记录显示）
  List<Map<String, dynamic>> _getAllFinancialItemsData() {
    final List<Map<String, dynamic>> result = [];
    
    for (final record in _financialRecords) {
      final patient = _getPatientById(record.patientId);
      if (patient != null) {
        final items = _recordItemsMap[record.id] ?? [];
        for (final item in items) {
          result.add({
            'patient': patient,
            'record': record,
            'item': item,
          });
        }
      }
    }
    
    // 按收费日期降序排序
    result.sort((a, b) {
      final itemA = a['item'] as FinancialItem;
      final itemB = b['item'] as FinancialItem;
      return itemB.chargeDate.compareTo(itemA.chargeDate);
    });
    
    return result;
  }

  // 过滤财务数据（触发UI更新）
  void _filterFinancialData() {
    setState(() {
      _currentPage = 1; // 重置到第一页
      _pageCache.clear(); // 清除缓存
    });
    _loadData(); // 重新从后端加载数据
  }

  // 更新显示记录（分页逻辑）
  void _updateDisplayedRecords() {
    final filteredRecords = _filterRecordsInternal();
    final startIndex = (_currentPage - 1) * _recordsPerPage;
    final endIndex = startIndex + _recordsPerPage;
    
    setState(() {
      _displayedRecords = filteredRecords.sublist(
        startIndex.clamp(0, filteredRecords.length),
        endIndex.clamp(0, filteredRecords.length),
      );
    });
  }

  // 更新显示数据（分页逻辑）
  void _updateDisplayedData() {
    // 使用过滤后的数据进行分页显示
    final filteredData = _filteredFinancialData;
    final startIndex = (_currentPage - 1) * _recordsPerPage;
    final endIndex = startIndex + _recordsPerPage;
    
    print('🔄 _updateDisplayedData 调试: 开始更新显示数据');
    print('📊 过滤后数据长度: ${filteredData.length}');
    print('📍 当前页码: $_currentPage');
    print('📊 开始索引: $startIndex, 结束索引: $endIndex');
    
    // 计算过滤后的数据页数
    final filteredPages = (filteredData.length / _recordsPerPage).ceil();
    print('📑 过滤后总页数: $filteredPages');
    
    // 如果当前页码大于过滤后的页数，调整到最后一页
    if (_currentPage > filteredPages && filteredPages > 0) {
      print('⚠️ 当前页码超出范围，调整到最后一页: $filteredPages');
      _currentPage = filteredPages;
    } else if (filteredPages == 0) {
      print('⚠️ 没有数据，调整到第一页');
      _currentPage = 1;
    }
    
    setState(() {
      // 从Map中提取FinancialRecord对象
      final List<FinancialRecord> records = filteredData
          .sublist(
            startIndex.clamp(0, filteredData.length),
            endIndex.clamp(0, filteredData.length),
          )
          .map((data) => data['record'] as FinancialRecord)
          .toList();
      
      _displayedRecords = records;
      print('✅ 显示记录已更新，数量: ${records.length}');
    });
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
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
        actions: [
          // 显示模式切换按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _displayMode == 'patient' 
                  ? DentalColors.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _displayMode == 'patient' 
                    ? DentalColors.primary.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.people_rounded,
                color: _displayMode == 'patient' ? DentalColors.primary : Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _displayMode = 'patient';
                  _currentPage = 1;
                  // 患者模式允许的排序字段：最近更新/收费日期/应收费/已收费/欠费
                  const allowed = ['updated_at', 'charge_date', 'receivable', 'received', 'debt'];
                  if (!allowed.contains(_sortBy)) {
                    _sortBy = 'updated_at';
                    _sortAscending = false;
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
                  ? DentalColors.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _displayMode == 'record' 
                    ? DentalColors.primary.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.list_alt_rounded,
                color: _displayMode == 'record' ? DentalColors.primary : Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _displayMode = 'record';
                  _currentPage = 1;
                  // 切回记录模式无需限制（保留当前排序），如需可默认最近更新
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
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () async {
                final result = await _showFinancialRecordDialog();
                if (result == true) {
                  await _loadData();
                }
              },
              tooltip: '添加收费记录',
            ),
          ),
          // 收费图表统计按钮
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: DentalColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.success.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.bar_chart_rounded,
                color: DentalColors.success,
              ),
              onPressed: _showFinancialStatistics,
              tooltip: '收费图表统计',
            ),
          ),
          // 刷新按钮（移到最右侧）
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () async {
                await _loadData();
                if (!mounted) return;
                SuccessToastManager.show(context, message: '刷新数据成功');
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
                    _loadData();
                    financialProvider.resetFinancialsRefreshFlag();
                  }
                });
              }
              
              return Column(
                children: [
                  // MySQL连接失败警告（如果有）
                  if (!appState.isMySQLConnected)
                    const MySQLConnectionWarning(moduleName: '财务管理'),
                  
                  // 搜索栏 + 工具条（紧凑白底圆角容器）
                  Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  child: Row(
                    children: [
                    // 搜索框（Expanded）
                    Expanded(
                      child: UnifiedSearchField(
                        controller: _searchController,
                        labelText: _displayMode == 'patient' ? '搜索患者' : '搜索收费记录',
                        hintText: _displayMode == 'patient' ? '搜索姓名、病历号' : '搜索姓名、病历号',
                        prefixIcon: Icons.search_rounded,
                        searchQuery: _searchQuery,
                        onChanged: (value) {
                          setState(() { _searchQuery = value; });
                          _currentPage = 1;
                          _loadData();
                        },
                        onClear: () {
                          setState(() { _searchQuery = ''; });
                          _currentPage = 1;
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 排序切换按钮（使用清晰的排序图标）
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort_rounded, color: Colors.black87),
                      onSelected: (String value) {
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
                      itemBuilder: (BuildContext context) {
                        if (_displayMode == 'patient') {
                          return <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'updated_at',
                              child: ListTile(
                                leading: Icon(Icons.update, color: _sortBy == 'updated_at' ? Theme.of(context).primaryColor : null),
                                title: Text('按最近更新'),
                                trailing: _sortBy == 'updated_at' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'charge_date',
                              child: ListTile(
                                leading: Icon(Icons.calendar_today, color: _sortBy == 'charge_date' ? Theme.of(context).primaryColor : null),
                                title: Text('按收费日期'),
                                trailing: _sortBy == 'charge_date' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'receivable',
                              child: ListTile(
                                leading: Icon(Icons.request_quote, color: _sortBy == 'receivable' ? Theme.of(context).primaryColor : null),
                                title: Text('按应收费'),
                                trailing: _sortBy == 'receivable' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'received',
                              child: ListTile(
                                leading: Icon(Icons.payments, color: _sortBy == 'received' ? Theme.of(context).primaryColor : null),
                                title: Text('按已收费'),
                                trailing: _sortBy == 'received' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'debt',
                              child: ListTile(
                                leading: Icon(Icons.pending, color: _sortBy == 'debt' ? Theme.of(context).primaryColor : null),
                                title: Text('按欠费'),
                                trailing: _sortBy == 'debt' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                          ];
                        } else {
                          return <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'updated_at',
                              child: ListTile(
                                leading: Icon(Icons.update, color: _sortBy == 'updated_at' ? Theme.of(context).primaryColor : null),
                                title: Text('按最近更新'),
                                trailing: _sortBy == 'updated_at' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'charge_date',
                              child: ListTile(
                                leading: Icon(Icons.calendar_today, color: _sortBy == 'charge_date' ? Theme.of(context).primaryColor : null),
                                title: Text('按收费日期'),
                                trailing: _sortBy == 'charge_date' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'receivable',
                              child: ListTile(
                                leading: Icon(Icons.request_quote, color: _sortBy == 'receivable' ? Theme.of(context).primaryColor : null),
                                title: Text('按应收费'),
                                trailing: _sortBy == 'receivable' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'received',
                              child: ListTile(
                                leading: Icon(Icons.payments, color: _sortBy == 'received' ? Theme.of(context).primaryColor : null),
                                title: Text('按已收费'),
                                trailing: _sortBy == 'received' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'processing_fee',
                              child: ListTile(
                                leading: Icon(Icons.build, color: _sortBy == 'processing_fee' ? Theme.of(context).primaryColor : null),
                                title: Text('按加工费'),
                                trailing: _sortBy == 'processing_fee' ? Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward) : null,
                              ),
                            ),
                          ];
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    // 时间范围选择按钮（预约风格：全部时间 + 可清除X）
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: SizedBox(
                        height: 44,
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async { await _showCustomDateRangePicker(); },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 120, maxWidth: 280),
                                    child: Text(
                                      (_startDate == null && _endDate == null)
                                          ? '全部时间'
                                          : '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                                      style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_startDate != null || _endDate != null) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setState(() { _startDate = null; _endDate = null; });
                                        _filterFinancialData();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.black45),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 高级筛选按钮（仅在按收费记录显示模式下显示）
                    if (_displayMode == 'record')
                      SizedBox(
                        height: 44,
                        width: 44,
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                          ),
                          elevation: 0.5,
                          child: IconButton(
                            icon: Icon(Icons.tune, color: (_chargeItemQuery.isNotEmpty || _receivableMin != null || _receivableMax != null || _processingMin != null || _processingMax != null) ? DentalColors.primary : Colors.grey[700]),
                            tooltip: '高级筛选',
                            onPressed: _showAdvancedFilterDialog,
                          ),
                        ),
                      ),
                  ],
                  ),
                ),
              ),
              // 内容区域
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _totalRecords == 0
                            ? Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_searchQuery.isEmpty ? Icons.account_balance_wallet_outlined : Icons.search_off, size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      Text(_searchQuery.isEmpty ? '暂无财务记录' : '未找到匹配的记录', style: Theme.of(context).textTheme.headlineSmall),
                                      const SizedBox(height: 8),
                                      Container(
                                        constraints: const BoxConstraints(maxWidth: 400),
                                        child: Text(
                                          _searchQuery.isEmpty ? '点击右上角按钮添加第一条财务记录' : '请尝试其他搜索关键词',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (_searchQuery.isEmpty) ...[
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final result = await _showFinancialRecordDialog();
                                            if (result == true) await _loadData();
                                          },
                                          child: const Text('添加收费记录'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
  Widget _buildStatsSection() {
    final totalRecords = _financialRecords.length;
    final totalPatients = _patients.length;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.receipt_long,
                  label: '总记录数',
                  value: totalRecords.toString(),
                  color: Colors.blue[700]!,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.people,
                  label: '涉及患者',
                  value: totalPatients.toString(),
                  color: Colors.green[700]!,
                ),
              ),
            ],
          ),
        ),
        
        // 分页信息显示
        if (_totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pages_rounded,
                  color: Colors.blue[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '第 $_currentPage 页，共 $_totalPages 页',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '每页显示 $_recordsPerPage 条记录',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 构建统计项组件
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 构建记录列表
  // 滚动控制器
  final ScrollController _horizontalScrollController = ScrollController();

  Widget _buildRecordsList() {
    return Column(
      children: [
        // 记录列表
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 计算所需的最小宽度
              const minTableWidth = 1200.0;
              final availableWidth = constraints.maxWidth;
              final needsScroll = availableWidth < minTableWidth;
              
              if (_displayMode == 'patient') {
                // 患者模式：不需要横向滚动
                return Column(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final pagedData = _getPagedData();
                          print('📋 渲染按患者显示列表(分页后): ${pagedData.length} 条, 当前页=$_currentPage/$_totalPages');
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: pagedData.length,
                            itemBuilder: (context, index) {
                              final data = pagedData[index];
                              final patient = data['patient'] as Patient;
                              final record = data['record'] as FinancialRecord;
                              final totalCost = data['totalCost'] as double? ?? _getPatientTotalReceivable(record.patientId);
                              final receivedSum = data['receivedSum'] as double?;
                              final processingSum = data['processingSum'] as double?;
                              final lastVisitDate = data['lastVisitDate'] as DateTime? ?? _getPatientLastVisitDate(record.patientId);
                              return _buildFinancialCard(
                                patient,
                                record,
                                totalCost,
                                lastVisitDate,
                                receivedSum: receivedSum,
                                processingSum: processingSum,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              
              // 记录模式：需要横向滚动
              if (needsScroll) {
                return Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: minTableWidth,
                      child: Column(
                        children: [
                          // 表头
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildTableHeader(),
                          ),
                          const SizedBox(height: 8),
                          
                          // 记录列表
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                print('📋 渲染按收费记录显示列表: ${_financialItemsWithDetails.length} 条记录');
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _financialItemsWithDetails.length,
                                  itemBuilder: (context, index) {
                                    final data = _financialItemsWithDetails[index];
                                    final item = data['item'] as FinancialItem;
                                    final patientId = data['patient_id'] as int;
                                    
                                    return FutureBuilder<Patient?>(
                                      future: _getPatientByIdAsync(patientId),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                        }
                                        
                                        final patient = snapshot.data;
                                        if (patient == null) {
                                          print('⚠️ 收费项 $index: 找不到患者');
                                          print('   患者ID: $patientId');
                                          print('   收费项ID: ${item.id}');
                                          return const SizedBox.shrink();
                                        }
                                        
                                        // 创建一个临时的 FinancialRecord 对象用于显示
                                        final record = FinancialRecord(
                                          id: item.financialRecordId,
                                          patientId: patientId,
                                          totalQuantity: 0,
                                          notes: data['record_notes'] as String?,
                                          createdAt: item.createdAt,
                                          updatedAt: item.updatedAt,
                                        );
                                        
                                        return _buildFinancialItemCard(patient, record, item);
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              // 不需要滚动
              return Column(
                children: [
                  // 表头
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTableHeader(),
                  ),
                  const SizedBox(height: 8),
                  
                  // 记录列表
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        print('📋 渲染按收费记录显示列表: ${_financialItemsWithDetails.length} 条记录');
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _financialItemsWithDetails.length,
                          itemBuilder: (context, index) {
                            final data = _financialItemsWithDetails[index];
                            final item = data['item'] as FinancialItem;
                            final patientId = data['patient_id'] as int;
                            
                            return FutureBuilder<Patient?>(
                              future: _getPatientByIdAsync(patientId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                
                                final patient = snapshot.data;
                                if (patient == null) {
                                  print('⚠️ 收费项 $index: 找不到患者');
                                  print('   患者ID: $patientId');
                                  print('   收费项ID: ${item.id}');
                                  return const SizedBox.shrink();
                                }
                                
                                // 创建一个临时的 FinancialRecord 对象用于显示
                                final record = FinancialRecord(
                                  id: item.financialRecordId,
                                  patientId: patientId,
                                  totalQuantity: 0,
                                  notes: data['record_notes'] as String?,
                                  createdAt: item.createdAt,
                                  updatedAt: item.updatedAt,
                                );
                                
                                return _buildFinancialItemCard(patient, record, item);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        
        // 分页控件（只要有数据就显示）
        if (_totalRecords > 0)
          _buildPagination(),
      ],
    );
  }

  // 构建表头
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.indigo[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 记录ID列
          SizedBox(
            width: 70,
            child: _buildHeaderCell(
              icon: Icons.tag,
              label: 'ID',
              color: Colors.purple[600]!,
              alignment: MainAxisAlignment.center,
            ),
          ),
          const SizedBox(width: 12),
          // 病历号列
          SizedBox(
            width: 90,
            child: _buildHeaderCell(
              icon: Icons.badge,
              label: '病历号',
              color: Colors.orange[600]!,
              alignment: MainAxisAlignment.center,
            ),
          ),
          const SizedBox(width: 12),
          // 患者姓名列
          Expanded(
            flex: 2,
            child: _buildHeaderCell(
              icon: Icons.person,
              label: '患者姓名',
              color: Colors.blue[700]!,
              alignment: MainAxisAlignment.center,
            ),
          ),
          const SizedBox(width: 12),
          // 收费日期列
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[200]!, width: 1),
              ),
              child: _buildHeaderCell(
                icon: Icons.calendar_today,
                label: '收费日期',
                color: Colors.teal[600]!,
                alignment: MainAxisAlignment.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 最近更新列
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo[200]!, width: 1),
              ),
              child: _buildHeaderCell(
                icon: Icons.update,
                label: '最近更新',
                color: Colors.indigo[600]!,
                alignment: MainAxisAlignment.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 收费项目列
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!, width: 1),
              ),
              child: _buildHeaderCell(
                icon: Icons.medical_services,
                label: '收费项目',
                color: Colors.green[700]!,
                alignment: MainAxisAlignment.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 应收费列
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: _buildHeaderCell(
                  icon: Icons.request_quote,
                  label: '应收费',
                  color: Colors.blue[700]!,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 已收费列
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!, width: 1),
                ),
                child: _buildHeaderCell(
                  icon: Icons.payments,
                  label: '已收费',
                  color: Colors.green[700]!,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 加工费列
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!, width: 1),
                ),
                child: _buildHeaderCell(
                  icon: Icons.build,
                  label: '加工费',
                  color: Colors.orange[700]!,
                  alignment: MainAxisAlignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 操作列
          SizedBox(
            width: 100,
            child: _buildHeaderCell(
              icon: Icons.settings,
              label: '操作',
              color: Colors.grey[700]!,
              alignment: MainAxisAlignment.center,
            ),
          ),
        ],
      ),
    );
  }

  // 构建表头单元格
  Widget _buildHeaderCell({
    required IconData icon,
    required String label,
    required Color color,
    MainAxisAlignment alignment = MainAxisAlignment.start,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // 过滤记录
  List<FinancialRecord> _filterRecords() {
    // 使用内部过滤方法
    final filteredRecords = _filterRecordsInternal();
    
    // 更新分页信息
    _totalRecords = filteredRecords.length;
    _totalPages = (_totalRecords / _recordsPerPage).ceil();
    _currentPage = 1; // 重置到第一页
    
    // 更新当前页面显示的数据
    _updateDisplayedRecords();
    
    return filteredRecords;
  }

  // 构建记录卡片
  Widget _buildRecordCard(FinancialRecord record, Patient patient) {
    final items = _recordItemsMap[record.id] ?? [];
    
    return _HoverableFinancialCard(
      record: record,
      patient: patient,
      items: items,
      onTap: () => _showFinancialRecordDialog(record, patient),
      onViewPatient: () => _viewPatientDetails(patient),
      onEdit: () => _showFinancialRecordDialog(record, patient),
      onDelete: () => _deleteFinancialRecord(record),
      child: Row(
          children: [
            // 患者信息列
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  patient.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            // 收费项目列
            Expanded(
              flex: 2,
              child: Text(
                items.isNotEmpty 
                    ? items.first.itemName 
                    : (record.notes ?? '收费项目'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 应收费列
            Expanded(
              flex: 1,
              child: Text(
                items.isNotEmpty 
                    ? '¥${(items.first.itemPrice % 1 == 0 ? items.first.itemPrice.toInt().toString() : items.first.itemPrice.toStringAsFixed(2))}'
                    : '¥0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // 加工费列
            Expanded(
              flex: 1,
              child: Text(
                items.isNotEmpty 
                    ? '¥${(items.first.processingFee % 1 == 0 ? items.first.processingFee.toInt().toString() : items.first.processingFee.toStringAsFixed(2))}'
                    : '¥0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // 已收费列
            Expanded(
              flex: 1,
              child: Text(
                items.isNotEmpty 
                    ? '¥${(items.first.totalPrice % 1 == 0 ? items.first.totalPrice.toInt().toString() : items.first.totalPrice.toStringAsFixed(2))}'
                    : '¥0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // 欠费列
            Expanded(
              flex: 1,
              child: Text(
                items.isNotEmpty 
                    ? () {
                        final debt = items.first.itemPrice - items.first.totalPrice;
                        return '¥${(debt % 1 == 0 ? debt.toInt().toString() : debt.toStringAsFixed(2))}';
                      }()
                    : '¥0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: items.isNotEmpty && (items.first.itemPrice - items.first.totalPrice) > 0 
                      ? Colors.red[700] 
                      : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // 操作列
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 查看按钮
                  IconButton(
                    onPressed: () => _viewPatientDetails(patient),
                    icon: Icon(Icons.visibility, color: Colors.blue[600], size: 18),
                    tooltip: '查看患者',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  // 编辑按钮
                  IconButton(
                    onPressed: () => _showFinancialRecordDialog(record, patient),
                    icon: Icon(Icons.edit, color: Colors.orange[600], size: 18),
                    tooltip: '编辑记录',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  // 删除按钮
                  IconButton(
                    onPressed: () => _deleteFinancialRecord(record),
                    icon: Icon(Icons.delete, color: Colors.red[600], size: 18),
                    tooltip: '删除记录',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  // 删除财务记录
  Future<void> _deleteFinancialRecord(FinancialRecord record) async {
    // 获取患者信息用于显示删除提示
    final patient = _getPatientById(record.patientId);
    final patientName = patient?.name ?? '未知患者';
    
    final confirmed = await DeleteConfirmDialogManager.showFinancialRecordDelete(
      context,
      patientName: patientName,
    );

    if (confirmed == true) {
      try {
        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        
        // 先删除相关的明细项
        final items = _recordItemsMap[record.id] ?? [];
        for (final item in items) {
          await financialProvider.deleteFinancialItem(item.id!);
        }
        
        // 删除主记录
        final success = await financialProvider.deleteFinancialRecord(record.id!);
        
        if (success) {
          // 重新加载数据
          await _loadData();
          
          DeleteSuccessToastManager.show(
            context,
            message: '财务记录删除成功',
          );
        } else {
          SuccessToastManager.showError(
            context,
            message: '删除失败',
          );
        }
      } catch (e) {
        SuccessToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }

  // 查看患者详情
  void _viewPatientDetails(Patient patient) {
    // 这里可以导航到患者详情页面
    // 暂时显示一个简单的对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('患者信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('姓名: ${patient.name}'),
            Text('年龄: ${patient.age}岁'),
            Text('性别: ${patient.gender}'),
            Text('电话: ${patient.phone.isEmpty ? '未设置' : patient.phone}'),
            Text('病历号: ${patient.medical_record_number ?? '未设置'}'),
            Text('首诊日期: ${DateFormat('yyyy-MM-dd').format(patient.first_visit_date)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

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
      if (result == true) {
        _loadData();
      }
    });
  }

  // 删除患者所有财务记录
  Future<void> _deleteAllFinancialRecordsByPatient(FinancialRecord record) async {
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
        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        
        // 获取该患者的所有财务记录
        final patientRecords = _financialRecords
            .where((r) => r.patientId == record.patientId)
            .toList();
        
        // 删除所有相关记录
        for (final patientRecord in patientRecords) {
          final items = _recordItemsMap[patientRecord.id] ?? [];
          for (final item in items) {
            await financialProvider.deleteFinancialItem(item.id!);
          }
          await financialProvider.deleteFinancialRecord(patientRecord.id!);
        }
        
        // 重新加载数据
        await _loadData();
        
        DeleteSuccessToastManager.show(
          context,
          message: '患者财务记录删除成功',
        );
      } catch (e) {
        SuccessToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }

  // 显示财务统计图表（改为基于当前筛选从数据源获取全量明细）
  Future<void> _showFinancialStatistics() async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      // 依据设置确定“患者管理”数据源（用于按姓名搜索患者ID）
      final String patientsDataSource = settingsProvider.dataSourceMode == 'modular'
          ? (settingsProvider.moduleDataSources['patients'] ?? settingsProvider.dataSourceType)
          : settingsProvider.dataSourceType;

      // 若有搜索词，先在SQLite中查患者ID；否则不限制
      List<int>? filterPatientIds;
      if (_searchQuery.isNotEmpty) {
        try {
          filterPatientIds = await patientProvider.searchPatientIds(
            _searchQuery,
            effectiveDataSourceType: patientsDataSource,
          );
        } catch (e) {
          filterPatientIds = [];
        }
      }

      // 取全量（当前筛选）收费明细，包含 patient_id
      final itemsWithDetails = await financialProvider.getAllFinancialItemsWithDetailsFiltered(
        sortBy: _sortBy,
        sortOrder: _sortAscending ? 'ASC' : 'DESC',
        startDate: _startDate,
        endDate: _endDate,
        patientIds: filterPatientIds,
        chargeItemQuery: _chargeItemQuery.isNotEmpty ? _chargeItemQuery : null,
        receivableMin: _receivableMin,
        receivableMax: _receivableMax,
        receivedMin: _receivedMin,
        receivedMax: _receivedMax,
        processingMin: _processingMin,
        processingMax: _processingMax,
      );

      // 构建 FinancialItem 列表 + FinancialRecord（最小字段）列表 + 患者列表
      final List<FinancialItem> allFinancialItems = [];
      final Map<int, FinancialRecord> recordMap = {};
      final Set<int> patientIdSet = {};

      for (final row in itemsWithDetails) {
        final FinancialItem item = row['item'] as FinancialItem;
        final int pid = row['patient_id'] as int;
        allFinancialItems.add(item);
        patientIdSet.add(pid);
        recordMap[item.financialRecordId] = recordMap[item.financialRecordId] ??
            FinancialRecord(
              id: item.financialRecordId,
              patientId: pid,
              totalQuantity: 0,
              createdAt: item.chargeDate,
              updatedAt: item.updatedAt,
              notes: row['record_notes'] as String?,
            );
      }

      // 批量获取患者信息
      final patients = await patientProvider.getPatientsByIds(
        patientIdSet.toList(),
        effectiveDataSourceType: patientsDataSource,
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
                  financialRecords: recordMap.values.toList(),
                  financialItems: allFinancialItems,
                  patients: patients,
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
  Future<bool> _showFinancialRecordDialog([FinancialRecord? record, Patient? contextPatient]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FinancialFormDialog(
        record: record,
        contextPatient: contextPatient,
      ),
    );
    
    if (result == true) {
      await _loadData();
    }
    
    return result ?? false;
  }

  // 显示编辑财务记录对话框（专用方法）
  // 这是专门用于财务管理列表编辑按钮的方法，显示收费信息列表并允许编辑备注
  Future<bool> _showEditFinancialRecordDialog(Patient patient, FinancialRecord record) async {
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
      
      if (result == true) {
        await _loadData();
      }
      
      return result ?? false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('编辑财务记录失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // 记录错误日志
      print('编辑财务记录时发生错误: $e');
      return false;
    }
  }

  // 构建财务卡片 - 紧凑版
  Widget _buildFinancialCard(
    Patient patient,
    FinancialRecord record,
    double totalCost,
    DateTime? lastVisitDate, {
    double? receivedSum,
    double? processingSum,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPurpleTheme = Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;
    
    // 计算财务数据
    final fee = processingSum ?? _calculateTotalProcessingFee(record);
    final received = receivedSum ?? _calculateTotalCollected(record);
    final debt = totalCost - received;

    return _HoverableFinancialListCard(
      onTap: () => _showFinancialDetail(patient),
      child: Row(
              children: [
                // 左侧：头像
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _getAvatarBackgroundColor(patient),
                  child: Text(
                    patient.name.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 中间：患者信息和财务数据
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 第一行：患者姓名 + 病历号
                      Row(
                        children: [
                          Text(
                            patient.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.badge,
                                  size: 11,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${patient.medical_record_number ?? '未设置'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // 第二行：财务信息标签
                      Row(
                        children: [
                          // 首诊日期
                          Flexible(
                            flex: 2,
                            child: _buildCompactFinancialTag(
                              icon: Icons.calendar_today,
                              label: DateFormat('yy-MM-dd').format(patient.first_visit_date),
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 4),
                          
                          // 最近更新
                          if (lastVisitDate != null)
                            Flexible(
                              flex: 2,
                              child: _buildCompactFinancialTag(
                                icon: Icons.update,
                                label: DateFormat('yy-MM-dd').format(lastVisitDate),
                                color: Colors.orange,
                              ),
                            ),
                          const SizedBox(width: 4),
                          
                          // 应收费
                          Flexible(
                            flex: 2,
                            child: _buildCompactFinancialTag(
                              icon: Icons.account_balance_wallet,
                              label: '¥${(totalCost % 1 == 0 ? totalCost.toInt().toString() : totalCost.toStringAsFixed(0))}',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 4),
                          
                          // 加工费
                          Flexible(
                            flex: 2,
                            child: _buildCompactFinancialTag(
                              icon: Icons.build,
                              label: '¥${(fee % 1 == 0 ? fee.toInt().toString() : fee.toStringAsFixed(0))}',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 4),
                          
                          // 已收费
                          Flexible(
                            flex: 2,
                            child: _buildCompactFinancialTag(
                              icon: Icons.check_circle,
                              label: '¥${(received % 1 == 0 ? received.toInt().toString() : received.toStringAsFixed(0))}',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 4),
                          
                          // 欠费
                          Flexible(
                            flex: 2,
                            child: _buildCompactFinancialTag(
                              icon: Icons.pending,
                              label: '¥${(debt % 1 == 0 ? debt.toInt().toString() : debt.toStringAsFixed(0))}',
                              color: debt > 0 ? Colors.red : Colors.grey,
                            ),
                          ),
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
                    _buildCompactFinancialActionButton(
                      icon: Icons.visibility,
                      color: Colors.blue,
                      tooltip: '查看',
                      onPressed: () => _showFinancialDetail(patient),
                    ),
                    
                    const SizedBox(width: 6),
                    
                    // 编辑按钮
                    _buildCompactFinancialActionButton(
                      icon: Icons.edit,
                      color: Colors.orange,
                      tooltip: '编辑',
                      onPressed: () async {
                        final result = await _showEditFinancialRecordDialog(patient, record);
                        if (result == true) {
                          await _loadData();
                        }
                      },
                    ),
                    
                    const SizedBox(width: 6),
                    
                    // 删除按钮
                    _buildCompactFinancialActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      tooltip: '删除',
                      onPressed: () => _deleteAllFinancialRecordsByPatient(record),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // 紧凑型财务标签
  Widget _buildCompactFinancialTag({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: color[700],
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 紧凑型财务操作按钮
  Widget _buildCompactFinancialActionButton({
    required IconData icon,
    required MaterialColor color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color[600]),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // 构建紧凑信息项组件
  Widget _buildCompactInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 计算应收金额
  double _calculateTotalReceivable(FinancialRecord record) {
    final items = _recordItemsMap[record.id] ?? [];
    return items.fold(0.0, (sum, item) => sum + (item.itemPrice * (item.quantity ?? 1)));
  }

  // 计算已收金额
  double _calculateTotalCollected(FinancialRecord record) {
    final items = _recordItemsMap[record.id] ?? [];
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // 计算欠费金额
  double _calculateOutstandingAmount(FinancialRecord record) {
    final items = _recordItemsMap[record.id] ?? [];
    return _calculateTotalReceivable(record) - _calculateTotalCollected(record);
  }

  // 计算加工费总额
  double _calculateTotalProcessingFee(FinancialRecord record) {
    final items = _recordItemsMap[record.id] ?? [];
    return items.fold(0.0, (sum, item) => sum + item.processingFee);
  }

  // 根据患者性别获取头像背景色
  Color _getAvatarBackgroundColor(Patient patient) {
    if (patient.gender == '女' || patient.gender.toLowerCase() == 'female') {
      return Colors.pink[400]!; // 女性为粉红色
    } else if (patient.gender == '男' || patient.gender.toLowerCase() == 'male') {
      return Colors.blue[300]!; // 男性为浅蓝色
    } else {
      return Colors.grey[400]!; // 其他情况为灰色
    }
  }

  // 构建收费记录卡片（按收费记录显示模式）
  Widget _buildFinancialItemCard(Patient patient, FinancialRecord record, FinancialItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editFinancialItem(record, item, patient),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 记录ID列
                SizedBox(
                  width: 70,
                  child: _buildDataCell(
                    value: '${item.id ?? 'N/A'}',
                    color: Colors.purple[600]!,
                    isBold: true,
                    fontSize: 13,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 病历号列
                SizedBox(
                  width: 90,
                  child: _buildDataCell(
                    value: '${patient.medical_record_number ?? '未设置'}',
                    color: Colors.orange[700]!,
                    isBold: true,
                    fontSize: 13,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 患者姓名列
                Expanded(
                  flex: 2,
                  child: _buildDataCell(
                    value: patient.name,
                    color: Colors.black87,
                    isBold: true,
                    fontSize: 14,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 收费日期列
                Expanded(
                  flex: 2,
                  child: _buildDateCell(
                    date: item.chargeDate,
                    icon: Icons.event,
                    color: Colors.teal[600]!,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 最近更新列
                Expanded(
                  flex: 2,
                  child: _buildDateCell(
                    date: record.updatedAt,
                    icon: Icons.update,
                    color: Colors.indigo[600]!,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 收费项目列
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_services, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.itemName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[900],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 应收费列
                Expanded(
                  flex: 2,
                  child: _buildAmountCell(
                    amount: item.itemPrice * (item.quantity ?? 1),
                    icon: Icons.request_quote,
                    color: Colors.blue[700]!,
                    bgColor: Colors.blue[50]!,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 已收费列
                Expanded(
                  flex: 2,
                  child: _buildAmountCell(
                    amount: item.totalPrice,
                    icon: Icons.check_circle,
                    color: Colors.green[700]!,
                    bgColor: Colors.green[50]!,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 加工费列
                Expanded(
                  flex: 2,
                  child: _buildAmountCell(
                    amount: item.processingFee,
                    icon: Icons.build,
                    color: Colors.orange[700]!,
                    bgColor: Colors.orange[50]!,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 操作列
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 编辑按钮
                      _buildActionButton(
                        icon: Icons.edit_rounded,
                        color: Colors.blue[600]!,
                        tooltip: '编辑',
                        onPressed: () => _editFinancialItem(record, item, patient),
                      ),
                      const SizedBox(width: 8),
                      // 删除按钮
                      _buildActionButton(
                        icon: Icons.delete_rounded,
                        color: Colors.red[600]!,
                        tooltip: '删除',
                        onPressed: () => _deleteFinancialItem(record, item, patient),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建数据单元格
  Widget _buildDataCell({
    required String value,
    required Color color,
    bool isBold = false,
    double fontSize = 13,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Text(
      value,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // 构建日期单元格
  Widget _buildDateCell({
    required DateTime date,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            DateFormat('yyyy-MM-dd').format(date),
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 构建金额单元格
  Widget _buildAmountCell({
    required double amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              '¥${amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButton({
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
        border: Border.all(color: color.withOpacity(0.3), width: 1),
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

  // 编辑收费记录明细项
  Future<void> _editFinancialItem(FinancialRecord record, FinancialItem item, Patient patient) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FinancialFormDialog(
        record: record,
        contextPatient: patient,
        item: item,
        showNotesField: false,
      ),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  // 删除收费记录明细项
  Future<void> _deleteFinancialItem(FinancialRecord record, FinancialItem item, Patient patient) async {
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '确认删除',
      message: '确定要删除患者 "${patient.name}" 的这条收费明细项吗？\n\n'
          '收费项目: ${item.itemName}\n'
          '收费日期: ${DateFormat('yyyy-MM-dd').format(item.chargeDate)}\n\n'
          '删除后无法恢复！',
      confirmText: '删除',
      cancelText: '取消',
    );

    if (confirmed == true) {
      try {
        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        final success = await financialProvider.deleteFinancialItem(item.id!);
        
        if (success) {
          await _loadData();
          
          DeleteSuccessToastManager.show(
            context,
            message: '已删除患者 "${patient.name}" 的收费明细项',
          );
        } else {
          SuccessToastManager.showError(
            context,
            message: '删除失败',
          );
        }
      } catch (e) {
        SuccessToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }



  /// 获取当前数据源类型
  String get _dataSourceType {
    try {
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
      return databaseProvider.dataSourceType;
    } catch (e) {
      return 'sqlite'; // 默认使用 SQLite
    }
  }

  // 构建分页控件
  Widget _buildPagination() {
    print('📊 _buildPagination 调试: 总记录数: $_totalRecords');
    print('📄 每页记录数: $_recordsPerPage');
    print('📑 总页数: $_totalPages');
    print('📍 当前页码: $_currentPage');
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭头
          _buildPaginationButton(
            icon: Icons.keyboard_arrow_left,
            onPressed: _currentPage > 1 ? _goToPreviousPage : null,
            isActive: _currentPage > 1,
          ),

          const SizedBox(width: 8),

          // 页码
          ...List.generate(
            _totalPages > 5 ? 5 : _totalPages,
            (index) {
              int pageNumber;
              if (_totalPages <= 5) {
                pageNumber = index + 1;
              } else {
                if (_currentPage <= 3) {
                  pageNumber = index + 1;
                } else if (_currentPage >= _totalPages - 2) {
                  pageNumber = _totalPages - 4 + index;
                } else {
                  pageNumber = _currentPage - 2 + index;
                }
              }

              return _buildPaginationButton(
                icon: null,
                pageNumber: pageNumber,
                onPressed: () => _goToPage(pageNumber),
                isActive: _currentPage == pageNumber,
              );
            },
          ),

          const SizedBox(width: 8),

          // 右箭头
          _buildPaginationButton(
            icon: Icons.keyboard_arrow_right,
            onPressed: _currentPage < _totalPages ? _goToNextPage : null,
            isActive: _currentPage < _totalPages,
          ),

          const SizedBox(width: 16),

          // 首页按钮
          _buildPaginationButton(
            icon: Icons.home,
            onPressed: _currentPage != 1 ? () => _goToPage(1) : null,
            isActive: _currentPage != 1,
          ),

          const SizedBox(width: 16),

          // 分页信息（统一样式：每页 X 条 · 共 N 条 / M 页）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Icon(Icons.info_outline, size: 16, color: Theme.of(context).primaryColor.withOpacity(0.9)),
                const SizedBox(width: 6),
                Text(
                  '每页 $_recordsPerPage 条 · 共 $_totalRecords 条 / $_totalPages 页',
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 页面跳转（容器化，视觉为一体）
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 左段：文本
                Container(
                  height: 36,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    '转到',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700], fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 中段：输入
                Container(
                  height: 36,
                  width: 72,
                  color: Colors.white,
                  child: TextField(
                    controller: _pageJumpController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '页码',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (value) {
                      final page = int.tryParse(value);
                      if (page != null) _goToPage(page);
                    },
                  ),
                ),
                // 右段：确认按钮（右侧圆角）
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    onTap: () {
                      final text = _pageJumpController.text.trim();
                      final page = int.tryParse(text);
                      if (page != null) _goToPage(page);
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        gradient: DentalColors.primaryGradient,
                      ),
                      child: const Text('确定', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建分页按钮
  Widget _buildPaginationButton({
    IconData? icon,
    int? pageNumber,
    VoidCallback? onPressed,
    required bool isActive,
  }) {
    final isPurpleTheme = Theme.of(context).scaffoldBackgroundColor == Colors.purple[50];
    
    if (icon != null) {
      // 箭头或首页按钮
      return IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        splashRadius: 20,
        color: isActive
            ? (isPurpleTheme ? Colors.purple[600] : Theme.of(context).primaryColor)
            : Colors.grey[400],
        disabledColor: Colors.grey[300],
      );
    } else {
      // 页码按钮
      return Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: isActive
                    ? (isPurpleTheme ? Colors.purple[600] : Theme.of(context).primaryColor)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? (isPurpleTheme ? Colors.purple[600]! : Theme.of(context).primaryColor)
                      : Colors.grey[300]!,
                ),
              ),
              child: Center(
                child: Text(
                  '$pageNumber',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey[700],
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

/// 财务记录编辑对话框
/// 显示收费信息列表并允许编辑备注信息
class FinancialRecordEditDialog extends StatefulWidget {
  final Patient patient;
  final FinancialRecord record;

  const FinancialRecordEditDialog({
    Key? key,
    required this.patient,
    required this.record,
  }) : super(key: key);

  @override
  State<FinancialRecordEditDialog> createState() => _FinancialRecordEditDialogState();
}

class _FinancialRecordEditDialogState extends State<FinancialRecordEditDialog> {
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  List<FinancialItem> _financialItems = [];

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.record.notes ?? '';
    _loadFinancialItems();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // 加载财务明细项
  Future<void> _loadFinancialItems() async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final items = await financialProvider.getFinancialItemsByRecordId(widget.record.id!);
      setState(() {
        _financialItems = items;
      });
    } catch (e) {
      print('加载财务明细项失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.indigo[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '编辑财务记录',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          minHeight: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientInfoSection(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFinancialItemsSection(),
                    const SizedBox(height: 16),
                    _buildNotesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  // 构建患者信息区域
  Widget _buildPatientInfoSection() {
    final bool isFemale = (widget.patient.gender == '女') ||
        (widget.patient.gender.toLowerCase() == 'female');
    final Color? infoBgColor = isFemale ? Colors.pink[50] : Colors.blue[50];
    final Color infoBorderColor =
        isFemale ? Colors.pink[200]! : Colors.blue[200]!;
    final Color avatarBgColor = isFemale ? Colors.pink[400]! : Colors.blue[300]!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: infoBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: infoBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: infoBorderColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: avatarBgColor,
            child: Text(
              widget.patient.name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: infoBorderColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已选择患者',
                      style: TextStyle(
                        color: infoBorderColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.patient.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.badge,
                        label: '病历号',
                        value: widget.patient.medical_record_number?.toString() ?? '未设置',
                        color: Colors.orange[600]!,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.calendar_today,
                        label: '首诊日期',
                        value: DateFormat('MM-dd').format(widget.patient.first_visit_date),
                        color: Colors.purple[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建信息芯片
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // 构建收费信息列表区域
  Widget _buildFinancialItemsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.orange[700],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '收费信息 (${_financialItems.length}条)',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _addFinancialItem(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加收费项'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 收费信息列表
          if (_financialItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '暂无收费记录',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  // 表头
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('收费日期', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.left)),
                        Expanded(flex: 3, child: Text('收费项目', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.left)),
                        Expanded(flex: 2, child: Text('应收费', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.left)),
                        Expanded(flex: 2, child: Text('加工费', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.left)),
                        Expanded(flex: 2, child: Text('已收费', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.left)),
                        SizedBox(width: 100, child: Text('操作', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  // 数据行
                  ...List.generate(_financialItems.length, (index) {
                    final item = _financialItems[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              DateFormat('yyyy-MM-dd').format(item.chargeDate),
                              style: const TextStyle(fontSize: 14),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.itemName,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '¥${(item.itemPrice * (item.quantity ?? 1)).toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.w500),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '¥${item.processingFee.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 14, color: Colors.orange[700], fontWeight: FontWeight.w500),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '¥${item.totalPrice.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.w500),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () => _editFinancialItem(item),
                                  icon: Icon(Icons.edit, color: Colors.blue[600], size: 18),
                                  tooltip: '编辑',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                IconButton(
                                  onPressed: () => _deleteFinancialItem(item),
                                  icon: Icon(Icons.delete, color: Colors.red[600], size: 18),
                                  tooltip: '删除',
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 构建备注编辑区域
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green[200]!.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: Colors.green[700],
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '备注信息',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 备注输入框
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[300]!, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.green[300]!.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '备注信息',
                hintText: '请输入备注信息...',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[600]!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.note_add, color: Colors.green[600], size: 18),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建操作按钮
  List<Widget> _buildActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 取消按钮
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '取消',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 保存按钮
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[500]!, Colors.indigo[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveNotes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '保存中...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.save,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // 添加收费项
  Future<void> _addFinancialItem() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FinancialDetailFormDialog(
        patient: widget.patient,
        record: widget.record,
        item: null,
        onResult: (success) {
          Navigator.of(context).pop(success);
        },
      ),
    );
    
    if (result == true) {
      await _loadFinancialItems();
    }
  }

  // 编辑收费项
  Future<void> _editFinancialItem(FinancialItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FinancialDetailFormDialog(
        patient: widget.patient,
        record: widget.record,
        item: item,
        onResult: (success) {
          Navigator.of(context).pop(success);
        },
      ),
    );
    
    if (result == true) {
      await _loadFinancialItems();
    }
  }

  // 更新财务记录的收费项数量和更新时间
  Future<void> _updateFinancialRecordAfterItemChange() async {
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      
      // 获取该财务记录的所有收费项，重新计算总数量
      final items = await financialProvider.getFinancialItemsByRecordId(widget.record.id!);
      final totalQuantity = items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 1));
      
      // 更新财务记录
      final updatedRecord = widget.record.copyWith(
        totalQuantity: totalQuantity,
        updatedAt: DateTime.now(),
      );
      
      await financialProvider.updateFinancialRecord(updatedRecord);
    } catch (e) {
      print('更新财务记录失败: $e');
    }
  }

  // 删除收费项
  Future<void> _deleteFinancialItem(FinancialItem item) async {
    final confirmed = await DeleteConfirmDialogManager.show(
      context,
      title: '确认删除',
      message: '确定要删除这条收费记录吗？\n\n'
          '收费项目: ${item.itemName}\n'
          '收费日期: ${DateFormat('yyyy-MM-dd').format(item.chargeDate)}\n'
          '应收费: ¥${(item.itemPrice * (item.quantity ?? 1)).toStringAsFixed(0)}\n\n'
          '删除后无法恢复！',
      confirmText: '删除',
      cancelText: '取消',
    );

    if (confirmed == true) {
      try {
        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        final success = await financialProvider.deleteFinancialItem(item.id!);
        
        if (success) {
          // 更新财务记录的收费项数量和更新时间
          await _updateFinancialRecordAfterItemChange();
          await _loadFinancialItems();
          SuccessToastManager.show(context, message: '收费记录删除成功');
        } else {
          SuccessToastManager.showError(context, message: '删除失败');
        }
      } catch (e) {
        SuccessToastManager.showError(context, message: '删除失败: $e');
      }
    }
  }

  // 保存备注信息
  Future<void> _saveNotes() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      
      // 创建更新后的财务记录，只更新备注字段
      final updatedRecord = widget.record.copyWith(
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        updatedAt: DateTime.now(),
      );
      
      // 更新财务记录
      final success = await financialProvider.updateFinancialRecord(updatedRecord);
      
      if (success) {
        SuccessToastManager.show(context, message: '财务记录更新成功');
        Navigator.of(context).pop(true);
      } else {
        SuccessToastManager.showError(context, message: '更新失败，请重试');
      }
    } catch (e) {
      SuccessToastManager.showError(context, message: '操作出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// 可悬浮的财务列表卡片组件
class _HoverableFinancialListCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HoverableFinancialListCard({
    Key? key,
    required this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  State<_HoverableFinancialListCard> createState() => _HoverableFinancialListCardState();
}

class _HoverableFinancialListCardState extends State<_HoverableFinancialListCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered 
                ? Color(0xFFE3F2FD)  // 浅蓝色
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// 可悬浮的财务记录卡片组件(旧版,用于表格模式)
class _HoverableFinancialCard extends StatefulWidget {
  final FinancialRecord record;
  final Patient patient;
  final List<FinancialItem> items;
  final VoidCallback onTap;
  final VoidCallback onViewPatient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  const _HoverableFinancialCard({
    Key? key,
    required this.record,
    required this.patient,
    required this.items,
    required this.onTap,
    required this.onViewPatient,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  }) : super(key: key);

  @override
  State<_HoverableFinancialCard> createState() => _HoverableFinancialCardState();
}

class _HoverableFinancialCardState extends State<_HoverableFinancialCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    print('_HoverableFinancialCard build: ${widget.patient.name}, _isHovered=$_isHovered');
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        print('✅ 财务卡片悬浮进入: ${widget.patient.name}');
        setState(() {
          _isHovered = true;
          print('✅ setState完成, _isHovered=$_isHovered');
        });
      },
      onExit: (_) {
        print('❌ 财务卡片悬浮离开: ${widget.patient.name}');
        setState(() {
          _isHovered = false;
          print('❌ setState完成, _isHovered=$_isHovered');
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isHovered 
              ? Colors.red  // 先用红色测试,确保能看到变化
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}
