import 'package:flutter/material.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/features/patients/widgets/patient_form_sheet.dart';
import 'package:dentist_app/utils/pinyin_util.dart';
import 'dart:convert';

class PatientSelectionDialog extends StatefulWidget {
  final List<Patient> patients;
  final VoidCallback? onPatientAdded;

  const PatientSelectionDialog({
    required this.patients,
    this.onPatientAdded,
  });

  @override
  State<PatientSelectionDialog> createState() => PatientSelectionDialogState();
}

class PatientSelectionDialogState extends State<PatientSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Patient> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    if (widget.patients.isEmpty) {
      _filteredPatients = [];
    } else {
      _filteredPatients = List.from(widget.patients);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPatients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = List.from(widget.patients);
      } else {
        _filteredPatients = widget.patients.where((patient) {
          final queryLower = query.toLowerCase();
          
          final nameMatch = patient.name.toLowerCase().contains(queryLower);
          final phoneMatch = patient.phone.toLowerCase().contains(queryLower);
          
          bool pinyinMatch = false;
          bool initialsMatch = false;
          
          if (patient.name.isNotEmpty) {
            try {
              final pinyin = PinyinUtil.toPinyin(patient.name, separator: '').toLowerCase();
              final initials = PinyinUtil.getInitials(patient.name).toLowerCase();
              
              pinyinMatch = pinyin.contains(queryLower);
              initialsMatch = initials.contains(queryLower);
            } catch (e) {
              print('拼音搜索错误: $e');
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
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
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _filterPatients,
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '患者列表 (${_filteredPatients.length})',
                    style: TextStyle(
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
              child: _filteredPatients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.patients.isEmpty)
                            Column(
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                                  _searchController.text.isEmpty ? Icons.people_outline : Icons.search_off,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty ? '暂无患者数据' : '未找到匹配的患者',
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
                                patient.name.isNotEmpty ? patient.name[0] : '?',
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
                              '电话: ${_getDisplayPhone(patient.phone)}',
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

  Future<void> _addNewPatient() async {
    Navigator.of(context).pop();
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PatientFormSheet(
        onSaved: (isSuccess, message) {
          if (isSuccess) {
            widget.onPatientAdded?.call();
          }
          return isSuccess;
        },
      ),
    );
    
    if (result == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('患者添加成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
