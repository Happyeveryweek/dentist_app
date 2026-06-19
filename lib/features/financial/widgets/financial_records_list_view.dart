import 'package:flutter/material.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../widgets/financial_table_header.dart';
import '../widgets/financial_card.dart';
import '../widgets/financial_item_card.dart';
import './financial_pagination.dart';

/// 财务记录列表视图
/// 
/// 包含患者模式和记录模式的列表渲染逻辑
class FinancialRecordsListView extends StatelessWidget {
  final String displayMode;
  final List<Map<String, dynamic>> financialItemsWithDetails;
  final ScrollController horizontalScrollController;
  final int totalRecords;
  final int currentPage;
  final int totalPages;
  final int recordsPerPage;
  final TextEditingController pageJumpController;
  final Function(int) onGoToPage;
  final VoidCallback onGoToPreviousPage;
  final VoidCallback onGoToNextPage;
  final List<Map<String, dynamic>> Function() getPagedData;
  final Future<Patient?> Function(int) getPatientByIdAsync;
  final double Function(int) getPatientTotalReceivable;
  final DateTime? Function(int) getPatientLastFinancialUpdateDate;
  final Widget Function(Patient, FinancialRecord, double, DateTime?, {double? receivedSum, double? processingSum}) buildFinancialCard;
  final Widget Function(Patient, FinancialRecord, FinancialItem) buildFinancialItemCard;

  const FinancialRecordsListView({
    Key? key,
    required this.displayMode,
    required this.financialItemsWithDetails,
    required this.horizontalScrollController,
    required this.totalRecords,
    required this.currentPage,
    required this.totalPages,
    required this.recordsPerPage,
    required this.pageJumpController,
    required this.onGoToPage,
    required this.onGoToPreviousPage,
    required this.onGoToNextPage,
    required this.getPagedData,
    required this.getPatientByIdAsync,
    required this.getPatientTotalReceivable,
    required this.getPatientLastFinancialUpdateDate,
    required this.buildFinancialCard,
    required this.buildFinancialItemCard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

              if (displayMode == 'patient') {
                // 患者模式：不需要横向滚动
                return Column(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final pagedData = getPagedData();
                          print('📋 渲染按患者显示列表(分页后): ${pagedData.length} 条, 当前页=$currentPage/$totalPages');
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: pagedData.length,
                            itemBuilder: (context, index) {
                              final data = pagedData[index];
                              final patient = data['patient'] as Patient;
                              final record = data['record'] as FinancialRecord;
                              final totalCost = data['totalCost'] as double? ?? getPatientTotalReceivable(record.patientId);
                              final receivedSum = data['receivedSum'] as double?;
                              final processingSum = data['processingSum'] as double?;
                              final lastFinancialUpdateDate = data['lastFinancialUpdateDate'] as DateTime? ?? getPatientLastFinancialUpdateDate(record.patientId);
                              return buildFinancialCard(
                                patient,
                                record,
                                totalCost,
                                lastFinancialUpdateDate,
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
                  controller: horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: minTableWidth,
                      child: Column(
                        children: [
                          // 表头
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const FinancialTableHeader(),
                          ),
                          const SizedBox(height: 8),

                          // 记录列表
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                print('📋 渲染按收费记录显示列表: ${financialItemsWithDetails.length} 条记录');
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: financialItemsWithDetails.length,
                                  itemBuilder: (context, index) {
                                    final data = financialItemsWithDetails[index];
                                    final item = data['item'] as FinancialItem;
                                    final patientId = data['patient_id'] as int;

                                    return FutureBuilder<Patient?>(
                                      future: getPatientByIdAsync(patientId),
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

                                        return buildFinancialItemCard(patient, record, item);
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
                    child: const FinancialTableHeader(),
                  ),
                  const SizedBox(height: 8),

                  // 记录列表
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        print('📋 渲染按收费记录显示列表: ${financialItemsWithDetails.length} 条记录');
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: financialItemsWithDetails.length,
                          itemBuilder: (context, index) {
                            final data = financialItemsWithDetails[index];
                            final item = data['item'] as FinancialItem;
                            final patientId = data['patient_id'] as int;

                            return FutureBuilder<Patient?>(
                              future: getPatientByIdAsync(patientId),
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

                                return buildFinancialItemCard(patient, record, item);
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
        if (totalRecords > 0)
          FinancialPagination(
            currentPage: currentPage,
            totalPages: totalPages,
            totalRecords: totalRecords,
            recordsPerPage: recordsPerPage,
            pageJumpController: pageJumpController,
            onGoToPage: onGoToPage,
            onGoToPreviousPage: onGoToPreviousPage,
            onGoToNextPage: onGoToNextPage,
          ),
      ],
    );
  }
}
