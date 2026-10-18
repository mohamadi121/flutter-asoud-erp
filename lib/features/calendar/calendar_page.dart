import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/frappe_client.dart';
import '../../core/theme/asoud_colors.dart';
import '../../core/utils/jalali_date.dart';
import '../../core/widgets/asoud_jalali_picker.dart';
import '../../core/widgets/asoud_ui.dart';
import 'calendar_repository.dart';

/// The same interactive calendar is used on home and on the full page.
class AsoudCalendar extends StatefulWidget {
  const AsoudCalendar({
    required this.company,
    this.compact = false,
    this.createReminder = false,
    this.repository,
    this.now,
    super.key,
  });
  final String company;
  final bool compact;
  final bool createReminder;
  final CalendarRepository? repository;
  final DateTime? now;
  @override
  State<AsoudCalendar> createState() => _AsoudCalendarState();
}

class _AsoudCalendarState extends State<AsoudCalendar> {
  late final CalendarRepository repository = widget.repository ??
      CalendarRepository(context.read<FrappeApiClient?>(), widget.company);
  late DateTime selected = DateUtils.dateOnly(widget.now ?? DateTime.now());
  late DateTime month = selected;
  bool weekly = false, loading = true, busy = false;
  CalendarRow data = {};
  String? error, editing;
  String newKind = 'Reminder';
  int generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.createReminder) editing = 'new';
    _load();
  }

  List<CalendarRow> get items => calendarRows(data['items']);
  DateTime _add(DateTime value, int days) =>
      DateTime(value.year, value.month, value.day + days);
  DateTime get first {
    final j = JalaliDate.fromDateTime(month);
    return parseJalaliDate('${j.year}/${j.month}/1')!;
  }

  DateTime get last {
    final j = JalaliDate.fromDateTime(month);
    final total = j.year * 12 + j.month;
    return _add(parseJalaliDate('${total ~/ 12}/${total % 12 + 1}/1')!, -1);
  }

  DateTime get weekStart => _add(selected, -((selected.weekday + 1) % 7));

  Future<void> _load({bool refreshRemote = true}) async {
    final token = ++generation;
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await repository.load(
        widget.compact || weekly ? weekStart : first,
        widget.compact || weekly ? _add(weekStart, 6) : last,
        refreshRemote: refreshRemote,
      );
      if (mounted && token == generation) {
        setState(() {
          data = result;
          error = result['load_warning'] as String?;
        });
      }
    } catch (e) {
      if (mounted && token == generation) {
        setState(() {
          data = {};
          error = _message(e);
        });
      }
    } finally {
      if (mounted && token == generation) setState(() => loading = false);
    }
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : e is StateError
          ? e.message
          : 'دریافت یا ذخیره تقویم انجام نشد؛ دوباره تلاش کنید.';

  Future<void> _perform(Future<void> Function() action,
      {bool refreshRemote = true}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => editing = null);
      await _load(refreshRemote: refreshRemote);
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save(CalendarRow row) => _perform(() async {
        if (row['kind'] == 'Organization') {
          await repository.holiday(row);
        } else {
          await repository.save(row);
          // Local persistence is success even when the server is unavailable.
          // The existing sync action sends the durable queue explicitly.
        }
        if (!mounted) return;
        setState(() {
          selected = DateTime.tryParse('${row['date']}') ?? selected;
          month = selected;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(row['kind'] == 'Organization'
              ? 'تعطیلی سازمانی ذخیره شد.'
              : 'روی دستگاه ذخیره شد؛ در انتظار ارسال به سرور.'),
        ));
      }, refreshRemote: row['kind'] == 'Organization');

  Future<void> _delete(CalendarRow row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف از تقویم؟'),
        content: Text('${row['title']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes == true) await _save({...row, 'deleted': true});
  }

  void _select(DateTime date) {
    setState(() {
      selected = date;
      month = date;
      editing = null;
    });
    _load();
  }

  void _move(int delta) {
    if (weekly || widget.compact) {
      _select(_add(selected, delta * 7));
      return;
    }
    final j = JalaliDate.fromDateTime(month);
    final total = j.year * 12 + j.month - 1 + delta;
    if (total ~/ 12 < 1200 || total ~/ 12 > 1500) return;
    _select(parseJalaliDate('${total ~/ 12}/${total % 12 + 1}/1')!);
  }

  List<CalendarRow> _on(DateTime date) {
    final key = calendarDate(date);
    return items
        .where(
          (r) =>
              '${r['date']}'.compareTo(key) <= 0 &&
              '${r['end_date'] ?? r['date']}'.compareTo(key) >= 0,
        )
        .toList()
      ..sort((a, b) {
        final time = '${a['time'] ?? ''}'.compareTo('${b['time'] ?? ''}');
        return time != 0 ? time : '${a['id']}'.compareTo('${b['id']}');
      });
  }

  Widget _day(DateTime date) {
    final index = (date.weekday + 1) % 7;
    final isToday = DateUtils.isSameDay(date, widget.now ?? DateTime.now());
    final chosen = DateUtils.isSameDay(date, selected);
    final rows = _on(date);
    final holiday = date.weekday == DateTime.friday ||
        rows.any((r) => ['Official', 'Organization'].contains(r['kind']));
    const colors = [
      0xFFE8F2FF,
      0xFFE8F7F1,
      0xFFF0E9FF,
      0xFFFFF1E1,
      0xFFFCEBF1,
      0xFFE6F6FA,
      0xFFFFF0F0,
    ];
    final foreground = chosen
        ? Colors.white
        : holiday
            ? AsoudColors.danger
            : AsoudColors.text;
    return Semantics(
      label:
          '${formatJalaliLong(date)}${isToday ? '، امروز' : ''}${holiday ? '، تعطیل' : ''}',
      selected: chosen,
      button: true,
      child: Material(
        color: chosen
            ? AsoudColors.primary
            : holiday
                ? const Color(0xFFFFF0F0)
                : Color(colors[index]),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: holiday
                ? AsoudColors.danger
                : chosen
                    ? AsoudColors.primary
                    : AsoudColors.border,
            width: holiday ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _select(date),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  const ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'][index],
                  style: TextStyle(
                    color: foreground,
                    fontSize: isToday ? 14.4 : 12,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
                Text(
                  toPersianDigits(JalaliDate.fromDateTime(date).day),
                  style: TextStyle(
                    color: foreground,
                    fontSize: isToday ? 19.2 : 16,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
                SizedBox(
                  height: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (rows.any((r) => r['kind'] == 'Reminder'))
                        Icon(Icons.circle, size: 5, color: foreground),
                      if (rows.any((r) => r['kind'] == 'PersonalDay'))
                        Icon(Icons.person_outline, size: 8, color: foreground),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editor(CalendarRow? row) => CalendarEntryEditor(
        key: ValueKey('$editing:$newKind'),
        date: selected,
        row: row,
        kind: row?['kind'] as String? ?? newKind,
        busy: busy,
        onSave: _save,
        onCancel: () => setState(() => editing = null),
        onDelete: row == null ? null : () => _delete(row),
      );

  Widget _content() {
    final j = JalaliDate.fromDateTime(month);
    final dayRows = _on(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.compact ? 'برنامه هفتگی من' : 'تقویم من',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.compact)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AsoudCalendar(
                        company: widget.company,
                        repository: repository,
                        now: widget.now,
                      ),
                    ),
                  );
                  if (mounted) _load();
                },
                child: const Text('تقویم کامل'),
              ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => _move(-1),
              tooltip: 'بازه قبل',
              icon: const Icon(Icons.chevron_right),
            ),
            Expanded(
              child: Text(
                '${j.monthName} ${toPersianDigits(j.year)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () =>
                  _select(DateUtils.dateOnly(widget.now ?? DateTime.now())),
              child: const Text('امروز'),
            ),
            IconButton(
              onPressed: () => _move(1),
              tooltip: 'بازه بعد',
              icon: const Icon(Icons.chevron_left),
            ),
          ],
        ),
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('ماهانه')),
                ButtonSegment(value: true, label: Text('هفتگی')),
              ],
              selected: {weekly},
              onSelectionChanged: (v) {
                setState(() {
                  weekly = v.first;
                  editing = null;
                });
                _load();
              },
            ),
          ),
        if (widget.compact || weekly)
          SizedBox(
            height: 80,
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < 7; i++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: SizedBox(
                                width: (constraints.maxWidth - 40) / 5.5,
                                child: _day(_add(weekStart, i)),
                              ),
                            ),
                        ],
                      ),
                    )),
          )
        else
          GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: 64,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < (first.weekday + 1) % 7; i++)
                const SizedBox.shrink(),
              for (var d = first; !d.isAfter(last); d = _add(d, 1)) _day(d),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          formatJalaliLong(selected),
          style: const TextStyle(fontSize: 12, color: AsoudColors.muted),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          TextButton(
            onPressed: _load,
            child: Text(
              error!,
              style: const TextStyle(color: AsoudColors.danger),
            ),
          ),
        if (data['cached'] == true)
          const Text(
            'نمایش اطلاعات ذخیره‌شده روی دستگاه',
            style: TextStyle(fontSize: 11, color: AsoudColors.muted),
          ),
        if (!widget.compact) ...[
          for (final alert in calendarRows(data['alerts']))
            Card(
                child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined,
                  color: AsoudColors.primary),
              title: Text('${alert['title']}'),
              subtitle: Text(formatJalaliDateTimeIso('${alert['due']}')),
              trailing: IconButton(
                  tooltip: 'خواندم',
                  icon: const Icon(Icons.done),
                  onPressed: busy
                      ? null
                      : () => _perform(
                          () => repository.readAlert('${alert['id']}'))),
            )),
          Text(
            'منطقه زمانی: ${data['timezone'] ?? 'زمان محلی دستگاه (آفلاین)'}',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            data['official_status'] as String? ??
                'اطلاعات تعطیلات رسمی هنوز دریافت نشده است.',
            style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
          ),
        ],
        if ((data['pending_count'] as num? ?? 0) > 0)
          TextButton.icon(
            onPressed: busy ? null : () => _perform(repository.sync),
            icon: const Icon(Icons.sync),
            label: Text(
              '${toPersianDigits(data['pending_count'])} تغییر روی دستگاه؛ ارسال به سرور',
            ),
          ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'یادآورهای من',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF0E9FF),
                foregroundColor: const Color(0xFF6841B5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: busy
                  ? null
                  : () => setState(() {
                        editing = 'new';
                        newKind = 'Reminder';
                      }),
              icon: const Icon(Icons.add),
              label: const Text('یادآور'),
            ),
          ],
        ),
        AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: editing == 'new' && newKind == 'Reminder'
                ? _editor(null)
                : const SizedBox.shrink()),
        if (selected.weekday == DateTime.friday)
          const Text(
            'جمعه · تعطیل هفتگی',
            style: TextStyle(color: AsoudColors.danger),
          ),
        if (dayRows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('موردی برای این روز ثبت نشده است.'),
          ),
        for (final row in dayRows) ...[
          Card(
            color: const Color(0xFFF5F8FD),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: row['kind'] == 'Reminder'
                  ? Checkbox(
                      value: row['done'] == true,
                      onChanged:
                          busy ? null : (v) => _save({...row, 'done': v}),
                    )
                  : Icon(
                      row['kind'] == 'PersonalDay'
                          ? Icons.person_outline
                          : Icons.event_busy,
                      color: AsoudColors.danger,
                    ),
              title: Text(
                '${row['title']}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration:
                      row['done'] == true ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                row['kind'] == 'Reminder'
                    ? '${toPersianDigits(row['time'] ?? '')}${row['pending'] == true ? ' · منتظر ارسال' : ''}'
                    : row['kind'] == 'PersonalDay'
                        ? 'روز غیرکاری شخصی · بدون ثبت مرخصی'
                        : row['kind'] == 'Official'
                            ? 'تعطیلی رسمی'
                            : 'تعطیلی سازمانی',
                style: const TextStyle(
                  color: AsoudColors.primary,
                  fontSize: 14,
                ),
              ),
              trailing: row['kind'] == 'Official' ||
                      (row['kind'] == 'Organization' &&
                          data['can_manage'] != true)
                  ? null
                  : IconButton(
                      tooltip: 'ویرایش',
                      onPressed: busy
                          ? null
                          : () => setState(() => editing = '${row['id']}'),
                      icon: const Icon(Icons.edit_outlined),
                    ),
            ),
          ),
          AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: editing == row['id']
                  ? _editor(row)
                  : const SizedBox.shrink()),
        ],
        if (!widget.compact) ...[
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          editing = 'new';
                          newKind = 'PersonalDay';
                        }),
                icon: const Icon(Icons.person_outline),
                label: const Text('روز غیرکاری شخصی'),
              ),
              if (data['can_manage'] == true)
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            editing = 'new';
                            newKind = 'Organization';
                          }),
                  icon: const Icon(Icons.event_busy),
                  label: const Text('تعطیلی سازمانی'),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: editing == 'new' && newKind != 'Reminder'
                ? _editor(null)
                : const SizedBox.shrink(),
          ),
          const Text(
            'این تقویم حقوق، حضور و غیاب یا سررسید اسناد را تغییر نمی‌دهد. یادآور ذخیره‌شده فقط روی دستگاه، اعلان پس‌زمینه ندارد.',
            style: TextStyle(fontSize: 11, color: AsoudColors.muted),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: widget.compact
            ? Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFD9E7FC)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _content(),
                ),
              )
            : Scaffold(
                appBar: const AsoudHeader(title: 'تقویم من'),
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('بازگشت به خانه'),
                        ),
                      ),
                      _content(),
                    ],
                  ),
                ),
              ),
      );
}

class CalendarEntryEditor extends StatefulWidget {
  const CalendarEntryEditor({
    required this.date,
    required this.kind,
    required this.busy,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.row,
    super.key,
  });
  final DateTime date;
  final String kind;
  final bool busy;
  final CalendarRow? row;
  final Future<void> Function(CalendarRow) onSave;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;
  @override
  State<CalendarEntryEditor> createState() => _CalendarEntryEditorState();
}

class _CalendarEntryEditorState extends State<CalendarEntryEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(
    text: widget.row?['title'] as String? ?? '',
  );
  late DateTime date =
      DateTime.tryParse('${widget.row?['date']}') ?? widget.date;
  late DateTime end = DateTime.tryParse('${widget.row?['end_date']}') ?? date;
  late int hour =
      int.tryParse('${widget.row?['time'] ?? '09:00'}'.split(':').first) ?? 9;
  late int minute =
      int.tryParse('${widget.row?['time'] ?? '09:00'}'.split(':').last) ?? 0;
  late final id = widget.row?['id'] ?? calendarId();
  bool timeOpen = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> _date(bool ending) async {
    final value = await showAsoudJalaliPicker(
      context,
      initialDate: ending ? end : date,
    );
    if (value != null && mounted) {
      setState(() {
        if (ending) {
          end = value;
        } else {
          date = value;
          if (end.isBefore(date)) end = date;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: AsoudColors.primary.withValues(alpha: .04),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.kind == 'Reminder'
                      ? 'یادآور شخصی'
                      : widget.kind == 'PersonalDay'
                          ? 'روز غیرکاری شخصی'
                          : 'تعطیلی سازمانی',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    tooltip: 'بستن',
                    onPressed: widget.busy ? null : widget.onCancel,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: title,
                  enabled: !widget.busy,
                  maxLength: 140,
                  decoration: InputDecoration(
                      labelText: 'عنوان',
                      hintText: widget.kind == 'Reminder'
                          ? 'مثلاً تماس با مشتری'
                          : 'عنوان تعطیلی'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'عنوان را وارد کنید.' : null,
                ),
                OutlinedButton.icon(
                  onPressed: widget.busy ? null : () => _date(false),
                  icon: const Icon(Icons.calendar_month),
                  label: Text('تاریخ: ${formatJalaliIso(calendarDate(date))}'),
                ),
                if (widget.kind != 'Reminder')
                  OutlinedButton(
                    onPressed: widget.busy ? null : () => _date(true),
                    child:
                        Text('تا تاریخ: ${formatJalaliIso(calendarDate(end))}'),
                  ),
                if (widget.kind == 'Reminder') ...[
                  OutlinedButton.icon(
                    onPressed: widget.busy
                        ? null
                        : () => setState(() => timeOpen = !timeOpen),
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      toPersianDigits(
                        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  if (timeOpen)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: hour,
                                decoration:
                                    const InputDecoration(labelText: 'ساعت'),
                                items: [
                                  for (var i = 0; i < 24; i++)
                                    DropdownMenuItem(
                                      value: i,
                                      child: Text(
                                        toPersianDigits(
                                            i.toString().padLeft(2, '0')),
                                      ),
                                    ),
                                ],
                                onChanged: widget.busy
                                    ? null
                                    : (v) => setState(() => hour = v!),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(':', style: TextStyle(fontSize: 24)),
                            ),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: minute,
                                decoration:
                                    const InputDecoration(labelText: 'دقیقه'),
                                items: [
                                  for (final i in ({
                                    for (var n = 0; n < 60; n += 5) n,
                                    minute,
                                  }.toList()
                                    ..sort()))
                                    DropdownMenuItem(
                                      value: i,
                                      child: Text(
                                        toPersianDigits(
                                            i.toString().padLeft(2, '0')),
                                      ),
                                    ),
                                ],
                                onChanged: widget.busy
                                    ? null
                                    : (v) => setState(() => minute = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (timeOpen)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: widget.busy
                            ? null
                            : () => setState(() => timeOpen = false),
                        child: const Text('تأیید ساعت'),
                      ),
                    ),
                ],
                if (end.isBefore(date))
                  const Text(
                    'تاریخ پایان باید پس از شروع باشد.',
                    style: TextStyle(color: AsoudColors.danger),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: widget.busy
                          ? null
                          : () {
                              if (!form.currentState!.validate() ||
                                  (widget.kind != 'Reminder' &&
                                      end.isBefore(date))) {
                                return;
                              }
                              widget.onSave({
                                ...?widget.row,
                                'id': id,
                                'kind': widget.kind,
                                'title': title.text.trim(),
                                'date': calendarDate(date),
                                'end_date': calendarDate(
                                  widget.kind == 'Reminder' ? date : end,
                                ),
                                'time':
                                    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                                'done': widget.row?['done'] == true,
                              });
                            },
                      child: Text(widget.busy ? 'در حال ذخیره…' : 'ذخیره'),
                    ),
                    TextButton(
                      onPressed: widget.busy ? null : widget.onCancel,
                      child: const Text('انصراف'),
                    ),
                    if (widget.onDelete != null)
                      TextButton(
                        onPressed: widget.busy ? null : widget.onDelete,
                        child: const Text('حذف'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
