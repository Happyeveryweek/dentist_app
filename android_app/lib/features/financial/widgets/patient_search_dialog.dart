import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/models/database_models.dart';
import '../../../utils/app_logger.dart';

/// 患者搜索对话框
/// 职责：显示患者搜索对话框，支持按姓名、拼音搜索
class PatientSearchDialog extends StatefulWidget {
  const PatientSearchDialog({super.key});

  @override
  State<PatientSearchDialog> createState() => _PatientSearchDialogState();
}

class _PatientSearchDialogState extends State<PatientSearchDialog> {
  final _searchController = TextEditingController();
  List<Patient> _allPatients = []; // 存储所有患者数据（使用 Patient 对象）
  List<Patient> _filteredPatients = []; // 过滤后的患者数据（Patient 对象）
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 从 PatientProvider 加载患者数据（使用 provider 的缓存与动态连接）
  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      final patients = await patientProvider.getAllPatients();
      _allPatients = patients;
      // 初始化过滤后的列表
      _filteredPatients = List.from(_allPatients);
    } catch (e) {
      AppLogger.info('加载患者数据失败: $e');
      _allPatients = [];
      _filteredPatients = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 过滤患者列表
  void _filterPatients(String query) {
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        // 如果搜索框为空，显示所有患者，按更新时间倒序排列
        _filteredPatients = List.from(_allPatients)..sort((a, b) {
          final aDate = a.updatedAt;
          final bDate = b.updatedAt;
          return bDate.compareTo(aDate);
        });
      } else {
        final qLower = query.toLowerCase();
        _filteredPatients =
            _allPatients.where((patient) {
                final name = patient.name.toLowerCase();
                final id = (patient.id ?? 0).toString();
                return name.contains(qLower) ||
                    id.contains(query) ||
                    _containsPinyinInitials(name, qLower);
              }).toList()
              ..sort((a, b) {
                final aDate = a.updatedAt;
                final bDate = b.updatedAt;
                return bDate.compareTo(aDate);
              });
      }
    });
  }

  /// 检查是否包含拼音首字母
  bool _containsPinyinInitials(String name, String query) {
    if (query.isEmpty || name.isEmpty) return false;

    try {
      // 获取姓名的拼音首字母
      final nameInitials = PinyinHelper.getShortPinyin(name).toLowerCase();
      // 获取姓名的完整拼音（无空格）
      final namePinyin =
          PinyinHelper.getPinyinE(
            name,
            separator: '',
            format: PinyinFormat.WITHOUT_TONE,
          ).toLowerCase();

      final queryLower = query.toLowerCase();

      // 支持多种搜索方式：
      // 1. 拼音首字母匹配 (例如: "zs" 匹配 "张三")
      // 2. 完整拼音匹配 (例如: "zhangsan" 匹配 "张三")
      // 3. 部分拼音匹配 (例如: "zhang" 匹配 "张三")
      return nameInitials.contains(queryLower) ||
          namePinyin.contains(queryLower) ||
          name.toLowerCase().contains(queryLower);
    } catch (e) {
      // 如果拼音转换失败，回退到简单的字符匹配
      return name.toLowerCase().contains(query.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // 标题栏 - 更紧凑的设计
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_search, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '选择患者',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),

            // 搜索框 - 更紧凑的设计
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索患者姓名或拼音',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _filterPatients('');
                            },
                          )
                          : null,
                ),
                onChanged: _filterPatients,
              ),
            ),

            // 患者列表标题 - 减少padding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '患者列表 (${_filteredPatients.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // 患者列表表头 - 减少padding，更紧凑
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.grey[600], size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '姓名',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey[600],
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '最近就诊',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 患者列表 - 减少行间距，更紧凑，与表头对齐
            Expanded(
              child:
                  _isLoading
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '加载患者中...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                      : _filteredPatients.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty
                                  ? Icons.people
                                  : Icons.search,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? '暂无患者数据' : '没有找到匹配的患者',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '请尝试其他搜索关键词',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 1),
                            child: InkWell(
                              onTap: () {
                                final patientId = patient.id;
                                if (patientId == null || patientId == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('无效的患者ID，无法选择'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(context).pop(patient);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    // 姓名列 - 与表头对齐
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color:
                                                Theme.of(context).primaryColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            patient.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 最近就诊列 - 与表头对齐
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        DateFormat('yyyy-MM-dd').format(
                                          patient.updatedAt,
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),

            // 底部按钮 - 减少padding
            // 已移除底部取消按钮，患者列表将直接延伸到对话框底部
          ],
        ),
      ),
    );
  }
}
