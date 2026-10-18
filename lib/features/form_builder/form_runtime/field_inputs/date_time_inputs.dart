import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../form_repository.dart';
import '../rules_engine.dart';

Widget? buildDateTimeInput({
  required BuildContext context,
  required FormMap f,
  required dynamic value,
  required String label,
  required bool required,
  required ValueChanged<dynamic> onChanged,
}) {
  final type = '${f['type']}';
  if (type != 'Date' && type != 'Time' && type != 'DateTime') {
    return null;
  }

  final date = DateTime.tryParse('$value');
  final display = date == null
      ? '${value ?? 'انتخاب'}'
      : '${JalaliDate.fromDateTime(date).format()}${type == 'DateTime' ? ' ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : ''}';

  return FormField<dynamic>(
    validator: (_) =>
        required && isEmptyValue(value) ? 'انتخاب الزامی است.' : null,
    builder: (state) => ListTile(
      title: Text(label),
      subtitle: Text(state.errorText ?? display),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        DateTime? picked;
        if (type != 'Time') {
          picked = await showAsoudJalaliPicker(context, initialDate: date);
          if (picked == null || !context.mounted) {
            return;
          }
        }
        if (type != 'Date') {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (time == null) {
            return;
          }
          if (type == 'Time') {
            onChanged(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            );
            return;
          }
          picked = DateTime(
            picked!.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        }
        onChanged(
          type == 'Date'
              ? picked!.toIso8601String().substring(0, 10)
              : picked!.toIso8601String(),
        );
      },
    ),
  );
}
