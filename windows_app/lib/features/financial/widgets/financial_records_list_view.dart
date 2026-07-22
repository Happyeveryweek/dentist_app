import 'package:flutter/material.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../widgets/financial_table_header.dart';
import '../../../widgets/pagination_control.dart';

/// 财务记录列表视图
///
/// 包含患者模式和记录模式的列表渲染逻辑
class FinancialRecordsListView extends StatelessWidget {
  final String displayMode;
  final List<Map<String, dynamic>> financialItemsWithDetails;
  final ScrollController horizontalScrollController;
  final int totalRecords;
  final int currentPage;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final List<Map<String, dynamic>> Function() getPagedData;
  final Patient? Function(int) getPatientById;
  final double Function(int) getPatientTotalReceivable;
  final DateTime? Function(int) getPatientLastFinancialUpdateDate;
  final Widget Function(Patient, FinancialRecord, double, DateTime?,
      {double? receivedSum, double? processingSum}) buildFinancialCard;
  final Widget Function(Patient, FinancialRecord, FinancialItem)
      buildFinancialItemCard;

  const FinancialRecordsListView({
    Key? key,
    required this.displayMode,
    required this.financialItemsWithDetails,
    required this.horizontalScrollController,
    required this.totalRecords,
    required this.currentPage,
    required this.pageSize,
    required this.onPageChanged,
    required this.getPagedData,
    required this.getPatientById,
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

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: pagedData.length,
                            itemBuilder: (context, index) {
                              final data = pagedData[index];
                              final patient = data['patient'] as Patient;
                              final record = data['record'] as FinancialRecord;
                              final totalCost = data['totalCost'] as double? ??
                                  getPatientTotalReceivable(record.patientId);
                              final receivedSum =
                                  data['receivedSum'] as double?;
                              final processingSum =
                                  data['processingSum'] as double?;
                              final lastFinancialUpdateDate =
                                  data['lastFinancialUpdateDate']
                                          as DateTime? ??
                                      getPatientLastFinancialUpdateDate(
                                          record.patientId);
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
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: financialItemsWithDetails.length,
                                  itemBuilder: (context, index) {
                                    final data =
                                        financialItemsWithDetails[index];
                                    final item = data['item'] as FinancialItem;
                                    final patientId = data['patient_id'] as int;

                                    final record = FinancialRecord(
                                      id: item.financialRecordId,
                                      patientId: patientId,
                                      totalQuantity: 0,
                                      notes: data['record_notes'] as String?,
                                      createdAt: item.createdAt,
                                      updatedAt: item.updatedAt,
                                    );
                                    final patient = getPatientById(patientId);
                                    final displayPatient = patient ??
                                        Patient.placeholderForFinancialRecord(
                                          patientId: patientId,
                                          recordId: record.id,
                                          createdAt: record.createdAt,
                                        );

                                    return buildFinancialItemCard(
                                        displayPatient, record, item);
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
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: financialItemsWithDetails.length,
                          itemBuilder: (context, index) {
                            final data = financialItemsWithDetails[index];
                            final item = data['item'] as FinancialItem;
                            final patientId = data['patient_id'] as int;

                            final record = FinancialRecord(
                              id: item.financialRecordId,
                              patientId: patientId,
                              totalQuantity: 0,
                              notes: data['record_notes'] as String?,
                              createdAt: item.createdAt,
                              updatedAt: item.updatedAt,
                            );
                            final patient = getPatientById(patientId);
                            final displayPatient = patient ??
                                Patient.placeholderForFinancialRecord(
                                  patientId: patientId,
                                  recordId: record.id,
                                  createdAt: record.createdAt,
                                );

                            return buildFinancialItemCard(
                                displayPatient, record, item);
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
          PaginationControl(
            currentPage: currentPage,
            pageSize: pageSize,
            totalRecords: totalRecords,
            onPageChanged: onPageChanged,
          ),
      ],
    );
  }
}
