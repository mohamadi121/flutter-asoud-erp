import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/workflow_wait_repository.dart';
import '../../domain/entities/workflow_definition.dart';

class WorkflowWaitSettingsPage extends StatefulWidget {
  const WorkflowWaitSettingsPage({required this.definition, required this.stage,
    required this.onSaved, this.repository, super.key});
  final String definition;
  final WorkflowStage stage;
  final Future<void> Function() onSaved;
  final WorkflowWaitRepository? repository;
  @override
  State<WorkflowWaitSettingsPage> createState() => _WorkflowWaitSettingsPageState();
}

class _WorkflowWaitSettingsPageState extends State<WorkflowWaitSettingsPage> {
  late WorkflowWaitRepository repository;
  final form = GlobalKey<FormState>();
  final anchors = <String, GlobalKey>{};
  final title = TextEditingController(), description = TextEditingController();
  final duration = TextEditingController(text: '24'), days = TextEditingController(text: '0');
  String type = 'Duration', unit = 'Hour', source = 'Original|', selected = '', storedType = '';
  String direction = 'Same', past = 'Continue', changedDate = 'Keep';
  DateTime? date;
  TimeOfDay? time;
  Map<String, dynamic>? metadata;
  String? error, validationAnchor, draftNotice;
  bool loading = true, saving = false, restored = false, legacyEvent = false, draftRead = false;
  List<Map<String, dynamic>> get fields => (metadata?['fields'] as List? ?? [])
      .whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList();
  String identity(Map<String, dynamic> f) => '${f['source_kind']}|${f['source_stage'] ?? ''}|${f['source_field']}';
  Map<String, dynamic>? get field => fields.where((f) => identity(f) == selected).firstOrNull;
  bool get needsClock => type == 'Date' || type == 'FormDate' && (field?['field_type'] ?? storedType) == 'Date';
  String get draftBase {
    Object? canonical(Object? value) => value is Map
        ? {for (final key in value.keys.map((k) => '$k').toList()..sort()) key: canonical(value[key])}
        : value is List ? value.map(canonical).toList() : value;
    return jsonEncode(canonical({'title': widget.stage.title, ...widget.stage.config}));
  }

  @override
  void initState() {
    super.initState();
    restore({'title': widget.stage.title, ...widget.stage.config});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!restored) {
      restored = true;
      load();
    }
  }

  void restore(Map<String, dynamic> config) {
    title.text = '${config['title'] ?? widget.stage.title}';
    description.text = '${config['description'] ?? ''}';
    type = '${config['wait_type'] ?? 'Duration'}';
    legacyEvent = type == 'Event';
    if (legacyEvent) type = '';
    unit = '${config['wait_unit'] ?? 'Hour'}';
    if (type == 'Duration') duration.text = toPersianDigits('${config['wait_value'] ?? 24}');
    if (type == 'Date') {
      final parsed = DateTime.tryParse('${config['wait_value'] ?? ''}');
      date = parsed;
      time = parsed == null ? null : TimeOfDay.fromDateTime(parsed);
    }
    final raw = config['date_source'];
    if (raw is Map) {
      final f = Map<String, dynamic>.from(raw);
      source = '${f['source_kind']}|${f['source_stage'] ?? ''}';
      selected = identity(f);
      storedType = '${f['field_type'] ?? ''}';
    }
    final clock = '${config['clock'] ?? ''}'.split(':');
    if (clock.length == 2 && int.tryParse(clock[0]) != null && int.tryParse(clock[1]) != null) {
      final h = int.parse(clock[0]), m = int.parse(clock[1]);
      if (h >= 0 && h < 24 && m >= 0 && m < 60) time = TimeOfDay(hour: h, minute: m);
    }
    direction = '${config['offset_direction'] ?? 'Same'}';
    days.text = '${config['offset_days'] ?? 0}';
    past = '${config['past_policy'] ?? 'Continue'}';
    changedDate = '${config['date_change_policy'] ?? 'Keep'}';
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      repository = widget.repository ?? WorkflowWaitRepository(context.read<FrappeApiClient>());
      if (!draftRead) { try {
        draftRead = true;
        final draft = await repository.draft(widget.definition, widget.stage.id);
        if (draft != null && mounted) {
          if (draft['_wait_draft_base'] == draftBase) { restore(draft); }
          else { draftNotice = 'پیش‌نویس دستگاه برای نسخهٔ دیگری است؛ اطلاعات فعلی سرور حفظ شد.'; }
        }
      } catch (_) { /* A corrupt local draft cannot replace the current editor. */ } }
      final value = await repository.options(widget.definition, widget.stage.id).timeout(const Duration(seconds: 12));
      if (value['wait_version'] != 1 || value['fields'] is! List || value['time_zone'] is! String) {
        throw StateError('پاسخ تنظیمات انتظار معتبر نیست.');
      }
      if (mounted) setState(() => metadata = value);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError
            ? 'پاسخ تنظیمات با این نسخه سازگار نیست؛ برنامه و سرور باید هماهنگ به‌روزرسانی شوند.' : failureMessage(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String get clockText => time == null ? '' : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
  Map<String, dynamic> get config => {
    'wait_version': 1, 'title': title.text.trim(), 'description': description.text.trim(),
    'wait_type': type, 'past_policy': past,
    if (type == 'Duration') ...{'wait_value': toLatinDigits(duration.text.trim()), 'wait_unit': unit},
    if (type == 'Date') 'wait_value': date == null || time == null ? '' :
        '${date!.toIso8601String().split('T').first}T$clockText:00',
    if (type == 'FormDate') ...{
      'date_source': field == null ? {'source_kind': source.split('|').first,
        'source_stage': source.split('|').last, 'source_field': selected.split('|').last, 'field_type': storedType} :
        {for (final key in ['source_kind', 'source_stage', 'source_field', 'field_type']) key: field![key]},
      'offset_direction': direction, 'offset_days': direction == 'Same' ? 0 : toLatinDigits(days.text.trim()),
      'date_change_policy': changedDate, if (needsClock) 'clock': clockText,
    },
  };

  String? invalid(String key, String? message) {
    if (message != null) validationAnchor ??= key;
    return message;
  }

  Future<void> save({bool draft = false}) async {
    if (saving) return;
    validationAnchor = null;
    if (!draft && !form.currentState!.validate()) {
      final target = anchors[validationAnchor]?.currentContext;
      if (target != null) await Scrollable.ensureVisible(target, alignment: .2, duration: const Duration(milliseconds: 200));
      return;
    }
    setState(() => saving = true);
    try {
      if (draft) {
        await repository.saveDraft(widget.definition, widget.stage.id, {...config, '_wait_draft_base': draftBase});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('پیش‌نویس روی دستگاه ذخیره شد؛ هیچ انتظار یا اجرای واقعی شروع نشد.')));
        }
      } else {
        await repository.save(widget.definition, widget.stage.id, config);
        try { await repository.clearDraft(widget.definition, widget.stage.id); } catch (_) { /* Server save remains authoritative. */ }
        await widget.onSaved();
        if (mounted) { Navigator.pop(context); }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError ? 'ذخیره از سرور تأیید نشد؛ اطلاعات فرم حفظ شده است.' : failureMessage(e));
      }
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  void dispose() { for (final c in [title, description, duration, days]) { c.dispose(); } super.dispose(); }

  Widget dropdown(String key, String label, String value, Map<String, String> choices, ValueChanged<String> change) =>
      Padding(key: anchors.putIfAbsent(key, GlobalKey.new), padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(key: ValueKey('$key:$value:${choices.keys.join()}'),
          initialValue: choices.containsKey(value) ? value : null, isExpanded: true,
          decoration: InputDecoration(labelText: label, floatingLabelBehavior: FloatingLabelBehavior.always),
          validator: (_) => invalid(key, key == 'field' && storedType.isNotEmpty && field?['field_type'] != storedType
              ? 'نوع فیلد تغییر کرده است؛ دوباره انتخاب کنید.' : choices.containsKey(value) ? null : 'گزینهٔ معتبر انتخاب کنید.'),
          items: choices.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: saving || choices.isEmpty ? null : (v) { if (v != null) setState(() => change(v)); }));

  Widget section(String text, IconData icon, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [AsoudIconBox(icon: icon, color: color, size: 32), const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)))]));

  Widget notice(String text, {bool warning = false}) => Container(margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12), decoration: BoxDecoration(
          color: warning ? const Color(0xfffff4dd) : const Color(0xffedf3ff), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.7)));

  Widget number(String key, String label, TextEditingController controller, int minimum) => Padding(
      key: anchors.putIfAbsent(key, GlobalKey.new), padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(controller: controller, enabled: !saving, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, floatingLabelBehavior: FloatingLabelBehavior.always), onChanged: (_) => setState(() {}),
          validator: (raw) { final n = int.tryParse(toLatinDigits(raw ?? ''));
            return invalid(key, n == null || n < minimum || n > 3650 ? 'عدد صحیح از ${toPersianDigits(minimum)} تا ۳۶۵۰ وارد کنید.' : null); }));

  String get summary => type == 'Duration' ? '${toPersianDigits(duration.text)} ${
      {'Minute': 'دقیقه', 'Hour': 'ساعت', 'Day': 'روز تقویمی'}[unit] ?? ''} پس از ورود به مرحله' :
      type == 'Date' ? '${date == null ? 'تاریخ انتخاب نشده' : formatJalaliIso(date!.toIso8601String())}، ${time == null ? 'ساعت انتخاب نشده' : toPersianDigits(clockText)}' :
      '${field?['label'] ?? 'تاریخ فرم انتخاب نشده'}؛ ${{'Same': 'همان تاریخ', 'Before': '${toPersianDigits(days.text)} روز قبل', 'After': '${toPersianDigits(days.text)} روز بعد'}[direction] ?? ''}';

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    backgroundColor: AsoudColors.background,
    appBar: const PreferredSize(preferredSize: Size.fromHeight(94), child: ColoredBox(color: Color(0xffe9edf8),
        child: AsoudHeader(title: 'انتظار و زمان‌بندی', subtitle: 'تنظیمات مرحله گردش‌کار'))),
    body: loading ? const Center(child: CircularProgressIndicator()) : Form(key: form, child: SingleChildScrollView(
      padding: AsoudFormStyle.pagePadding, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (error != null) ...[notice(error!, warning: true), OutlinedButton(onPressed: saving ? null : load, child: const Text('دریافت دوباره تنظیمات'))],
        if (legacyEvent) notice('انتظار رویدادیِ قدیمی قابل اجرا نیست؛ نوع انتظار جدید را صریحاً انتخاب کنید.', warning: true),
        if (draftNotice != null) notice(draftNotice!, warning: true),
        section('مشخصات مرحله', Icons.edit_outlined, AsoudColors.primary),
        Padding(key: anchors.putIfAbsent('title', GlobalKey.new), padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(controller: title, enabled: !saving, decoration: const InputDecoration(labelText: 'عنوان مرحله *', floatingLabelBehavior: FloatingLabelBehavior.always),
            validator: (v) => invalid('title', (v?.trim().length ?? 0) < 3 || (v?.length ?? 0) > 140 ? 'عنوان باید بین ۳ تا ۱۴۰ نویسه باشد.' : null))),
        TextFormField(controller: description, enabled: !saving, maxLines: 3, maxLength: 500,
            decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)', floatingLabelBehavior: FloatingLabelBehavior.always)),
        const Divider(height: 25),
        section('تنظیمات انتظار', Icons.alarm_outlined, const Color(0xff9062d3)),
        dropdown('type', 'نوع انتظار *', type, const {'Duration': 'انتظار به مدت مشخص', 'Date': 'انتظار تا تاریخ و ساعت مشخص', 'FormDate': 'انتظار براساس تاریخ فرم'},
            (v) { type = v; legacyEvent = false; }),
        if (type == 'Duration') ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: dropdown('unit', 'واحد زمان', unit, const {'Minute': 'دقیقه', 'Hour': 'ساعت', 'Day': 'روز تقویمی'}, (v) => unit = v)),
            const SizedBox(width: 8), Expanded(child: number('duration', 'مدت انتظار *', duration, 1)),
          ]),
          const Text('مدت انتظار از زمان ورود واقعی فرایند به این مرحله محاسبه می‌شود.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        ],
        if (type == 'Date') Padding(key: anchors.putIfAbsent('date', GlobalKey.new), padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(key: ValueKey('wait-date:$date'), readOnly: true,
            initialValue: date == null ? '' : formatJalaliIso(date!.toIso8601String()),
            decoration: const InputDecoration(labelText: 'تاریخ ادامه فرایند *', floatingLabelBehavior: FloatingLabelBehavior.always, suffixIcon: Icon(Icons.calendar_month_outlined)),
            validator: (_) => invalid('date', date == null ? 'تاریخ ادامه را انتخاب کنید.' : null),
            onTap: saving ? null : () async { final d = await showAsoudJalaliPicker(context, initialDate: date); if (d != null && mounted) setState(() => date = d); })),
        if (type == 'FormDate') ...[
          dropdown('source', 'منبع تاریخ', source, {'Original|': 'فرم اصلی درخواست یا سند',
            for (final f in fields.where((f) => f['source_kind'] == 'Stage')) 'Stage|${f['source_stage']}': '${f['stage_title']}'},
            (v) { source = v; selected = ''; storedType = ''; }),
          dropdown('field', 'فیلد تاریخ *', selected, {for (final f in fields.where((f) => '${f['source_kind']}|${f['source_stage'] ?? ''}' == source)) identity(f): '${f['label']}'},
            (v) { selected = v; storedType = '${field?['field_type'] ?? ''}'; }),
          if (fields.isEmpty) notice('فیلد تاریخِ مجاز در فرم اصلی یا خروجی مراحل قبلی پیدا نشد.', warning: true),
          if (field != null && storedType.isNotEmpty && field!['field_type'] != storedType)
            notice('نوع فیلد تاریخ تغییر کرده است؛ دوباره آن را انتخاب کنید.', warning: true),
          dropdown('direction', 'نحوه محاسبه تاریخ', direction, const {'Same': 'همان تاریخ', 'Before': 'چند روز قبل', 'After': 'چند روز بعد'}, (v) => direction = v),
          if (direction != 'Same') number('days', 'تعداد روز *', days, 0),
          if (!needsClock) notice('ساعت خودِ فیلد تاریخ‌وساعت استفاده می‌شود؛ ساعت دیگری روی آن اعمال نمی‌شود.'),
        ],
        if (needsClock) Padding(key: anchors.putIfAbsent('time', GlobalKey.new), padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(key: ValueKey('wait-clock:$clockText'), readOnly: true, initialValue: toPersianDigits(clockText),
            decoration: const InputDecoration(labelText: 'ساعت ادامه فرایند *', floatingLabelBehavior: FloatingLabelBehavior.always, suffixIcon: Icon(Icons.schedule_outlined)),
            validator: (_) => invalid('time', time == null ? 'ساعت ادامه را انتخاب کنید.' : null),
            onTap: saving ? null : () async { final t = await showTimePicker(context: context, initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
              builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!));
              if (t != null && mounted) setState(() => time = t); })),
        const Divider(height: 25), section('ادامه فرایند', Icons.route_outlined, const Color(0xff2d9e7b)),
        Card(child: ListTile(leading: const Icon(Icons.arrow_downward), title: const Text('ادامه خودکار'),
          subtitle: Text(metadata?['output_valid'] == true ? 'طبق اتصال موجود در نمودار' : 'یک اتصال خروجی معتبر در نمودار لازم است.'),
          trailing: Icon(metadata?['output_valid'] == true ? Icons.check_circle_outline : Icons.error_outline,
            color: metadata?['output_valid'] == true ? const Color(0xff2d9e7b) : AsoudColors.danger))),
        AsoudFormSection(title: 'تنظیمات تکمیلی', children: [
          dropdown('past', 'اگر زمان انتظار گذشته باشد', past, const {'Continue': 'ادامه فوری فرایند', 'Error': 'توقف و ثبت خطا'}, (v) => past = v),
          if (type == 'FormDate') dropdown('changed', 'اگر تاریخ فرم تغییر کند', changedDate,
              const {'Keep': 'حفظ زمان تعیین‌شده قبلی', 'Recalculate': 'محاسبه مجدد زمان انتظار'}, (v) => changedDate = v),
          Text('منطقه زمانی: ${metadata?['time_zone'] ?? 'دریافت نشده'}${metadata?['zone_source'] == 'System' ? ' (تنظیم سامانه؛ دفتر تنظیم اختصاصی ندارد)' : ''}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8), const Text('با لغو یا خاتمهٔ فرایند، انتظار قبلی دیگر ادامه‌ای ایجاد نمی‌کند.', style: TextStyle(fontSize: 11)),
        ]),
        notice('خلاصه زمان‌بندی\n$summary\nادامه در نوبت پردازش سرور انجام می‌شود، نه الزاماً همان ثانیه.'),
        if (metadata?['execution_ready'] != true) notice('${metadata?['blocked_message'] ?? 'تنظیمات معتبر سرور دریافت نشده است؛ فقط پیش‌نویس دستگاه قابل نگهداری است.'}', warning: true),
        OutlinedButton(onPressed: saving ? null : () => save(draft: true), child: const Text('ذخیره پیش‌نویس')),
        const SizedBox(height: 10), FilledButton(onPressed: saving || metadata?['execution_ready'] != true || metadata?['output_valid'] != true ? null : () => save(),
            child: Text(saving ? 'در حال ذخیره…' : 'اعتبارسنجی و ذخیره')),
      ]))),
  ));
}
