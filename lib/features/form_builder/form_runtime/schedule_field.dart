import 'package:flutter/material.dart';

import '../../../core/utils/failure_message.dart';
import '../../../core/utils/jalali_date.dart';
import '../form_repository.dart';

class ScheduleField extends StatefulWidget {
  const ScheduleField({
    required this.field,
    required this.values,
    required this.repository,
    this.formName,
    super.key,
  });

  final FormMap field;
  final FormMap values;
  final FormRepository repository;
  final String? formName;

  @override
  State<ScheduleField> createState() => _ScheduleFieldState();
}

class _ScheduleFieldState extends State<ScheduleField> {
  List<FormMap>? rows;
  Object? error;
  String signature = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ScheduleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reload();
  }

  void _reload() {
    final employeeKey = '${widget.field['schedule_of'] ?? 'self'}';
    final employee = employeeKey == 'self' ? null : '${widget.values[employeeKey] ?? ''}';
    final from = '${widget.values[widget.field['from_field']] ?? ''}';
    final to = '${widget.values[widget.field['to_field']] ?? ''}';
    final next = '$employee|$from|$to';
    if (next == signature) return;
    signature = next;
    rows = null;
    error = null;
    if (from.isEmpty || to.isEmpty || (employeeKey != 'self' && employee!.isEmpty)) {
      setState(() {});
      return;
    }
    widget.repository.employeeSchedule(
      fromDate: from,
      toDate: to,
      employee: employee,
      form: widget.formName,
      field: employeeKey == 'self' ? null : employeeKey,
    ).then((value) {
      if (!mounted || signature != next) return;
      setState(() => rows = value);
    }).catchError((Object value) {
      if (!mounted || signature != next) return;
      setState(() => error = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = '${widget.field['label'] ?? 'برنامه شیفت'}';
    if (signature.split('|').skip(1).any((part) => part.isEmpty)) {
      return _card(label, const Text('برای نمایش برنامه، کارمند و تاریخ را انتخاب کنید.'));
    }
    if (error != null) {
      return _card(label, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(failureMessage(error!)),
        TextButton(onPressed: () { signature = ''; _reload(); }, child: const Text('تلاش دوباره')),
      ]));
    }
    if (rows == null) return _card(label, const Center(child: CircularProgressIndicator()));
    if (rows!.isEmpty) return _card(label, const Text('برنامه‌ای برای این بازه ثبت نشده است.'));
    return _card(label, Column(children: [
      for (final row in rows!)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text('${row['date_label'] ?? formatJalaliIso('${row['date']}')}')),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: Text('${row['shift_type'] ?? row['source_label'] ?? 'بدون برنامه'}')),
            if (row['start_time'] != null) Flexible(child: Text('${toPersianDigits('${row['start_time']}').substring(0, 5)} تا ${toPersianDigits('${row['end_time']}').substring(0, 5)}', textDirection: TextDirection.rtl)),
          ]),
        ),
    ]));
  }

  Widget _card(String label, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F2)), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      child,
    ]),
  );
}
