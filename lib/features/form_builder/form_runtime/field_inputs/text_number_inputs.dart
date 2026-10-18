import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../form_repository.dart';
import '../rules_engine.dart';

Widget? buildTextNumberInput({
  required FormMap f,
  required dynamic value,
  required String label,
  required bool required,
  required ValueChanged<dynamic> onChanged,
}) {
  final type = '${f['type']}';
  final key = '${f['key']}';
  final numeric = ['Integer', 'Decimal', 'Money', 'Rating'].contains(type);

  return ControlledFormText(
    key: ValueKey(key),
    value: '${value ?? ''}',
    decoration: InputDecoration(
      labelText: label,
      helperText: '${f['help'] ?? ''}',
    ),
    maxLines: type == 'LongText' ? 3 : 1,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text,
    onChanged: (text) => onChanged(numeric ? toLatinDigits(text) : text),
    validator: (text) {
      if (required && (text ?? '').trim().isEmpty) {
        return 'تکمیل این فیلد الزامی است.';
      }
      if ((text ?? '').isEmpty) {
        return null;
      }
      if (numeric) {
        final n = double.tryParse(toLatinDigits(text!));
        if (n == null ||
            !n.isFinite ||
            (type == 'Integer' && n != n.roundToDouble())) {
          return 'عدد معتبر وارد کنید.';
        }
        if (f['min'] != null && n < formNumber(f['min'])) {
          return 'کمتر از حداقل مجاز است.';
        }
        if (f['max'] != null && n > formNumber(f['max'])) {
          return 'بیشتر از حداکثر مجاز است.';
        }
      }
      if (text!.length < ((f['min_length'] as num?)?.toInt() ?? 0) ||
          text.length > ((f['max_length'] as num?)?.toInt() ?? 5000)) {
        return 'طول متن مجاز نیست.';
      }
      if (f['format'] == 'email') {
        final parts = text.split('@');
        if (parts.length != 2 ||
            parts.first.isEmpty ||
            !parts.last.contains('.') ||
            parts.last.split('.').any((v) => v.isEmpty) ||
            RegExp(r'\s').hasMatch(text)) {
          return '${f['error_message'] ?? 'ایمیل معتبر وارد کنید.'}';
        }
      }
      if (f['format'] == 'mobile' &&
          !RegExp(r'^09[0-9]{9}$').hasMatch(toLatinDigits(text))) {
        return '${f['error_message'] ?? 'شماره همراه معتبر وارد کنید.'}';
      }
      return null;
    },
  );
}

class ControlledFormText extends StatefulWidget {
  const ControlledFormText({
    required this.value,
    required this.decoration,
    required this.maxLines,
    required this.keyboardType,
    required this.onChanged,
    required this.validator,
    super.key,
  });

  final String value;
  final InputDecoration decoration;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String> validator;

  @override
  State<ControlledFormText> createState() => _ControlledFormTextState();
}

class _ControlledFormTextState extends State<ControlledFormText> {
  late final controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant ControlledFormText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: widget.decoration,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        validator: widget.validator,
      );
}
