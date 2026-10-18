import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../form_repository.dart';
import '../rules_engine.dart';

Widget? buildReadonlyDisplayInput({
  required FormMap f,
  required dynamic value,
  required String label,
  required bool editable,
}) {
  final type = '${f['type']}';
  if (type == 'Formula' || type == 'Display' || (!editable && type != 'Table')) {
    final text = ['Date', 'DateTime'].contains(type) && !isEmptyValue(value)
        ? formatJalaliDateTimeIso('$value')
        : ['Boolean', 'Checkbox'].contains(type)
            ? (value == true ? 'بله' : 'خیر')
            : '${value ?? ''}';
    return ListTile(title: Text(label), subtitle: Text(text));
  }
  return null;
}
