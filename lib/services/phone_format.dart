import 'package:flutter/services.dart';

/// Formats a Uzbek number for display: `+998901234567` → `+998 90 123 45 67`.
/// Anything that is not a full +998 number is returned unchanged.
String formatUzPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final local = digits.startsWith('998') && digits.length == 12
      ? digits.substring(3)
      : digits.length == 9
      ? digits
      : null;
  if (local == null) return phone;
  return '+998 ${groupUzLocal(local)}';
}

/// Groups up to 9 local digits as `XX XXX XX XX`.
String groupUzLocal(String digits) {
  const groups = [2, 3, 2, 2];
  final parts = <String>[];
  var start = 0;
  for (final size in groups) {
    if (start >= digits.length) break;
    final end = (start + size).clamp(0, digits.length);
    parts.add(digits.substring(start, end));
    start = end;
  }
  return parts.join(' ');
}

/// Input formatter for the local part after the fixed `+998 ` prefix.
/// Keeps at most 9 digits and shows them as `33 313 44 22` while typing.
class UzPhoneInputFormatter extends TextInputFormatter {
  const UzPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // A pasted full number like +998 90 123 45 67 keeps only the local part.
    if (digits.length > 9 && digits.startsWith('998')) {
      digits = digits.substring(3);
    }
    if (digits.length > 9) digits = digits.substring(0, 9);
    final text = groupUzLocal(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
