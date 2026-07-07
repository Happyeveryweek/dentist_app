import 'package:flutter/material.dart';

import '../../../theme/theme_context_extensions.dart';

class PatientAppBarTitle extends StatelessWidget {
  const PatientAppBarTitle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: context.tokens.primaryHeaderGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.people_rounded,
            color: context.colors.onPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          '患者管理',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ],
    );
  }
}
