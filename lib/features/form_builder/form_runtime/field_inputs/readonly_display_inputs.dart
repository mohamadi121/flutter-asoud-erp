import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../form_repository.dart';
import '../rules_engine.dart';

/// The display name of a stored file reference: the last segment of a path
/// (`/private/files/.../report.pdf` → `report.pdf`), or the value itself when
/// it is already a name (a local preview label, a file name).
String _fileNames(dynamic value) {
  if (value == null || value == '') return '';
  final names = value is List ? value : [value];
  return names
      .map((name) {
        final text = '$name';
        final slash = text.lastIndexOf('/');
        return slash >= 0 && slash < text.length - 1
            ? text.substring(slash + 1)
            : text;
      })
      .join('، ');
}

Widget? buildReadonlyDisplayInput({
  required FormMap f,
  required dynamic value,
  required FormMap values,
  required String label,
  required bool editable,
}) {
  final type = '${f['type']}';
  final compare = formMap(f['compare']);
  if (type == 'Display' && compare.isNotEmpty) {
    String shown(dynamic raw) => isEmptyValue(raw) ? 'ثبت نشده' : toPersianDigits('$raw');
    final current = shown(values[compare['current']]);
    final proposed = shown(values[compare['proposed']]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('ساعت ثبت‌شده $current ← پیشنهادی $proposed'),
    );
  }
  if (type == 'Formula' || type == 'Display' || (!editable && type != 'Table')) {
    final text = ['Date', 'DateTime'].contains(type) && !isEmptyValue(value)
        ? formatJalaliDateTimeIso('$value')
        : ['Boolean', 'Checkbox'].contains(type)
            ? (value == true ? 'بله' : 'خیر')
            : ['File', 'Image', 'Signature'].contains(type)
                ? _fileNames(value)
                : '${value ?? ''}';
    return Material(
      color: Colors.transparent,
      child: ListTile(title: Text(label), subtitle: Text(text)),
    );
  }
  return null;
}
