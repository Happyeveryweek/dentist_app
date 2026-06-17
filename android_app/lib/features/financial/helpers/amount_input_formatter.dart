import 'package:flutter/services.dart';

final TextInputFormatter amountInputFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) {
    final text = newValue.text;
    if (text.isEmpty || RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) {
      return newValue;
    }
    return oldValue;
  },
);
