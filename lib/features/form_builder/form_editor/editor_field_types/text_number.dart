import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../editor_widgets.dart';

List<Widget> buildTextNumberConfig(
  FormMap f,
  void Function(String key, dynamic value) set,
) {
  final type = f['type'];
  final numeric = ['Integer', 'Decimal', 'Money', 'Rating'].contains(type);
  final isText = ['Text', 'LongText', 'Barcode'].contains(type);

  void handleText(String key, dynamic value, {bool isNumeric = false}) {
    if (value == null) {
      f.remove(key);
    } else {
      set(key, value);
    }
  }

  return [
    if (numeric) ...[
      editorFieldText(
        label: 'حداقل',
        value: f['min'],
        numeric: true,
        onChanged: (v) => handleText('min', v, isNumeric: true),
      ),
      editorFieldText(
        label: 'حداکثر',
        value: f['max'],
        numeric: true,
        onChanged: (v) => handleText('max', v, isNumeric: true),
      ),
    ],
    if (isText) ...[
      editorFieldText(
        label: 'حداقل طول',
        value: f['min_length'],
        numeric: true,
        onChanged: (v) => handleText('min_length', v, isNumeric: true),
      ),
      editorFieldText(
        label: 'حداکثر طول',
        value: f['max_length'],
        numeric: true,
        onChanged: (v) => handleText('max_length', v, isNumeric: true),
      ),
      formSelect(
        'قالب ورودی',
        '${f['format'] ?? ''}',
        const {
          '': 'آزاد',
          'email': 'ایمیل',
          'mobile': 'شماره همراه ایران',
        },
        (v) => set('format', v),
      ),
      editorFieldText(
        label: 'پیام خطای قالب (اختیاری)',
        value: f['error_message'],
        onChanged: (v) => handleText('error_message', v),
      ),
    ],
  ];
}
