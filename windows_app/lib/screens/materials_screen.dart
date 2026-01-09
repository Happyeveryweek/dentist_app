import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/material.dart' as material_models;
import '../providers/material_provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../utils/dental_materials_init.dart';
import '../widgets/unified_search_field.dart';
import '../widgets/success_toast.dart';
import '../widgets/mysql_connection_warning.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({Key? key}) : super(key: key);

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List<material_models.MaterialInfo> _materials = [];
  List<material_models.MaterialInfo> _filteredMaterials = [];
  List<material_models.MaterialInfo> _displayedMaterials = []; // 当前页面显示的材料
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedType = '全部'; // 新增：选中的材料类型
  bool _isTypeHover = false; // 类型筛选悬停态
  late TextEditingController _searchController;
  late TextEditingController _pageJumpController;

  // 分页相关变量
  int _currentPage = 1;
  final int _materialsPerPage = 10;
  int _totalMaterials = 0;
  int _totalPages = 0;

  // 新增：材料类型列表
  final List<String> _materialTypes = [
    '全部',
    '药品',
    '局部麻醉药',
    '消毒用品',
    '一次性用品',
    '牙科材料',
    '牙科器械',
    '根管治疗器械',
    '牙科耗材',
    '正畸材料',
    '口腔护理用品',
    '防护用品',
    '办公用品',
    '其他',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _pageJumpController = TextEditingController();
    
    // 确保初始状态没有错误
    _hasError = false;
    _errorMessage = '';
    
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查材料提供者中的刷新标志
    final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
    if (materialProvider.materialsNeedRefresh) {
      // 如果材料数据需要刷新，则重新加载
      _loadData();
      // 重置刷新标志
      materialProvider.resetMaterialsRefreshFlag();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageJumpController.dispose();
    super.dispose();
  }

  // 尝试修复可能的编码混淆：有时数据库以 UTF-8 存储字节，但被当作 Latin1/单字节直接构造为 String 导致乱码
  // 策略：如果原始字符串不包含中文但对其 codeUnits 使用 utf8.decode 后包含中文，则返回解码后的结果
  String _fixMaybeDecoded(String? s) {
    if (s == null || s.isEmpty) return s ?? '';
    final original = s;
    final cjkRe = RegExp(r'[\u4e00-\u9fff]');
    final origHasCJK = cjkRe.hasMatch(original);
    if (origHasCJK) return original;

    try {
      final decoded = utf8.decode(original.codeUnits, allowMalformed: true);
      final decodedHasCJK = cjkRe.hasMatch(decoded);
      if (decodedHasCJK) return decoded;
    } catch (e) {
      // ignore
    }
    return original;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = ''; // 确保错误消息被清空
    });

    try {
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      final materials = await materialProvider.getAllMaterials();
      
      // 不再自动初始化材料，只在用户主动点击时才执行
      setState(() {
        _materials = materials;
        _filteredMaterials = materials;
        _totalMaterials = materials.length;
        _totalPages = (materials.length / _materialsPerPage).ceil();
        _currentPage = 1; // 重置到第一页
        _isLoading = false;
        _hasError = false; // 确保成功时错误状态为false
        _errorMessage = ''; // 确保成功时错误消息为空
      });
      
      // 更新当前页面显示的数据
      _updateDisplayedMaterials();
      
      // 如果当前页超出范围，调整到最后一页
      if (_currentPage > _totalPages && _totalPages > 0) {
        _currentPage = _totalPages;
        _updateDisplayedMaterials();
      }
      
      // 打印调试信息
      print('材料数据加载成功，错误状态已重置: _hasError=$_hasError, _errorMessage="$_errorMessage"');
      
      // 额外确保错误状态被重置
      if (_hasError || _errorMessage.isNotEmpty) {
        print('检测到错误状态仍然存在，强制重置...');
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });
        print('强制重置后错误状态: _hasError=$_hasError, _errorMessage="$_errorMessage"');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '加载材料数据失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 初始化默认材料数据
  Future<void> _initializeDefaultMaterials(MaterialProvider materialProvider) async {
    try {
      print('开始初始化默认材料数据...');
      
      // 获取默认材料列表
      final defaultMaterials = DentalMaterialsInit.getDefaultMaterials();
      print('准备添加 ${defaultMaterials.length} 种默认材料...');
      
      // 检查是否已经有材料数据
      final existingMaterials = await materialProvider.getAllMaterials();
      print('现有材料数量: ${existingMaterials.length}');
      
      if (existingMaterials.isNotEmpty) {
        print('检测到现有材料数据，开始清空...');
        
        // 安全清空现有材料（不影响患者材料）
        final clearSuccess = await materialProvider.clearAllDentalMaterials();
        if (!clearSuccess) {
          print('清空现有材料失败，但继续执行初始化...');
          // 继续执行，不中断流程
        } else {
          print('现有材料清空成功');
        }
        
        // 验证清空结果
        final afterClear = await materialProvider.getAllMaterials();
        print('清空后材料数量: ${afterClear.length}');
      }
      
      print('开始批量添加默认材料...');
      int successCount = 0;
      int failCount = 0;
      
      // 批量添加材料，使用事务处理
      for (int i = 0; i < defaultMaterials.length; i++) {
        final material = defaultMaterials[i];
        try {
          await materialProvider.addMaterial(material);
          successCount++;
          
          // 每添加50个材料打印一次进度
          if ((i + 1) % 50 == 0) {
            print('进度: ${i + 1}/${defaultMaterials.length} 已添加');
          }
        } catch (e, stackTrace) {
          print('添加材料 ${material.materialName} 失败: $e');
          print('错误堆栈: $stackTrace');
          failCount++;
          // 继续添加下一个材料，不中断整个流程
        }
      }
      
      print('默认材料初始化完成: 成功 $successCount 个，失败 $failCount 个');
      
      // 验证最终添加结果
      final finalMaterials = await materialProvider.getAllMaterials();
      print('最终材料数量: ${finalMaterials.length}');
      
      // 检查MySQL模式下ID是否从1开始
      if (finalMaterials.isNotEmpty) {
        final firstMaterial = finalMaterials.first;
        print('第一个材料的ID: ${firstMaterial.id}');
        
        // 验证ID连续性
        final ids = finalMaterials.map((m) => m.id).toList()..sort();
        bool isContinuous = true;
        for (int i = 0; i < ids.length; i++) {
          if (ids[i] != i + 1) {
            isContinuous = false;
            break;
          }
        }
        print('ID连续性检查: ${isContinuous ? "通过" : "不通过"}');
      }
      
      // 标记需要刷新材料列表
      materialProvider.markMaterialsNeedRefresh();
      
    } catch (e, stackTrace) {
      print('初始化默认材料过程中出现异常: $e');
      print('错误堆栈: $stackTrace');
      // 不重新抛出异常，避免生命周期问题
    }
  }

  

    /// 显示初始化确认对话框
  Future<void> _showInitializeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 防止误触关闭
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.orange.shade50,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_backup_restore_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '初始化默认材料',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 内容区域
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.orange.shade600,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '此操作将添加304种常用的牙医材料到数据库中，包括：\n\n• 药品类（抗生素、止痛药等）\n• 局部麻醉药\n• 消毒用品\n• 一次性用品\n• 牙科材料\n• 牙科器械（探针、镊子、刮匙等）\n• 根管治疗器械（各种型号的根管锉、扩大针、拔髓针）\n• 牙科耗材（各种型号的车针、牙胶尖等）\n• 正畸材料（各种尺寸的弓丝、结扎丝）\n• 口腔护理用品\n• 防护用品\n• 办公用品\n\n⚠️ 重要提醒：此操作将先清空所有现有牙科材料数据，然后重新初始化！\n\n✅ 安全提示：此操作不会影响患者材料及其图片数据，患者材料将完整保留。\n\n请确保您已经备份了重要的牙科材料数据。',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade800,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 按钮栏
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => _startInitialization(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        '开始初始化',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  /// 开始初始化流程
  Future<void> _startInitialization(BuildContext dialogContext) async {
    // 关闭确认对话框
    Navigator.of(dialogContext).pop(true);
    
    // 显示初始化进度对话框
    _showInitializationProgressDialog();
    
    try {
      // 执行初始化
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      await _initializeDefaultMaterials(materialProvider);
      
      // 重新加载数据
      if (mounted) {
        await _loadData();
        
        // 重置错误状态
        setState(() {
          _hasError = false;
          _errorMessage = '';
        });
        
        // 关闭进度对话框
        _closeInitializationProgressDialog();
        
        // 显示成功提示
        SuccessToastManager.show(context, message: '材料数据初始化完成！');
      }
    } catch (e) {
      print('材料数据初始化过程中出现异常: $e');
      
      // 关闭进度对话框
      _closeInitializationProgressDialog();
      
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 显示初始化进度对话框
  void _showInitializationProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 加载动画
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                ),
              ),
              const SizedBox(height: 24),
              
              // 标题
              Text(
                '正在初始化材料数据...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // 描述
              Text(
                '请稍候，系统正在添加304种默认材料到数据库中。\n此过程可能需要几秒钟时间。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 关闭初始化进度对话框
  void _closeInitializationProgressDialog() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _filterMaterials() {
    setState(() {
      _filteredMaterials = _materials.where((material) {
        // 类型筛选
        bool typeMatch = _selectedType == '全部' || material.materialType == _selectedType;
        
        // 搜索关键词筛选
        bool searchMatch = _searchQuery.isEmpty;
        if (!searchMatch) {
          final query = _searchQuery.toLowerCase();
          searchMatch = material.materialName.toLowerCase().contains(query) ||
                       (material.materialCode?.toLowerCase().contains(query) ?? false) ||
                       (material.supplier?.toLowerCase().contains(query) ?? false) ||
                       (material.description?.toLowerCase().contains(query) ?? false);
        }
        
        return typeMatch && searchMatch;
      }).toList();
      
      // 更新分页信息
      _totalMaterials = _filteredMaterials.length;
      _totalPages = (_totalMaterials / _materialsPerPage).ceil();
      _currentPage = 1; // 重置到第一页
      
      // 更新当前页面显示的数据
      _updateDisplayedMaterials();
    });
  }

  // 更新当前页面显示的材料
  void _updateDisplayedMaterials() {
    final startIndex = (_currentPage - 1) * _materialsPerPage;
    final endIndex = startIndex + _materialsPerPage;
    
    setState(() {
      _displayedMaterials = _filteredMaterials.sublist(
        startIndex,
        endIndex > _filteredMaterials.length ? _filteredMaterials.length : endIndex,
      );
    });
  }

  // 跳转到指定页面
  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
      });
      _updateDisplayedMaterials();
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
    if (_currentPage < _totalPages) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _showMaterialDetail(material_models.MaterialInfo material) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 600,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: DentalColors.primaryGradient,
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        DentalIcons.pills,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '材料详情',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              
              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 材料基本信息
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: DentalColors.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: DentalColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                DentalIcons.pills,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    material.materialName,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (material.materialCode != null) ...[
                                    _buildDetailRow(Icons.qr_code_rounded, '编码', material.materialCode!, Colors.blue.shade700),
                                    const SizedBox(height: 4),
                                  ],
                                  _buildDetailRow(Icons.straighten_rounded, '单位', material.unit, Colors.blue.shade700),
                                  const SizedBox(height: 4),
                                  _buildDetailRow(Icons.category_rounded, '材料类型', material.materialType, Colors.purple.shade700),
                                  const SizedBox(height: 4),
                                  _buildDetailRow(Icons.attach_money_rounded, '默认价格', '¥${material.defaultPrice.toStringAsFixed(0)}', Colors.green.shade700),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 详细信息
                      if (material.supplier != null || material.description != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.grey.shade50, Colors.grey.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (material.supplier != null) ...[
                                _buildDetailRow(Icons.business_rounded, '供应商', material.supplier!, Colors.orange.shade700),
                                if (material.description != null) const SizedBox(height: 16),
                              ],
                                  if (material.description != null) ...[
                                _buildDetailRow(Icons.description_rounded, '描述', _fixMaybeDecoded(material.description), Colors.grey.shade700),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // 创建时间
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade50, Colors.green.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: _buildDetailRow(
                          Icons.calendar_today_rounded,
                          '创建时间',
                          DateFormat('yyyy-MM-dd HH:mm').format(material.createdAt),
                          Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 按钮栏
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      child: const Text(
                        '关闭',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showMaterialDialog(material);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('编辑'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
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

  Future<void> _showMaterialDialog([material_models.MaterialInfo? material]) async {
    final isEditing = material != null;
    final nameController = TextEditingController(text: material?.materialName ?? '');
    
    // 获取下一个材料编码（仅在添加时）
    String nextCode = '';
    if (!isEditing) {
      try {
        final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
        nextCode = await materialProvider.getNextMaterialCode();
      } catch (e) {
        nextCode = 'M001';
      }
    }
    
    final codeController = TextEditingController(text: material?.materialCode ?? nextCode);
    final priceController = TextEditingController(text: material?.defaultPrice.toString() ?? '0.0');
    final supplierController = TextEditingController(text: material?.supplier ?? '');
  final descriptionController = TextEditingController(text: _fixMaybeDecoded(material?.description ?? ''));
    final quantityController = TextEditingController(text: '1'); // 添加数量控制器
    
    // 预设的单位选项
    final List<String> unitOptions = [
      '个', '瓶', '把', '盒', '包', '支', '片', '克', '毫升', '米', '厘米',
      '箱', '卷', '袋', '套', '件', '条', '块', '粒', '颗', '根', '张',
      '台', '架', '组', '对', '双', '副', '只', '枚', '筒', '罐', '桶'
    ];
    String selectedUnit = material?.unit ?? '个';
    final unitController = TextEditingController(text: selectedUnit);
    
    // 材料类型选择
    String selectedType = material?.materialType ?? '其他';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 600,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: DentalColors.primaryGradient,
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            isEditing ? '编辑材料' : '添加材料',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                  ),
                  
                  // 表单内容
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 材料名称
                          _buildModernFormField(
                            controller: nameController,
                            label: '材料名称',
                            hint: '请输入材料名称',
                            icon: Icons.inventory_rounded,
                            isRequired: true,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 材料编码
                          _buildModernFormField(
                            controller: codeController,
                            label: '材料编码',
                            hint: '例如: M001',
                            icon: Icons.qr_code_rounded,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 材料类型
                          _buildModernDropdownField(
                            value: selectedType,
                            label: '材料类型',
                            icon: Icons.category_rounded,
                            items: _materialTypes.where((type) => type != '全部').toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedType = value;
                                });
                              }
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 数量和单位（调整位置：数量在前，单位在后）
                          Row(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Expanded(
                               child: _buildModernFormField(
                                 controller: quantityController,
                                 label: '数量',
                                 hint: '例如: 1',
                                 icon: Icons.numbers_rounded,
                                 keyboardType: TextInputType.number,
                               ),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Row(
                                     children: [
                                       Icon(Icons.straighten_rounded, size: 20, color: DentalColors.primary),
                                       const SizedBox(width: 8),
                                       Text(
                                         '单位',
                                         style: TextStyle(
                                           fontSize: 16,
                                           fontWeight: FontWeight.w600,
                                           color: DentalColors.onSurface,
                                         ),
                                       ),
                                     ],
                                   ),
                                   const SizedBox(height: 8),
                                   _buildModernUnitDropdown(
                                     controller: unitController,
                                     options: unitOptions,
                                     onSelected: (value) {
                                       setDialogState(() {
                                         unitController.text = value;
                                       });
                                     },
                                   ),
                                 ],
                               ),
                             ),
                           ],
                         ),
                          
                          const SizedBox(height: 20),
                          
                          // 默认价格
                          _buildModernFormField(
                            controller: priceController,
                            label: '默认价格',
                            hint: '0.00',
                            icon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            prefix: '¥',
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 供应商
                          _buildModernFormField(
                            controller: supplierController,
                            label: '供应商',
                            hint: '请输入供应商名称',
                            icon: Icons.business_rounded,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 描述
                          _buildModernFormField(
                            controller: descriptionController,
                            label: '描述',
                            hint: '请输入材料描述信息',
                            icon: Icons.description_rounded,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 按钮栏
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          child: const Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('请输入材料名称'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            try {
                              final price = double.tryParse(priceController.text) ?? 0.0;
                              
                              // 修复：手动添加材料时自动生成编码
                              String? materialCode;
                              if (isEditing) {
                                // 编辑模式：使用现有编码或用户输入的编码
                                materialCode = codeController.text.trim().isEmpty ? null : codeController.text.trim();
                              } else {
                                // 新增模式：自动生成编码
                                if (codeController.text.trim().isEmpty) {
                                  // 用户没有输入编码，自动生成
                                  final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
                                  try {
                                    materialCode = await materialProvider.getNextMaterialCode();
                                  } catch (e) {
                                    print('自动生成材料编码失败: $e');
                                    // 如果自动生成失败，使用默认编码
                                    materialCode = 'M001';
                                  }
                                } else {
                                  // 用户输入了编码，使用用户输入的
                                  materialCode = codeController.text.trim();
                                }
                              }
                              
                              final newMaterial = material_models.MaterialInfo(
                                id: material?.id,
                                materialName: nameController.text.trim(),
                                materialCode: materialCode, // 使用自动生成或用户输入的编码
                                materialType: selectedType,
                                unit: unitController.text,
                                defaultPrice: price,
                                supplier: supplierController.text.trim().isEmpty ? null : supplierController.text.trim(),
                                description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                              );

                              final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
                              bool success;
                              
                              if (isEditing) {
                                success = await materialProvider.updateMaterial(newMaterial);
                              } else {
                                final newId = await materialProvider.addMaterial(newMaterial);
                                success = newId != null && newId > 0;
                              }

                              if (success) {
                                Navigator.of(context).pop(true);
                                _loadData();
                                SuccessToastManager.show(context, message: isEditing ? '材料更新成功' : '材料添加成功');
                              } else {
                                SuccessToastManager.showError(context, message: '操作失败');
                              }
                            } catch (e) {
                              SuccessToastManager.showError(context, message: '操作失败: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DentalColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            isEditing ? '更新' : '添加',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  // 构建现代化表单字段
  Widget _buildModernFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    bool isReadOnly = false,
    TextInputType? keyboardType,
    String? prefix,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: DentalColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DentalColors.primary, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // 构建现代化下拉字段
  Widget _buildModernDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: DentalColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildModernDropdownContainer(
          value: value,
          items: items,
          onChanged: onChanged,
          hintText: '请选择$label',
        ),
      ],
    );
  }

  // 构建现代化下拉容器
  Widget _buildModernDropdownContainer({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    String? hintText,
    double? width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        initialValue: value,
        onSelected: onChanged,
        constraints: const BoxConstraints(maxHeight: 300, minWidth: 200),
        offset: const Offset(0, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        itemBuilder: (context) => [
          // 标题栏
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [DentalColors.primary.withOpacity(0.1), DentalColors.primary.withOpacity(0.05)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.list_rounded, size: 16, color: DentalColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '选择选项',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DentalColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 分割线
          const PopupMenuDivider(height: 1),
          // 选项列表
          ...items.map((item) {
            final isSelected = item == value;
            return PopupMenuItem<String>(
              value: item,
              height: 36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? DentalColors.primary.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? DentalColors.primary : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: isSelected ? DentalColors.primary : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 10, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? DentalColors.primary : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? (hintText ?? '请选择') : value,
                  style: TextStyle(
                    fontSize: 15,
                    color: value.isEmpty ? Colors.grey[500] : Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建现代化单位下拉框
  Widget _buildModernUnitDropdown({
    required TextEditingController controller,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 输入框部分
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '例如: 个',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // 下拉按钮部分
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: Colors.grey[600],
              ),
            ),
            constraints: const BoxConstraints(maxHeight: 240, minWidth: 180),
            offset: const Offset(0, 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            onSelected: onSelected,
            itemBuilder: (context) => [
              // 标题栏
              PopupMenuItem<String>(
                enabled: false,
                height: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        '常用单位',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${options.length}个',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 分割线
              const PopupMenuDivider(height: 1),
              // 选项列表
              ...options.map((unit) {
                final isSelected = controller.text == unit;
                
                return PopupMenuItem<String>(
                  value: unit,
                  height: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected ? Border.all(color: Colors.blue.shade300, width: 1) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.blue : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 10, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? Colors.blue.shade700 : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  // 构建类型筛选下拉框
  Widget _buildModernTypeDropdown({
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isTypeHover = true),
      onExit: (_) => setState(() => _isTypeHover = false),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (_selectedType != '全部' || _isTypeHover) 
                ? DentalColors.primary.withOpacity(0.6) 
                : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: [
            if (_isTypeHover)
              BoxShadow(
                color: DentalColors.primary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: PopupMenuButton<String>(
          initialValue: value,
          onSelected: onChanged,
          constraints: const BoxConstraints(maxHeight: 320, minWidth: 240),
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 12,
          itemBuilder: (context) => [
            // 标题栏
            PopupMenuItem<String>(
              enabled: false,
              height: 44,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: DentalColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.category_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text(
                      '材料类型',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}项',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 分割线
            const PopupMenuDivider(height: 1),
            // 选项列表
            ...items.map((type) {
              final isSelected = type == value;
              return PopupMenuItem<String>(
                value: type,
                height: 38,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? DentalColors.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSelected ? DentalColors.primaryGradient : null,
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? DentalColors.primary : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DentalColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '已选',
                            style: TextStyle(
                              fontSize: 10,
                              color: DentalColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: (_selectedType != '全部' || _isTypeHover) 
                      ? DentalColors.primary 
                      : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedType,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: (_selectedType != '全部' || _isTypeHover) 
                        ? DentalColors.primary 
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: (_selectedType != '全部' || _isTypeHover) 
                      ? DentalColors.primary 
                      : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建详情行
  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteMaterial(material_models.MaterialInfo material) async {
    final confirmed = await DeleteConfirmDialogManager.showMaterialDelete(
      context,
      materialName: material.materialName,
    );

    if (confirmed == true) {
      try {
        final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
        final success = await materialProvider.deleteMaterial(material.id!);

        if (success) {
          _loadData();
          DeleteSuccessToastManager.show(context, message: '材料删除成功');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMaterialCard(material_models.MaterialInfo material) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPurpleTheme = Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return _HoverableMaterialCard(
      onTap: () => _showMaterialDetail(material),
      isPurpleTheme: isPurpleTheme,
      child: Row(
              children: [
                // 材料图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPurpleTheme ? AppTheme.purpleColor : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    DentalIcons.pills,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 材料信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 第一行：材料名称
                      Text(
                        material.materialName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // 第二行：价格、单位、类型标签
                      Row(
                        children: [
                          // 价格
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_money, size: 11, color: Colors.green[700]),
                                const SizedBox(width: 3),
                                Text(
                                  '¥${material.defaultPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 6),
                          
                          // 单位
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory, size: 11, color: Colors.blue[700]),
                                const SizedBox(width: 3),
                                Text(
                                  material.unit,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 6),
                          
                          // 类型
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.category_rounded, size: 11, color: Colors.purple[700]),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      material.materialType,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.purple[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // 供应商（如果有）
                          if (material.supplier != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.business, size: 11, color: Colors.orange[700]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        material.supplier!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange[700],
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
                
                // 操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactMaterialActionButton(
                      icon: Icons.visibility,
                      color: Colors.blue,
                      tooltip: '查看',
                      onPressed: () => _showMaterialDetail(material),
                    ),
                    const SizedBox(width: 6),
                    _buildCompactMaterialActionButton(
                      icon: Icons.edit,
                      color: Colors.orange,
                      tooltip: '编辑',
                      onPressed: () => _showMaterialDialog(material),
                    ),
                    const SizedBox(width: 6),
                    _buildCompactMaterialActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      tooltip: '删除',
                      onPressed: () => _deleteMaterial(material),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // 紧凑型材料操作按钮
  Widget _buildCompactMaterialActionButton({
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
                DentalIcons.pills,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '材料管理',
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
          // 刷新按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () async {
                await _loadData();
                // 使用公用成功提示组件
                SuccessToastManager.show(context, message: '数据已刷新');
              },
              tooltip: '刷新数据',
            ),
          ),
          // 初始化按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.white),
              onPressed: () => _showInitializeDialog(),
              tooltip: '初始化默认材料',
            ),
          ),
          // 添加按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () => _showMaterialDialog(),
              tooltip: '添加材料',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // MySQL连接状态检查
          Consumer<AppState>(
            builder: (context, appState, _) {
              if (!appState.isMySQLConnected) {
                return const MySQLConnectionWarning(moduleName: '材料管理');
              }
              return const SizedBox.shrink();
            },
          ),
          // 搜索栏和类型筛选（一行布局）
          Container(
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
              child: Row(
              children: [
                // 搜索栏 - 自适应长度
                Expanded(
                  child: UnifiedSearchField(
                    controller: _searchController,
                    labelText: '搜索材料',
                    hintText: '输入材料名称、编码、供应商或描述',
                    prefixIcon: Icons.search_rounded,
                    searchQuery: _searchQuery,
                    onChanged: (value) {
                      setState(() { _searchQuery = value; });
                      _filterMaterials();
                    },
                    onClear: () {
                      setState(() { _searchQuery = ''; });
                      _searchController.clear();
                      _filterMaterials();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 类型筛选器 - 靠右固定宽度
                Container(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_rounded, color: DentalColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('类型:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: DentalColors.onSurface)),
                      const SizedBox(width: 12),
                      _buildModernTypeDropdown(
                        value: _selectedType,
                        items: _materialTypes,
                        onChanged: (value) {
                          setState(() { _selectedType = value; });
                          _filterMaterials();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
          // 统计信息 - 紧凑版
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_rounded,
                    label: '材料总数',
                    value: _filteredMaterials.length.toString(),
                    color: DentalColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money_rounded,
                    label: '总价值',
                    value: '¥${_filteredMaterials.fold<double>(0.0, (sum, material) => sum + material.defaultPrice).toStringAsFixed(0)}',
                    color: DentalColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.category_rounded,
                    label: '类型数',
                    value: _filteredMaterials.map((m) => m.materialType).toSet().length.toString(),
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.business_rounded,
                    label: '供应商数',
                    value: _filteredMaterials.map((m) => m.supplier).where((s) => s != null).toSet().length.toString(),
                    color: DentalColors.warning,
                  ),
                ),
              ],
            ),
          ),
          
          // 分页信息显示
          
          const SizedBox(height: 16),
          
          
          
          // 材料列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_hasError && _errorMessage.isNotEmpty)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              '加载失败',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.red[300],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _filteredMaterials.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _searchQuery.isEmpty ? Icons.inventory_outlined : Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty ? '暂无材料数据' : '未找到匹配的材料',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_searchQuery.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '点击"添加材料"开始创建您的第一个材料',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _showMaterialDialog(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('添加材料'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // 材料列表
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _displayedMaterials.length,
                                  itemBuilder: (context, index) {
                                    return _buildMaterialCard(_displayedMaterials[index]);
                                  },
                                ),
                              ),
                              
                              // 分页控件
                              if (_totalPages > 1) _buildPagination(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
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
                    color: DentalColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建分页控件
  Widget _buildPagination() {
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
                const Icon(Icons.info_outline, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
                Text(
                  '每页 $_materialsPerPage 条 · 共 $_totalMaterials 条 / $_totalPages 页',
                  style: const TextStyle(
                    color: Colors.black87,
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
              color: DentalColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DentalColors.primary.withOpacity(0.12)),
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
                    style: TextStyle(
                      color: DentalColors.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                // 右段：确认（右圆角）
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
    if (icon != null) {
      // 箭头或首页按钮
      return IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        splashRadius: 20,
        color: isActive ? Theme.of(context).primaryColor : Colors.grey[400],
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
                color: isActive ? Theme.of(context).primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? Theme.of(context).primaryColor : Colors.grey[300]!,
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

// 可悬浮的材料卡片组件
class _HoverableMaterialCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool isPurpleTheme;
  final Widget child;

  const _HoverableMaterialCard({
    Key? key,
    required this.onTap,
    required this.isPurpleTheme,
    required this.child,
  }) : super(key: key);

  @override
  State<_HoverableMaterialCard> createState() => _HoverableMaterialCardState();
}

class _HoverableMaterialCardState extends State<_HoverableMaterialCard> {
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
                ? Color(0xFFE3F2FD)  // 淡蓝色
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