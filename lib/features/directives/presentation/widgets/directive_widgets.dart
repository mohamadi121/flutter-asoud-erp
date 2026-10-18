import 'dart:math';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../data/directive_repository.dart';
import '../../domain/directive_models.dart';

String directiveRequestKey() => List.generate(24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();
String directiveError(Object error) => switch (error) {
      ApiException e => e.message,
      StateError e => e.message,
      String message => message,
      _ => failureMessage(error),
    };
String directiveDate(DateTime? date) => date == null
    ? '—'
    : toPersianDigits(JalaliDate.fromDateTime(date).format());
DateTime directiveDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Widget directiveFieldLabel(String label) => Text.rich(TextSpan(children: [
      TextSpan(text: label.replaceFirst(RegExp(r'\s*\*$'), '')),
      if (label.endsWith('*'))
        const TextSpan(text: ' *', style: TextStyle(color: AsoudColors.danger)),
    ]));

Color directivePriorityColor(String priority) => switch (priority) {
      'Urgent' => AsoudColors.danger,
      'High' => AsoudColors.warning,
      _ => AsoudColors.primary,
    };

class DirectiveSection extends StatelessWidget {
  const DirectiveSection(
      {super.key,
      required this.title,
      required this.child,
      this.color = AsoudColors.primary,
      this.collapsible = false});
  final String title;
  final Widget child;
  final Color color;
  final bool collapsible;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AsoudColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 3))
          ]),
      child: collapsible
          ? ExpansionTile(
              title: Text(title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              childrenPadding: const EdgeInsets.all(14),
              children: [child])
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    child
                  ])));
}

class DirectiveError extends StatelessWidget {
  const DirectiveError(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          color: AsoudColors.dangerSurface,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(message, style: const TextStyle(color: AsoudColors.danger)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('تلاش دوباره'))
          ])));
}

class DirectiveDateField extends StatelessWidget {
  const DirectiveDateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      required this.firstDate,
      this.lastDate});
  final String label;
  final DateTime? value, lastDate;
  final DateTime firstDate;
  final ValueChanged<DateTime>? onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      icon: const Icon(Icons.calendar_month_outlined),
      label: Column(mainAxisSize: MainAxisSize.min, children: [
        directiveFieldLabel(label),
        Text(value == null ? 'انتخاب تاریخ' : directiveDate(value)),
      ]),
      onPressed: onChanged == null
          ? null
          : () async {
              final selected = await showAsoudJalaliPicker(context,
                  initialDate: value ?? firstDate, title: label);
              if (selected == null || !context.mounted) return;
              if (directiveDay(selected).isBefore(directiveDay(firstDate)) ||
                  (lastDate != null &&
                      directiveDay(selected)
                          .isAfter(directiveDay(lastDate!)))) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تاریخ انتخاب‌شده خارج از بازه مجاز است.')));
                return;
              }
              onChanged!(selected);
            });
}

Future<DirectivePerson?> pickDirectivePerson(
        BuildContext context, List<DirectivePerson> people) =>
    showModalBottomSheet<DirectivePerson>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _PeoplePicker(people));

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker(this.people);
  final List<DirectivePerson> people;
  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final matches = widget.people
        .where((p) => '${p.name} ${p.department} ${p.position}'
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    return Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, MediaQuery.viewInsetsOf(context).bottom),
                child: Column(children: [
                  TextField(
                      decoration: const InputDecoration(
                          labelText: 'جست‌وجوی نام، واحد یا سمت',
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (value) => setState(() => query = value)),
                  Expanded(
                      child: matches.isEmpty
                          ? const Center(child: Text('فرد مجازی یافت نشد.'))
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (_, index) {
                                final p = matches[index];
                                return ListTile(
                                    title: Text(p.name),
                                    subtitle: Text(p.description),
                                    onTap: () => Navigator.pop(context, p));
                              }))
                ]))));
  }
}

class DirectiveAttachmentPicker extends StatefulWidget {
  const DirectiveAttachmentPicker(
      {super.key,
      required this.repository,
      required this.company,
      required this.policy,
      required this.attachments,
      required this.onChanged,
      required this.onBusyChanged,
      this.directiveId,
      this.enabled = true});
  final DirectiveRepository repository;
  final String company;
  final String? directiveId;
  final DirectiveFilePolicy? policy;
  final List<DirectiveAttachment> attachments;
  final ValueChanged<List<DirectiveAttachment>> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;
  @override
  State<DirectiveAttachmentPicker> createState() =>
      _DirectiveAttachmentPickerState();
}

class _DirectiveAttachmentPickerState extends State<DirectiveAttachmentPicker> {
  bool busy = false;
  String? error;
  XFile? pending;
  String? requestKey;
  Future<void> upload() async {
    if (busy || widget.policy == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    widget.onBusyChanged(true);
    try {
      pending ??= await openFile();
      if (pending == null) return;
      final size = await pending!.length();
      final invalid = widget.policy!
          .validate(pending!.name, size, widget.attachments.length);
      if (invalid != null) {
        pending = null;
        requestKey = null;
        throw invalid;
      }
      requestKey ??= directiveRequestKey();
      final attachment = await widget.repository.uploadAttachment(
          widget.company,
          directiveId: widget.directiveId,
          filename: pending!.name,
          bytes: await pending!.readAsBytes(),
          requestKey: requestKey!);
      if (!mounted) return;
      widget.onChanged([...widget.attachments, attachment]);
      pending = null;
      requestKey = null;
    } catch (e) {
      if (mounted) setState(() => error = directiveError(e));
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged(pending != null);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.policy == null)
          const Text(
              'سیاست بارگذاری از سرور دریافت نشده است؛ افزودن فایل فعلاً ممکن نیست.'),
        if (widget.policy != null)
          Text(
              '${widget.policy!.maxCount == null ? 'تعداد طبق سیاست سرور' : 'حداکثر ${toPersianDigits(widget.policy!.maxCount!)} فایل'}، هر فایل ${toPersianDigits(widget.policy!.maxBytes)} بایت\n${widget.policy!.extensions.join('، ')}'),
        for (final file in widget.attachments)
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(file.filename),
              subtitle: Text(
                  '${file.contentType} · ${toPersianDigits(file.size)} بایت'),
              trailing: IconButton(
                  tooltip: 'حذف پیوست از فرم',
                  icon: const Icon(Icons.close),
                  onPressed: !widget.enabled || busy
                      ? null
                      : () => widget.onChanged(widget.attachments
                          .where((f) => f.id != file.id)
                          .toList()))),
        if (busy) const LinearProgressIndicator(),
        if (error != null) DirectiveError(error!),
        if (pending != null && !busy)
          TextButton(
              onPressed: () {
                setState(() {
                  pending = null;
                  requestKey = null;
                  error = null;
                });
                widget.onBusyChanged(false);
              },
              child: const Text('انصراف از افزودن این فایل')),
        OutlinedButton.icon(
            onPressed: widget.enabled && !busy && widget.policy != null
                ? upload
                : null,
            icon: const Icon(Icons.attach_file),
            label: Text(pending == null
                ? 'افزودن پیوست'
                : 'تلاش دوباره برای بارگذاری')),
      ]);
}

class DirectiveAttachmentTile extends StatefulWidget {
  const DirectiveAttachmentTile(
      {super.key,
      required this.file,
      required this.repository,
      required this.company});
  final DirectiveAttachment file;
  final DirectiveRepository repository;
  final String company;
  @override
  State<DirectiveAttachmentTile> createState() =>
      _DirectiveAttachmentTileState();
}

class _DirectiveAttachmentTileState extends State<DirectiveAttachmentTile> {
  bool busy = false;
  Future<void> download() async {
    setState(() => busy = true);
    try {
      final file = await widget.repository
          .downloadAttachment(widget.company, widget.file.id);
      await FilePicker.platform
          .saveFile(fileName: file.filename, bytes: file.bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(directiveError(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.file.filename),
      subtitle: Text(
          '${widget.file.contentType} · ${toPersianDigits(widget.file.size)} بایت'),
      trailing: IconButton(
          tooltip: 'دریافت فایل',
          onPressed: busy ? null : download,
          icon: busy
              ? const SizedBox.square(
                  dimension: 20, child: CircularProgressIndicator())
              : const Icon(Icons.download_outlined)));
}
