import 'package:flutter/material.dart';
import '../utils/jalali_date.dart';

Future<DateTime?> showAsoudJalaliPicker(BuildContext context,
        {DateTime? initialDate, String title = 'انتخاب تاریخ'}) =>
    showDialog<DateTime>(
        context: context,
        builder: (_) => _JalaliPicker(initialDate: initialDate, title: title));

class _JalaliPicker extends StatefulWidget {
  const _JalaliPicker({this.initialDate, required this.title});
  final DateTime? initialDate;
  final String title;
  @override
  State<_JalaliPicker> createState() => _JalaliPickerState();
}

class _JalaliPickerState extends State<_JalaliPicker> {
  late final initial =
      JalaliDate.fromDateTime(widget.initialDate ?? DateTime.now());
  late int year = initial.year.clamp(1200, 1500).toInt();
  late int month = initial.month;

  void _move(int delta) {
    final total = year * 12 + month - 1 + delta;
    final nextYear = total ~/ 12;
    if (nextYear < 1200 || nextYear > 1500) return;
    setState(() {
      year = nextYear;
      month = total % 12 + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final first = parseJalaliDate('$year/$month/1')!;
    final offset = (first.weekday + 1) % 7;
    var days = 31;
    while (parseJalaliDate('$year/$month/$days') == null) {
      days--;
    }
    return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  IconButton(
                      onPressed: () => _move(-1),
                      tooltip: 'ماه قبل',
                      icon: const Icon(Icons.chevron_right)),
                  Expanded(
                      child: Text(JalaliDate.monthNames[month - 1],
                          textAlign: TextAlign.center)),
                  DropdownButton<int>(
                      value: year,
                      items: [
                        for (var value = 1200; value <= 1500; value++)
                          DropdownMenuItem(
                              value: value, child: Text(toPersianDigits(value)))
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => year = value);
                      }),
                  IconButton(
                      onPressed: () => _move(1),
                      tooltip: 'ماه بعد',
                      icon: const Icon(Icons.chevron_left)),
                ]),
                Row(children: [
                  for (final label in ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'])
                    Expanded(child: Center(child: Text(label)))
                ]),
                const SizedBox(height: 8),
                GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var cell = 0; cell < offset + days; cell++)
                        if (cell < offset)
                          const SizedBox.shrink()
                        else
                          TextButton(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: year == initial.year &&
                                          month == initial.month &&
                                          cell - offset + 1 == initial.day
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : null),
                              onPressed: () => Navigator.pop(
                                  context,
                                  parseJalaliDate(
                                      '$year/$month/${cell - offset + 1}')),
                              child: Text(toPersianDigits(cell - offset + 1))),
                    ]),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'))
          ],
        ));
  }
}
