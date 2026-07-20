import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayMessage = message;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        if (displayMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              displayMessage,
              style: TextStyle(
                fontSize: 16.0,
                color: context.tokens.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
