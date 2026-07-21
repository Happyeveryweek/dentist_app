import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../theme/theme_context_extensions.dart';

/// 公共患者选择对话框
///
/// 财务、预约等模块共用，通过 `showDialog<Patient>` 返回选中的患者。
/// 支持按姓名、拼音、首字母、病历号、电话搜索。
class PatientSelectionDialog extends StatefulWidget {
  final List<Patient> patients;

  const PatientSelectionDialog({Key? key, required this.patients})
      : super(key: key);

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
        final lowerQuery = query.toLowerCase();
        final queryNoSpace = lowerQuery.replaceAll(' ', '');
        _filteredPatients = widget.patients.where((patient) {
          // 姓名搜索
          final nameMatch = patient.name.toLowerCase().contains(lowerQuery);

          // 病历号搜索
          final medicalRecordMatch =
              patient.medicalRecordNumber?.toString().contains(query) ?? false;

          // 姓名拼音搜索（支持带空格和不带空格）
          final namePinyinMatch = patient.namePinyin
                  ?.toLowerCase()
                  .replaceAll(' ', '')
                  .contains(queryNoSpace) ??
              false;

          // 姓名拼音首字母搜索
          final nameInitialsMatch =
              patient.nameInitials?.toLowerCase().contains(lowerQuery) ?? false;

          // 电话搜索
          final phoneMatch =
              patient.mainPhone.toLowerCase().contains(lowerQuery);

          return nameMatch ||
              medicalRecordMatch ||
              namePinyinMatch ||
              nameInitialsMatch ||
              phoneMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 560,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.52,
          minHeight: 300,
        ),
        decoration: BoxDecoration(
          gradient: tokens.primaryHeaderGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: tokens.elevatedShadow,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.cardBackground.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tokens.primaryAccent.withValues(alpha: 0.1),
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
                  gradient: tokens.primaryHeaderGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_search,
                            color: colors.onPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '选择患者',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.onPrimary,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                                color: colors.shadow.withValues(alpha: 0.26),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.close,
                            color: colors.onPrimary, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 14,
                        tooltip: '关闭',
                        padding: const EdgeInsets.all(3),
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
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
                          hintText: '搜索患者 (姓名/拼音/首字母/病历号/电话)',
                          prefixIcon:
                              Icon(Icons.search, color: tokens.iconMuted),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.borderRadius),
                            borderSide: BorderSide(color: tokens.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.borderRadius),
                            borderSide: BorderSide(
                                color: tokens.primaryAccent, width: 2),
                          ),
                          filled: true,
                          fillColor: tokens.inputBackground,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                        ),
                        onChanged: _filterPatients,
                      ),

                      const SizedBox(height: 20),

                      // 患者列表标题
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: tokens.primaryAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '患者列表 (${_filteredPatients.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: tokens.primaryAccent,
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
                                      _searchQuery.isEmpty
                                          ? Icons.people_outline
                                          : Icons.search_off,
                                      size: 48,
                                      color: tokens.iconMuted,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? '暂无患者数据'
                                          : '未找到匹配的患者',
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '请尝试其他搜索关键词',
                                        style: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: tokens.cardBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: tokens.border),
                                  boxShadow: tokens.cardShadow,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    children: [
                                      // 表头
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: tokens.subtleHeaderGradient,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.badge_outlined,
                                                    size: 16,
                                                    color: tokens.primaryAccent,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '病历号',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          tokens.primaryAccent,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.person,
                                                    size: 16,
                                                    color: tokens.primaryAccent,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '姓名 / 电话',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          tokens.primaryAccent,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 16,
                                                    color: tokens.primaryAccent,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '最近就诊',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          tokens.primaryAccent,
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
                                            final patient =
                                                _filteredPatients[index];
                                            final lastVisitDate =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(patient.updatedAt);
                                            final phone =
                                                patient.mainPhone.isEmpty
                                                    ? '暂无电话'
                                                    : patient.mainPhone;
                                            final medicalRecordNumber = patient
                                                    .medicalRecordNumber
                                                    ?.toString() ??
                                                '未设置';

                                            return Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: index % 2 == 0
                                                    ? tokens.cardBackground
                                                    : tokens.mutedBackground,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.transparent,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  mouseCursor:
                                                      SystemMouseCursors.click,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  onTap: () {
                                                    // 选择患者并关闭对话框
                                                    Navigator.of(context)
                                                        .pop(patient);
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4,
                                                        horizontal: 16),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            medicalRecordNumber,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: tokens
                                                                  .textMuted,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 4,
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Icon(
                                                                Icons.person,
                                                                size: 16,
                                                                color: tokens
                                                                    .primaryAccent,
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      patient
                                                                          .name,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            2),
                                                                    Text(
                                                                      phone,
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color: tokens
                                                                            .textMuted,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            lastVisitDate,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: tokens
                                                                  .textMuted,
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
