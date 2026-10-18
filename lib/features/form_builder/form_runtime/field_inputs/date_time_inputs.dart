import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../form_editor/field_sheet/live_clock_time_picker.dart';
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
    builder: (state) => Material(
      color: Colors.transparent,
      child: ListTile(
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
          final timeStr = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LiveClockTimePicker(
                    initialTime: type == 'Time' && value != null ? '$value' : null,
                    minuteStep: (f['minute_step'] as int?) ?? 5,
                    onConfirm: (t) => Navigator.of(ctx).pop(t),
                    onCancel: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ),
          );
          if (timeStr == null) {
            return;
          }
          if (type == 'Time') {
            onChanged(timeStr);
            return;
          }
          final parts = timeStr.split(':');
          final hour = int.tryParse(toLatinDigits(parts[0])) ?? 0;
          final minute = int.tryParse(toLatinDigits(parts[1])) ?? 0;
          picked = DateTime(
            picked!.year,
            picked.month,
            picked.day,
            hour,
            minute,
          );
        }
        onChanged(
          type == 'Date'
              ? picked!.toIso8601String().substring(0, 10)
              : picked!.toIso8601String(),
        );
      },
    ),
  ),
);
}
