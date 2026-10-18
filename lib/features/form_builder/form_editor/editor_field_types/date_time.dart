import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../form_repository.dart';

List<Widget> buildDateTimeConfig({
  required BuildContext context,
  required FormMap f,
  required void Function(String key, dynamic value) set,
  required void Function(VoidCallback fn) update,
}) {
  if (!['Date', 'DateTime'].contains(f['type'])) {
    return const [];
  }
  return [
    for (final bound in ['min_date', 'max_date'])
      ListTile(
        title: Text(
          bound == 'min_date' ? 'حداقل تاریخ' : 'حداکثر تاریخ',
        ),
        subtitle: Text(
          f[bound] == null
              ? 'بدون محدودیت'
              : formatJalaliDateTimeIso('${f[bound]}'),
        ),
        trailing: f[bound] == null
            ? null
            : IconButton(
                onPressed: () => update(() => f.remove(bound)),
                icon: const Icon(Icons.close),
              ),
        onTap: () async {
          final date = await showAsoudJalaliPicker(
            context,
            initialDate: DateTime.tryParse('${f[bound]}'),
          );
          if (date != null && context.mounted) {
            set(bound, date.toIso8601String().substring(0, 10));
          }
        },
      ),
  ];
}
