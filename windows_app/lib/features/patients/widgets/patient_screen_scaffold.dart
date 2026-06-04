import 'package:flutter/material.dart';

import '../../../widgets/dental_icons.dart';

class PatientScreenScaffold extends StatelessWidget {
  final Widget title;
  final Widget actions;
  final Widget body;
  final Widget? floatingActionButton;

  const PatientScreenScaffold({
    Key? key,
    required this.title,
    required this.actions,
    required this.body,
    this.floatingActionButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title,
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
        actions: [actions],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
