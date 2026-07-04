import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../models/patient.dart';
import './patient_detail_screen.dart';

/// 筛选后的患者列表页面
/// 用于显示从统计图表点击后筛选出的患者列表
class FilteredPatientsScreen extends StatefulWidget {
  final List<Patient> patients;
  final String filterTitle;
  final String filterDescription;

  const FilteredPatientsScreen({
    Key? key,
    required this.patients,
    required this.filterTitle,
    required this.filterDescription,
  }) : super(key: key);

  @override
  State<FilteredPatientsScreen> createState() => _FilteredPatientsScreenState();
}

class _FilteredPatientsScreenState extends State<FilteredPatientsScreen> {
  int _currentPage = 1;
  final int _patientsPerPage = 10;

  List<Patient> _getCurrentPagePatients() {
    final startIndex = (_currentPage - 1) * _patientsPerPage;
    final endIndex = startIndex + _patientsPerPage;

    if (startIndex >= widget.patients.length) {
      return [];
    }

    return widget.patients.sublist(
      startIndex,
      endIndex > widget.patients.length ? widget.patients.length : endIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (widget.patients.length / _patientsPerPage).ceil();
    final displayTotalPages = totalPages > 0 ? totalPages : 1;
    final currentPagePatients = _getCurrentPagePatients();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.filterTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.filterDescription,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: context.tokens.cardBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
      ),
      body: widget.patients.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 64,
                    color: context.tokens.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无患者数据',
                    style: TextStyle(
                      fontSize: 18,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentPagePatients.length,
                    itemBuilder: (context, index) {
                      final patient = currentPagePatients[index];
                      return _buildPatientCard(context, patient);
                    },
                  ),
                ),
                _buildPagination(displayTotalPages),
              ],
            ),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient) {
    final patientName = patient.name;
    final patientGender = patient.gender;

    // 根据性别决定头像背景和图标颜色
    final Color avatarBgColor = patientGender == '女'
        ? const Color(0xFFF48FB1).withValues(alpha: 0.2)
        : context.tokens.infoContainer;
    final Color avatarTextColor =
        patientGender == '女' ? const Color(0xFFEC407A) : context.tokens.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(12),
          color: context.tokens.cardBackground,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PatientDetailScreen(patient: patient),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 左侧：头像
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        avatarBgColor,
                        avatarBgColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: avatarTextColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      patientName.isNotEmpty ? patientName[0] : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: avatarTextColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // 中间：患者信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 第一行：姓名 + 性别年龄标签
                      Row(
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 16,
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
                              color: avatarBgColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: avatarTextColor.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  patientGender == '女'
                                      ? Icons.female
                                      : Icons.male,
                                  size: 12,
                                  color: avatarTextColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${patient.age}岁',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: avatarTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 第二行：电话 + 首诊时间
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            patient.phone ?? '未设置',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.event,
                            size: 14,
                            color: context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('yyyy-MM-dd')
                                .format(patient.firstVisitDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      // 第三行：地址（如果有）
                      Builder(builder: (context) {
                        final patientAddress = patient.address;
                        if (patientAddress == null ||
                            patientAddress.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: context.colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    patientAddress,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 右侧：查看详情按钮
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: context.tokens.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    final String resultText =
        '每页 $_patientsPerPage 条 · 共 ${widget.patients.length} 条 / $totalPages 页';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: context.tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.tokens.elevatedShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左箭头
          _buildPaginationButton(
            icon: Icons.keyboard_arrow_left,
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
            isActive: _currentPage > 1,
          ),

          const SizedBox(width: 8),

          // 页码
          ...List.generate(
            totalPages > 5 ? 5 : totalPages,
            (index) {
              int pageNumber;
              if (totalPages <= 5) {
                pageNumber = index + 1;
              } else {
                if (_currentPage <= 3) {
                  pageNumber = index + 1;
                } else if (_currentPage >= totalPages - 2) {
                  pageNumber = totalPages - 4 + index;
                } else {
                  pageNumber = _currentPage - 2 + index;
                }
              }

              bool isCurrentPage = pageNumber == _currentPage;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 0,
                  child: InkWell(
                    onTap: isCurrentPage
                        ? null
                        : () {
                            setState(() {
                              _currentPage = pageNumber;
                            });
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isCurrentPage
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.tokens.primaryAccent,
                                  context.tokens.primaryAccent.withValues(alpha: 0.8),
                                ],
                              )
                            : null,
                        color: isCurrentPage ? null : context.tokens.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrentPage
                            ? null
                            : Border.all(
                                color: context.tokens.border,
                                width: 1.5,
                              ),
                        boxShadow: isCurrentPage
                            ? [
                                BoxShadow(
                                  color: context.tokens.primaryAccent
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Text(
                        '$pageNumber',
                        style: TextStyle(
                          color: isCurrentPage
                              ? Colors.white
                              : context.colors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          // 右箭头
          _buildPaginationButton(
            icon: Icons.keyboard_arrow_right,
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : null,
            isActive: _currentPage < totalPages,
          ),

          const SizedBox(width: 16),

          // 首页按钮
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.tokens.primaryAccent.withValues(alpha: 0.8),
                  context.tokens.primaryAccent.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: context.tokens.primaryAccent.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentPage = 1;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.home,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // 页面信息
          Container(
            margin: const EdgeInsets.only(left: 32),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: context.tokens.subtleHeaderGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.tokens.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: context.tokens.primaryAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Icon(Icons.info_outline,
                    size: 16,
                    color: context.tokens.primaryAccent.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                Text(
                  resultText,
                  style: TextStyle(
                    color: context.colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required Function()? onPressed,
    required bool isActive,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.tokens.primaryAccent,
                      context.tokens.primaryAccent.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: isActive ? null : context.tokens.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? context.tokens.primaryAccent.withValues(alpha: 0.3)
                  : context.tokens.border,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: context.tokens.primaryAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : context.tokens.textMuted,
            size: 24,
          ),
        ),
      ),
    );
  }
}
