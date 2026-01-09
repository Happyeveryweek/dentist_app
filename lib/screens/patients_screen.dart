import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/screens/patient_detail_screen.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:dentist_app/utils/toast_util.dart';
import 'dart:async';
import 'package:dentist_app/widgets/patient_form_sheet.dart'; // 添加这行导入
import 'package:dentist_app/widgets/modern_date_picker.dart'; // 添加新的公共日期时间选择器
import 'package:dentist_app/widgets/success_toast.dart'; // 添加新的公共组件导入
import 'package:dentist_app/utils/permission_utils.dart'; // 添加权限工具类导入

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

  Timer? _searchTimer;

  // 时间筛选相关状态
  bool _showTimeFilter = false;
  String _dateFilterType = 'first_visit_date'; // 'first_visit_date', 'updated_at'
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
      if (!_isLoadingMore && _hasMoreData && _searchQuery.isEmpty && !_isDateRangeFiltering) {
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
    if (_searchTimer != null && _searchTimer!.isActive) {
      _searchTimer!.cancel();
    }
    super.dispose();
  }

  // 重置搜索和分页状态，重新加载数据
  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreData = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      print('加载患者列表，数据库类型: ${dbProvider.dbType}');

      // 确保PatientProvider已初始化
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      if (!patientProvider.initialized) {
        await patientProvider.initializeFromDatabase(dbProvider);
      }
      
      // 确保PatientProvider有UserProvider的引用用于权限过滤
      patientProvider.setUserProvider(userProvider);

      List<Patient> patients = [];

      // 如果启用了时间筛选，需要获取所有患者数据进行筛选
      if (_isDateRangeFiltering && _startDate != null && _endDate != null) {
        // 获取所有患者数据
        patients = await patientProvider.getAllPatients();
        print('获取所有患者数据用于时间筛选: ${patients.length} 个患者');
        
        // 应用时间筛选
        patients = _applyTimeFilterToPatients(patients);
        print('应用时间筛选后剩余 ${patients.length} 个患者');
        
        // 在内存中应用排序
        _sortPatientsInMemory(patients);
        
        // 时间筛选模式下，总患者数就是筛选后的数量
        _totalPatientsInDatabase = patients.length;
      } else if (_searchQuery.isEmpty) {
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
        // 使用我们的搜索方法直接在数据库中搜索
        patients = await patientProvider.searchPatients(_searchQuery);
        print('搜索 "$_searchQuery" 返回 ${patients.length} 个结果');
        
        // 搜索模式下，总患者数就是搜索结果的数量
        _totalPatientsInDatabase = patients.length;
        
        // 在搜索模式下，需要在内存中排序
        _sortPatientsInMemory(patients);
      }

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
      print('加载患者数据错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 加载更多患者数据
  Future<void> _loadMorePatients() async {
    if (_isLoadingMore || !_hasMoreData || _searchQuery.isNotEmpty || _isDateRangeFiltering) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final nextPage = _currentPage + 1;
      final newPatients = await Provider.of<PatientProvider>(context, listen: false).getPatientsPage(
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
      print('加载更多患者数据错误: $e');
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
    print('刷新患者列表...');

    // 强制清除数据库提供者中的缓存
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    await Provider.of<PatientProvider>(context, listen: false).forceRefreshPatients();

    if (mounted) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _patients = [];
        // 保持时间筛选状态，不清除筛选条件
      });
    }

    await _loadPatients();

    if(mounted) {
      SuccessToastManager.show(
        context,
        message: '刷新成功',
      );
    }

    print('患者列表刷新完成，加载了 ${_patients.length} 个患者');
  }

  // 在内存中对患者列表进行排序（不触发setState）
  void _sortPatientsInMemory(List<Patient> patients) {
    switch (_currentSort) {
      case 'name':
        patients.sort(
          (a, b) =>
              _ascending
                  ? a.name.compareTo(b.name)
                  : b.name.compareTo(a.name),
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

  // 对当前显示的患者列表进行排序（触发setState）
  void _sortPatients() {
    setState(() {
      _sortPatientsInMemory(_patients);
    });
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

  // 在患者列表中展示联系方式
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
          parts =
              parts.map((p) {
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

  Widget _buildPatientsHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '患者管理',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: Colors.teal.shade600),
                onPressed: () {
                  _showSortOptions(context);
                },
                tooltip: '排序选项',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.teal.shade100,
          ),
        ],
      ),
    );
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
      body: Column(
        children: [
          _buildPatientsHeader(),
          _buildSearchBar(),
          _buildPatientStatsBar(),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            '加载患者数据中...',
                            style: TextStyle(color: AppTheme.secondaryText),
                          ),
                        ],
                      ),
                    )
                    : _patients.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: _refreshPatients,
                      color: AppTheme.primaryColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.padding),
                        itemCount:
                            _patients.length +
                            (_hasMoreData && _searchQuery.isEmpty ? 1 : 0),
                        controller: _scrollController,
                        itemBuilder: (context, index) {
                          // 如果是最后一项且有更多数据要加载，显示加载指示器
                          if (index == _patients.length &&
                              _hasMoreData &&
                              _searchQuery.isEmpty) {
                            return _buildLoadingIndicator();
                          }

                          // 否则显示患者卡片
                          final patient = _patients[index];
                          return _buildPatientCard(patient);
                        },
                      ),
                    ),
          ),
        ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.lightText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '暂无患者数据' : '未找到符合"$_searchQuery"的患者',
            style: const TextStyle(fontSize: 16, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
                // 清空搜索后重新加载患者列表
                _loadPatients();
              },
              icon: const Icon(Icons.clear),
              label: const Text('清除搜索'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            )
          else
            PermissionWrapper(
              module: 'patients',
              action: 'create',
              hideWhenDenied: true,
              child: ElevatedButton.icon(
                onPressed: () => _showPatientDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('添加首位患者'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientStatsBar() {
    if (_isLoading) return const SizedBox.shrink();

    // 使用数据库中的总患者数，而不是当前页面的患者数量
    final totalCount = _totalPatientsInDatabase;

    String pageInfo = '';
    if (_searchQuery.isEmpty && _hasMoreData && !_isDateRangeFiltering) {
      pageInfo = '第$_currentPage页 | ';
    }

    String filterInfo = '';
    if (_searchQuery.isNotEmpty) {
      filterInfo = '搜索结果 | ';
    } else if (_isDateRangeFiltering && _startDate != null && _endDate != null) {
      filterInfo = '时间筛选 | ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.cardBackground,
      child: Row(
        children: [
          Text(
            '共 $totalCount 位患者',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '$filterInfo$pageInfo当前显示: ${_patients.length} 位',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }

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
                  title: '按修改时间排序',
                  icon: Icons.update,
                  isSelected: _currentSort == 'updated',
                  isAscending: _ascending,
                  onTap: () {
                    _changeSort('updated');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按年龄排序',
                  icon: Icons.sort,
                  isSelected: _currentSort == 'age',
                  isAscending: _ascending,
                  onTap: () {
                    _changeSort('age');
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                _buildSortOption(
                  title: '按病历号排序',
                  icon: Icons.format_list_numbered,
                  isSelected: _currentSort == 'medical_record',
                  isAscending: _ascending,
                  onTap: () {
                    _changeSort('medical_record');
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
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryText,
      ),
      title: Text(title),
      trailing:
          isSelected
              ? Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: AppTheme.primaryColor,
                size: 18,
              )
              : null,
      onTap: onTap,
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.padding),
      color: AppTheme.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索姓名、拼音、电话、病历号或地址',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.secondaryText,
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppTheme.secondaryText,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                          // 清空搜索后重新加载患者列表
                          _loadPatients();
                        },
                      )
                      : null,
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              // 当搜索值变化时，不要立即搜索，而是等待用户停止输入
              _onSearchChanged(value);
            },
          ),
          if (_searchQuery.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '提示: 可通过姓名、拼音、地址、电话等进行精确或模糊搜索',
                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
            ),
          const SizedBox(height: 16),
          // 时间筛选区域
          _buildTimeFilterSection(),
        ],
      ),
    );
  }

  // 搜索延迟处理
  void _onSearchChanged(String query) {
    // 取消之前的延迟搜索
    if (_searchTimer != null && _searchTimer!.isActive) {
      _searchTimer!.cancel();
    }

    // 立即设置加载状态，并清空患者列表
    setState(() {
      _isLoading = true;
      _patients = [];
    });

    // 设置新的延迟搜索，300ms后执行
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (query != _searchQuery) return; // 如果查询已更改，则不执行搜索
      _loadPatients(); // 执行搜索
    });
  }

  // 构建时间筛选区域
  Widget _buildTimeFilterSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间筛选标题和切换按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showTimeFilter ? '隐藏时间筛选' : '时间筛选',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showTimeFilter = !_showTimeFilter;
                    if (!_showTimeFilter) {
                      // 隐藏时间筛选时，清除筛选条件
                      _startDate = null;
                      _endDate = null;
                      _isDateRangeFiltering = false;
                      _loadPatients(); // 重新加载数据
                    }
                  });
                },
                icon: Icon(
                  _showTimeFilter ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.primaryColor,
                ),
                tooltip: _showTimeFilter ? '隐藏时间筛选' : '显示时间筛选',
              ),
            ],
          ),
          
          // 时间筛选内容
          if (_showTimeFilter) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // 筛选类型选择
            Row(
              children: [
                const Text(
                  '按: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterTypeButton(
                  '首诊时间',
                  'first_visit_date',
                  Icons.event,
                ),
                const SizedBox(width: 12),
                _buildFilterTypeButton(
                  '更新时间',
                  'updated_at',
                  Icons.update,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 日期范围选择
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    '开始日期',
                    _startDate,
                    (date) => setState(() => _startDate = date),
                    isStartDate: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    '结束日期',
                    _endDate,
                    (date) => setState(() => _endDate = date),
                    isStartDate: false,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startDate != null && _endDate != null
                        ? _applyTimeFilter
                        : null,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('应用筛选'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearTimeFilter,
                    icon: const Icon(Icons.clear),
                    label: const Text('清除筛选'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondaryText,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // 当前筛选状态显示
            if (_isDateRangeFiltering && _startDate != null && _endDate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前筛选: ${DateFormat('yyyy-MM-dd').format(_startDate!)} 至 ${DateFormat('yyyy-MM-dd').format(_endDate!)} (${_dateFilterType == 'first_visit_date' ? '首诊时间' : '更新时间'})',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // 构建筛选类型按钮
  Widget _buildFilterTypeButton(String label, String value, IconData icon) {
    final isSelected = _dateFilterType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _dateFilterType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.secondaryText,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建日期选择字段
  Widget _buildDateField(String label, DateTime? date, Function(DateTime?) onDateSelected, {required bool isStartDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? selectedDate = await showDialog<DateTime>(
              context: context,
              builder: (BuildContext context) {
                return ModernDatePickerDialog(
                  initialDate: date ?? DateTime.now(),
                  firstDate: isStartDate ? DateTime(2000) : (_startDate ?? DateTime(2000)),
                  lastDate: isStartDate ? (_endDate ?? DateTime(2100)) : DateTime(2100),
                  title: '选择$label',
                );
              },
            );
            if (selectedDate != null && context.mounted) {
              onDateSelected(selectedDate);
              // 如果是开始日期，确保结束日期不早于开始日期
              if (isStartDate && _endDate != null && _endDate!.isBefore(selectedDate)) {
                setState(() {
                  _endDate = selectedDate;
                });
              }
              // 如果是结束日期，确保开始日期不晚于结束日期
              if (!isStartDate && _startDate != null && _startDate!.isAfter(selectedDate)) {
                setState(() {
                  _startDate = selectedDate;
                });
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('yyyy年MM月dd日').format(date)
                        : '请选择日期',
                    style: TextStyle(
                      fontSize: 14,
                      color: date != null ? AppTheme.primaryText : AppTheme.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
      final patientDateOnly = DateTime(patientDate.year, patientDate.month, patientDate.day);
      final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final endDateOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      
      // 使用 compareTo 进行日期比较，包含开始和结束日期
      return patientDateOnly.compareTo(startDateOnly) >= 0 && 
             patientDateOnly.compareTo(endDateOnly) <= 0;
    }).toList();
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          onTap: () => _showPatientDetail(context, patient),
          child: Column(
            children: [
              // 顶部区域
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 头像
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: patientColor.withOpacity(0.15),
                      child: Text(
                        patient.name.isNotEmpty
                            ? patient.name.characters.first
                            : "?",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: patientColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 姓名和基本信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                patient.name,
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
                                  color:
                                      patient.gender == '男'
                                          ? AppTheme.infoColor.withOpacity(0.1)
                                          : AppTheme.accentColor.withOpacity(
                                            0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  patient.gender,
                                  style: TextStyle(
                                    color:
                                        patient.gender == '男'
                                            ? AppTheme.infoColor
                                            : AppTheme.accentColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${patient.age}岁',
                                style: const TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: AppTheme.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayPhone,
                                style: const TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 操作按钮
                    Column(
                      children: [
                        PermissionWrapper(
                          module: 'patients',
                          action: 'edit',
                          recordDoctor: patient.doctor,
                          onPermissionDenied: () {
                            PermissionUtils.showPermissionDeniedMessage(
                              context,
                              customMessage: '您只能编辑自己负责的患者',
                            );
                          },
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed:
                                () =>
                                    _showPatientDialog(context, patient: patient),
                            color: AppTheme.primaryColor,
                            tooltip: '编辑患者',
                          ),
                        ),
                        PermissionWrapper(
                          module: 'patients',
                          action: 'delete',
                          recordDoctor: patient.doctor,
                          onPermissionDenied: () {
                            PermissionUtils.showPermissionDeniedMessage(
                              context,
                              customMessage: '您只能删除自己负责的患者',
                            );
                          },
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed:
                                () => _confirmDeletePatient(context, patient),
                            color: AppTheme.errorColor,
                            tooltip: '删除患者',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 底部区域
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行信息
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.badge_outlined,
                            text: '病历号: ${patient.medicalRecordNumber ?? "未分配"}',
                            color: AppTheme.infoColor,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.calendar_today_outlined,
                            text:
                                '初诊: ${DateFormat('yyyy-MM-dd').format(patient.firstVisitDate)}',
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 第二行信息
                    Row(
                      children: [
                        Expanded(
                          child: (patient.doctor != null &&
                                  patient.doctor!.isNotEmpty)
                              ? _buildInfoItem(
                                  icon: Icons.medical_services_outlined,
                                  text: '医生: ${patient.doctor}',
                                  color: AppTheme.secondaryColor,
                                )
                              : _buildInfoItem(
                                  icon: Icons.medical_services_outlined,
                                  text: '医生: 未分配',
                                  color: AppTheme.secondaryColor,
                                ),
                        ),
                        Expanded(
                          child: (patient.address != null &&
                                  patient.address!.isNotEmpty)
                              ? _buildInfoItem(
                                  icon: Icons.location_on_outlined,
                                  text: patient.address!,
                                  color: AppTheme.accentColor,
                                )
                              : _buildInfoItem(
                                  icon: Icons.location_on_outlined,
                                  text: '未填写',
                                  color: AppTheme.lightText,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 查看详情按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _showPatientDetail(context, patient),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('查看详情'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13),
        ),
      ],
    );
  }

  void _showPatientDetail(BuildContext context, Patient patient) {
    print(
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
        print('从患者详情页返回，刷新患者列表');
        _refreshPatients();
      }
    });
  }

  void _showPatientDialog(BuildContext context, {Patient? patient}) async {
    if (patient == null) {
      // 添加新患者 - 直接获取病历号，不显示加载提示

      try {
        // 先获取最大病历号 - 使用await等待操作完成
        final dbProvider = Provider.of<DatabaseProvider>(
          context,
          listen: false,
        );
        final int maxMedicalRecordNumber =
            await Provider.of<PatientProvider>(context, listen: false).getMaxMedicalRecordNumber();
        final int nextMedicalRecordNumber = maxMedicalRecordNumber + 1;

        print('当前最大病历号: $maxMedicalRecordNumber');
        print('将使用默认病历号: $nextMedicalRecordNumber');

        // 移除提示条，直接设置病历号

        // 确保UI上下文仍然有效
        if (context.mounted) {
          // 使用 Navigator.push 打开全屏页面
          print('构建PatientFormSheet，传入初始病历号: $nextMedicalRecordNumber');
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
                            print('患者表单保存成功，直接刷新患者列表');
                            _loadPatients();
                            // 使用公共组件的成功提示
                            SuccessToastManager.show(context, message: message);
                          } else {
                            SuccessToastManager.showError(context, message: message);
                          }
                        },
                      ),
                    ),
                  ),
            ),
          );
        }
      } catch (error) {
        print('获取最大病历号出错: $error');
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
                            print('患者表单保存成功，直接刷新患者列表');
                            _loadPatients();
                            // 使用公共组件的成功提示
                            SuccessToastManager.show(context, message: message);
                          } else {
                            SuccessToastManager.showError(context, message: message);
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
                        print('患者表单保存成功，直接刷新患者列表');
                        _loadPatients();
                        // 使用公共组件的成功提示
                        SuccessToastManager.show(context, message: message);
                      } else {
                        SuccessToastManager.showError(context, message: message);
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
      try {
        final dbProvider = Provider.of<DatabaseProvider>(
          context,
          listen: false,
        );
        await Provider.of<PatientProvider>(context, listen: false).deletePatient(patient.id!);
        _loadPatients();
        
        // 使用新的成功提示组件
        if (mounted) {
          SuccessToastManager.show(context, message: '患者删除成功');
        }
      } catch (e) {
        if (mounted) {
          SuccessToastManager.showError(context, message: '删除失败: $e');
        }
      }
    }
  }

  // 构建加载更多指示器
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const Column(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '加载更多患者数据...',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}