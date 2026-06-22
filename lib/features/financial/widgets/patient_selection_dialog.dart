import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/patient.dart';
// 患者选择对话框
class PatientSelectionDialog extends StatefulWidget {
  final List<Patient> patients;

  const PatientSelectionDialog({Key? key, required this.patients}) : super(key: key);

  @override
  State<PatientSelectionDialog> createState() => _PatientSelectionDialogState();
}

class _PatientSelectionDialogState extends State<PatientSelectionDialog> {
  String _searchQuery = '';
  List<Patient> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    _filteredPatients = List.from(widget.patients);
  }

  void _filterPatients(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredPatients = List.from(widget.patients);
      } else {
        _filteredPatients = widget.patients.where((patient) {
          // 姓名搜索
          final nameMatch = patient.name.toLowerCase().contains(query.toLowerCase());
          
          // 病历号搜索
          final medicalRecordMatch = patient.medical_record_number?.toString().contains(query) ?? false;
          
          // 姓名拼音搜索（支持带空格和不带空格）
          final namePinyinMatch = patient.name_pinyin?.toLowerCase().replaceAll(' ', '').contains(query.toLowerCase().replaceAll(' ', '')) ?? false;
          
          // 姓名拼音首字母搜索
          final nameInitialsMatch = patient.name_initials?.toLowerCase().contains(query.toLowerCase()) ?? false;
          
          return nameMatch || medicalRecordMatch || namePinyinMatch || nameInitialsMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 根据患者信息的更新时间排序，最新的排到最前面
    List<Patient> sortedPatients = List.from(widget.patients);
    sortedPatients.sort((a, b) => b.updated_at.compareTo(a.updated_at));
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.52,
          minHeight: 300,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF667eea).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏 - 带渐变背景
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_search,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '选择患者',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 14,
                        tooltip: '关闭',
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 内容区域
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 搜索框
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '搜索患者 (姓名/拼音/首字母/病历号)',
                          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        ),
                        onChanged: _filterPatients,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 患者列表标题
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: const Color(0xFF667eea),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '患者列表 (${_filteredPatients.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667eea),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 患者列表
                      Expanded(
                        child: _filteredPatients.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty ? '暂无患者数据' : '未找到匹配的患者',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '请尝试其他搜索关键词',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    children: [
                                      // 表头
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF667eea).withOpacity(0.1),
                                              const Color(0xFF667eea).withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    size: 16,
                                                    color: const Color(0xFF667eea),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    '姓名',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF667eea),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 16,
                                                    color: const Color(0xFF667eea),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    '最近就诊',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF667eea),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 表格内容
                                      Expanded(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _filteredPatients.length,
                                          itemBuilder: (context, index) {
                                            final patient = _filteredPatients[index];
                                            final lastVisitDate = DateFormat('yyyy-MM-dd')
                                                .format(patient.updated_at);

                                            return Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.transparent,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: () {
                                                    // 选择患者并关闭对话框
                                                    Navigator.of(context).pop(patient);
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 3,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.person,
                                                                size: 16,
                                                                color: const Color(0xFF667eea),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                patient.name,
                                                                style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 3,
                                                          child: Text(
                                                            lastVisitDate,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
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
            ],
          ),
        ),
      ),
    );
  }
}