import 'package:flutter/material.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/utils/pinyin_util.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../../utils/app_logger.dart';

class PatientSelectionDialog extends StatefulWidget {
  final List<Patient> patients;
  final VoidCallback? onPatientAdded;
  final Future<List<Patient>> Function()? onLoadPatients;
  final Future<List<Patient>> Function(String query)? onSearchPatients;

  const PatientSelectionDialog({super.key, 
    required this.patients,
    this.onPatientAdded,
    this.onLoadPatients,
    this.onSearchPatients,
  });

  @override
  State<PatientSelectionDialog> createState() => PatientSelectionDialogState();
}

class PatientSelectionDialogState extends State<PatientSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Patient> _filteredPatients = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _searchDebounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onLoadPatients != null) {
      _loadPatients();
    } else {
      _filteredPatients = List.from(widget.patients);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final loader = widget.onLoadPatients;
    if (loader == null) return;

    final currentRequest = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final patients = await loader();
      if (!mounted || currentRequest != _requestId) return;
      setState(() {
        _filteredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentRequest != _requestId) return;
      setState(() {
        _filteredPatients = [];
        _isLoading = false;
        _errorMessage = '加载患者失败';
      });
      AppLogger.info('加载患者列表失败: $e');
    }
  }

  void _filterPatients(String query) {
    final searcher = widget.onSearchPatients;
    if (searcher != null) {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
        final trimmed = query.trim();
        if (trimmed.isEmpty) {
          await _loadPatients();
          return;
        }

        final currentRequest = ++_requestId;
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        try {
          final patients = await searcher(trimmed);
          if (!mounted || currentRequest != _requestId) return;
          setState(() {
            _filteredPatients = patients;
            _isLoading = false;
          });
        } catch (e) {
          if (!mounted || currentRequest != _requestId) return;
          setState(() {
            _filteredPatients = [];
            _isLoading = false;
            _errorMessage = '搜索患者失败';
          });
          AppLogger.info('搜索患者失败: $e');
        }
      });
      return;
    }

    setState(() {
      if (query.isEmpty) {
        _filteredPatients = List.from(widget.patients);
      } else {
        _filteredPatients =
            widget.patients.where((patient) {
              final queryLower = query.toLowerCase();

              final nameMatch = patient.name.toLowerCase().contains(queryLower);
              final phoneMatch = patient.phone.toLowerCase().contains(
                queryLower,
              );

              bool pinyinMatch = false;
              bool initialsMatch = false;

              if (patient.name.isNotEmpty) {
                try {
                  final pinyin =
                      PinyinUtil.toPinyin(
                        patient.name,
                        separator: '',
                      ).toLowerCase();
                  final initials =
                      PinyinUtil.getInitials(patient.name).toLowerCase();

                  pinyinMatch = pinyin.contains(queryLower);
                  initialsMatch = initials.contains(queryLower);
                } catch (e) {
                  AppLogger.info('拼音搜索错误: $e');
                }
              }

              return nameMatch || phoneMatch || pinyinMatch || initialsMatch;
            }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_search,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '选择患者',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索患者 (姓名/拼音/首字母)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _filterPatients,
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.people, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '患者列表 (${_filteredPatients.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child:
                  _isLoading
                      ? _buildLoadingState()
                      : _filteredPatients.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_errorMessage != null)
                              Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Builder(
                                    builder: (context) {
                                      final errorMessage = _errorMessage;
                                      return Text(
                                        errorMessage ?? '',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            else if (widget.patients.isEmpty &&
                                widget.onLoadPatients == null)
                              Column(
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '正在加载患者数据...',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Icon(
                                    _searchController.text.isEmpty
                                        ? Icons.people_outline
                                        : Icons.search_off,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? '暂无患者数据'
                                        : '未找到匹配的患者',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
                                child: Text(
                                  patient.name.isNotEmpty
                                      ? patient.name[0]
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                patient.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '最近就诊: ${DateFormat('yyyy-MM-dd').format(patient.updatedAt)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pop(patient);
                              },
                            ),
                          );
                        },
                      ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.trim().isEmpty ? '正在加载患者数据...' : '正在搜索患者...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
