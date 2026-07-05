import 'package:flutter/material.dart';

import '../../../theme/theme_context_extensions.dart';

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
        backgroundColor: context.tokens.shellBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [actions],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
