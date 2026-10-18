import 'package:flutter/material.dart';

import '../../form_repository.dart';
import '../editor_widgets.dart';

List<Widget> buildFileConfig(
  FormMap f,
  void Function(String key, dynamic value) set,
) {
  if (!['File', 'Image', 'Signature'].contains(f['type'])) {
    return const [];
  }

  void handleNumeric(String key, dynamic value) {
    if (value == null) {
      f.remove(key);
    } else {
      set(key, value);
    }
  }

  return [
    editorFieldText(
      label: 'حداکثر تعداد فایل (تا ۱۰)',
      value: f['max_files'],
      numeric: true,
      onChanged: (v) => handleNumeric('max_files', v),
    ),
    editorFieldText(
      label: 'حداکثر حجم مگابایت (تا ۱۰)',
      value: f['max_mb'],
      numeric: true,
      onChanged: (v) => handleNumeric('max_mb', v),
    ),
    TextFormField(
      initialValue:
          (f['extensions'] as List? ?? ['pdf', 'jpg', 'jpeg', 'png']).join(','),
      decoration: const InputDecoration(
        labelText: 'پسوندهای مجاز با کاما',
      ),
      onChanged: (v) => f['extensions'] = v
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList(),
    ),
  ];
}
