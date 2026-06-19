import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class PatientDentalConditionEmptyState extends StatelessWidget {
  const PatientDentalConditionEmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Text('暂无牙齿状况记录'),
    );
  }
}

class PatientDentalConditionList extends StatelessWidget {
  final List<Widget> chartRows;
  final ScrollController scrollController;
  final double maxHeight;

  const PatientDentalConditionList({
    Key? key,
    required this.chartRows,
    required this.scrollController,
    required this.maxHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                const Icon(
                  Icons.medical_services,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '牙齿状况',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              minWidth: double.infinity,
            ),
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: chartRows.length > 3,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: chartRows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientDentalChartCard extends StatelessWidget {
  final String dateStr;
  final String createdByDoctor;
  final String chart1TopLeft;
  final String chart1TopRight;
  final String chart1BottomLeft;
  final String chart1BottomRight;
  final String chart1Note;
  final String chart2TopLeft;
  final String chart2TopRight;
  final String chart2BottomLeft;
  final String chart2BottomRight;
  final String chart2Note;
  final String chart3TopLeft;
  final String chart3TopRight;
  final String chart3BottomLeft;
  final String chart3BottomRight;
  final String chart3Note;

  const PatientDentalChartCard({
    Key? key,
    required this.dateStr,
    required this.createdByDoctor,
    required this.chart1TopLeft,
    required this.chart1TopRight,
    required this.chart1BottomLeft,
    required this.chart1BottomRight,
    required this.chart1Note,
    required this.chart2TopLeft,
    required this.chart2TopRight,
    required this.chart2BottomLeft,
    required this.chart2BottomRight,
    required this.chart2Note,
    required this.chart3TopLeft,
    required this.chart3TopRight,
    required this.chart3BottomLeft,
    required this.chart3BottomRight,
    required this.chart3Note,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (createdByDoctor.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 10,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '创建医生: $createdByDoctor',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            dateStr,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 100),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ReadOnlyCrossChart(
                        topLeft: chart1TopLeft,
                        topRight: chart1TopRight,
                        bottomLeft: chart1BottomLeft,
                        bottomRight: chart1BottomRight,
                        note: chart1Note,
                      ),
                      const SizedBox(width: 100),
                      _ReadOnlyCrossChart(
                        topLeft: chart2TopLeft,
                        topRight: chart2TopRight,
                        bottomLeft: chart2BottomLeft,
                        bottomRight: chart2BottomRight,
                        note: chart2Note,
                      ),
                      const SizedBox(width: 100),
                      _ReadOnlyCrossChart(
                        topLeft: chart3TopLeft,
                        topRight: chart3TopRight,
                        bottomLeft: chart3BottomLeft,
                        bottomRight: chart3BottomRight,
                        note: chart3Note,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyCrossChart extends StatelessWidget {
  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;
  final String note;

  const _ReadOnlyCrossChart({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 250,
                    height: 1.5,
                    color: Colors.blue.shade300,
                  ),
                ),
                Center(
                  child: Container(
                    width: 1.5,
                    height: 42,
                    color: Colors.blue.shade300,
                  ),
                ),
                Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 3, top: 14),
                              child: Text(
                                topLeft,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.only(left: 3, top: 14),
                              child: Text(
                                topRight,
                                textAlign: TextAlign.left,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 3, bottom: 14),
                              child: Text(
                                bottomLeft,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.only(left: 3, bottom: 14),
                              child: Text(
                                bottomRight,
                                textAlign: TextAlign.left,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 3),
            height: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (note.isNotEmpty)
                  Center(
                    child: Container(
                      width: 250,
                      alignment: Alignment.center,
                      child: Text(
                        note,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                Center(
                  child: Container(
                    height: 1.5,
                    width: 250,
                    color: Colors.blue.shade300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
