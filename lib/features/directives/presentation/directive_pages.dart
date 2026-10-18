import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/theme/asoud_colors.dart';
import '../../../core/utils/jalali_date.dart';
import '../../../core/widgets/asoud_ui.dart';
import '../data/directive_repository.dart';
import '../domain/directive_models.dart';
import '../directive_navigation.dart';
import 'widgets/directive_widgets.dart';

class DirectiveCreatePage extends StatefulWidget {
  const DirectiveCreatePage(
      {required this.company, this.id, this.repository, super.key});
  final String company;
  final String? id;
  final DirectiveRepository? repository;
  @override
  State<DirectiveCreatePage> createState() => _DirectiveCreatePageState();
}

class _DirectiveCreatePageState extends State<DirectiveCreatePage> {
  late final DirectiveRepository repo = widget.repository ??
      ApiDirectiveRepository(context.read<FrappeApiClient>());
  final form = GlobalKey<FormState>();
  final subject = TextEditingController(), body = TextEditingController();
  DirectiveOptions? options;
  final people = <DirectivePerson>[];
  String? id, primary, error;
  String priority = 'Medium';
  DateTime? due;
  bool allowTransfer = false, busy = false, uploading = false, loading = true;
  List<DirectiveAttachment> attachments = [];
  Future<void> Function()? pending;
  bool get locked => busy || uploading || pending != null;
  @override
  void initState() {
    super.initState();
    id = widget.id;
    _load();
  }

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final opts = await repo.options(widget.company);
      final detail =
          id == null ? null : await repo.getDirective(widget.company, id!);
      if (!mounted) return;
      if (detail != null && !detail.can('save_draft')) {
        throw StateError('این دستور قابل ویرایش نیست.');
      }
      setState(() {
        options = opts;
        loading = false;
        error = null;
        if (detail != null) {
          subject.text = detail.subject;
          body.text = detail.body;
          priority = detail.priority;
          due = detail.dueDate;
          people
            ..clear()
            ..addAll(detail.executors.map((e) => e.person));
          primary =
              detail.executors.where((e) => e.isPrimary).firstOrNull?.person.id;
          allowTransfer = detail.allowTransfer;
          attachments = detail.attachments;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = directiveError(e);
          loading = false;
        });
      }
    }
  }

  DirectiveDraft _draft() => DirectiveDraft(
      id: id,
      subject: subject.text.trim(),
      body: body.text.trim(),
      priority: priority,
      dueDate: due,
      executorIds: people.map((p) => p.id).toList(),
      primaryId: primary,
      allowTransfer: allowTransfer,
      attachments: List.of(attachments));
  Future<void> _save(bool issue) async {
    if (busy || uploading) return;
    if (pending == null) {
      if (issue &&
          (!(form.currentState?.validate() ?? false) ||
              people.isEmpty ||
              primary == null ||
              due == null)) {
        setState(() => error =
            'موضوع، شرح، مهلت، حداقل یک مجری و یک مسئول اصلی را مشخص کنید.');
        return;
      }
      final draft = _draft();
      final key = directiveRequestKey();
      pending = () async {
        final saved = issue
            ? await repo.issue(widget.company, draft, requestKey: key,
                onDraftSaved: (savedId) {
                if (mounted) setState(() => id = savedId);
              })
            : await repo.saveDraft(widget.company, draft, requestKey: key);
        if (!mounted) return;
        setState(() {
          id = saved;
          pending = null;
        });
        if (issue) {
          await Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute(
                  builder: (_) => DirectiveDetailPage(
                      company: widget.company, id: saved, repository: repo)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('پیش‌نویس روی سرور ذخیره شد.')));
        }
      };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await pending!();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = directiveError(e);
          if (e is ApiException &&
              [
                ApiFailureKind.validation,
                ApiFailureKind.forbidden,
                ApiFailureKind.conflict
              ].contains(e.kind)) {
            pending = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: AsoudColors.background,
          appBar: const AsoudHeader(
              title: 'صدور دستور',
              subtitle: 'پیش‌نویس · اطلاعات تا ابلاغ قابل تغییر است'),
          bottomNavigationBar: DirectiveBottomBar(
              company: widget.company,
              selectedIndex: 2,
              enabled: !busy && !uploading),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    if (error != null)
                      DirectiveError(error!,
                          onRetry: options == null ? _load : null),
                    if (pending != null && !busy)
                      const Text(
                          'نتیجه درخواست هنوز قطعی نیست؛ با «تلاش دوباره» همان درخواست پیگیری می‌شود.'),
                    if (options != null &&
                        !options!.allowedActions.contains('save_draft'))
                      const DirectiveError(
                          'برای صدور دستور باید زیرمجموعه فعال و مجاز داشته باشید.'),
                    if (options?.allowedActions.contains('save_draft') ==
                        true) ...[
                      DirectiveSection(
                          title: 'مشخصات دستور',
                          child: Column(children: [
                            TextFormField(
                                controller: subject,
                                readOnly: locked,
                                maxLength: 200,
                                decoration: const InputDecoration(
                                    labelText: 'موضوع دستور *'),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'موضوع را وارد کنید.'
                                    : null),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: body,
                                readOnly: locked,
                                minLines: 4,
                                maxLines: 9,
                                decoration: const InputDecoration(
                                    labelText: 'شرح دستور *'),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'شرح را وارد کنید.'
                                    : null),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                                initialValue: priority,
                                key: ValueKey(priority),
                                decoration:
                                    const InputDecoration(labelText: 'اولویت'),
                                items: options!.priorities
                                    .map((p) => DropdownMenuItem(
                                        value: p.value, child: Text(p.label)))
                                    .toList(),
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() => priority = v!)),
                            const SizedBox(height: 12),
                            DirectiveDateField(
                                label: 'مهلت انجام *',
                                value: due,
                                firstDate: options!.today,
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() => due = v)),
                          ])),
                      DirectiveSection(
                          title: 'مجریان و مسئول اصلی',
                          color: AsoudColors.cyan,
                          child: Column(children: [
                            for (final p in people)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(p.name),
                                  subtitle: Text(primary == p.id
                                      ? 'مسئول اصلی'
                                      : p.description),
                                  leading: IconButton(
                                      tooltip: 'انتخاب مسئول اصلی',
                                      icon: Icon(
                                          primary == p.id
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: AsoudColors.primary),
                                      onPressed: locked
                                          ? null
                                          : () =>
                                              setState(() => primary = p.id)),
                                  trailing: IconButton(
                                      tooltip: 'حذف مجری',
                                      icon: const Icon(Icons.close),
                                      onPressed: locked
                                          ? null
                                          : () => setState(() {
                                                people.remove(p);
                                                if (primary == p.id) {
                                                  primary = null;
                                                }
                                              }))),
                            OutlinedButton.icon(
                                icon: const Icon(Icons.person_add_alt),
                                label: const Text('انتخاب مجری'),
                                onPressed: locked
                                    ? null
                                    : () async {
                                        final person =
                                            await pickDirectivePerson(
                                                context,
                                                options!.people
                                                    .where((p) => !people.any(
                                                        (s) => s.id == p.id))
                                                    .toList());
                                        if (person != null && mounted) {
                                          setState(() {
                                            people.add(person);
                                            if (people.length == 1) {
                                              primary = person.id;
                                            }
                                          });
                                        }
                                      }),
                            const Text(
                                'هر مجری گزارش مستقل می‌دهد؛ تأیید نهایی فقط با صادرکننده است.',
                                style: TextStyle(
                                    fontSize: 12, color: AsoudColors.muted)),
                          ])),
                      DirectiveSection(
                          title: 'پیوست‌های دستور',
                          color: AsoudColors.warning,
                          collapsible: true,
                          child: id == null
                              ? const Text(
                                  'برای افزودن پیوست، ابتدا پیش‌نویس را ذخیره کنید.')
                              : DirectiveAttachmentPicker(
                                  repository: repo,
                                  company: widget.company,
                                  directiveId: id,
                                  policy: options!.filePolicy,
                                  attachments: attachments,
                                  enabled: !busy && pending == null,
                                  onChanged: (v) =>
                                      setState(() => attachments = v),
                                  onBusyChanged: (v) =>
                                      setState(() => uploading = v))),
                      DirectiveSection(
                          title: 'ارجاع و پیگیری',
                          color: AsoudColors.purple,
                          collapsible: true,
                          child: Column(children: [
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                    'اجازه انتقال مسئولیت توسط مجری'),
                                value: allowTransfer,
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() => allowTransfer = v)),
                            const Text(
                                'انتقال با دلیل و حفظ سابقه انجام می‌شود. ویرایش پس از صدور، لغو و تأیید جانشین فعال نیست.'),
                          ])),
                      if (busy) const LinearProgressIndicator(),
                      if (pending != null && !busy)
                        FilledButton(
                            onPressed: () => _save(false),
                            child: const Text('تلاش دوباره'))
                      else
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton(
                              onPressed: locked ? null : () => _save(false),
                              child: const Text('ذخیره پیش‌نویس')),
                          FilledButton(
                              onPressed: locked ? null : () => _save(true),
                              child: const Text('صدور دستور')),
                        ]),
                    ],
                  ]))));
}

class DirectiveDetailPage extends StatefulWidget {
  const DirectiveDetailPage(
      {required this.id, this.company = '', this.repository, super.key});
  final String id, company;
  final DirectiveRepository? repository;
  @override
  State<DirectiveDetailPage> createState() => _DirectiveDetailPageState();
}

class _DirectiveDetailPageState extends State<DirectiveDetailPage> {
  late final DirectiveRepository repo = widget.repository ??
      ApiDirectiveRepository(context.read<FrappeApiClient>());
  DirectiveDetail? detail;
  List<DirectiveReport> reports = [];
  List<DirectiveHistory> history = [];
  String? reportCursor, historyCursor, error;
  bool loading = true, busy = false;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await repo.getDirective(widget.company, widget.id);
      final r = await repo.reports(widget.company, widget.id);
      final h = await repo.history(widget.company, widget.id);
      if (mounted) {
        setState(() {
          detail = d;
          reports = r.items;
          history = h.items;
          reportCursor = r.nextCursor;
          historyCursor = h.nextCursor;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          detail = null;
          error = directiveError(e);
          loading = false;
        });
      }
    }
  }

  Future<void> _more(bool report) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (report) {
        final page =
            await repo.reports(widget.company, widget.id, cursor: reportCursor);
        if (mounted) {
          setState(() {
            reports.addAll(page.items);
            reportCursor = page.nextCursor;
          });
        }
      } else {
        final page = await repo.history(widget.company, widget.id,
            cursor: historyCursor);
        if (mounted) {
          setState(() {
            history.addAll(page.items);
            historyCursor = page.nextCursor;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = directiveError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _action(String action, {DirectiveReport? report}) async {
    final d = detail!;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => _DirectiveActionPage(
            detail: d,
            company: d.company,
            repository: repo,
            action: action,
            report: report)));
    if (mounted) await _load();
  }

  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AsoudColors.muted)),
        const SizedBox(height: 4),
        SelectableText(value.isEmpty ? '—' : value)
      ]));
  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: AsoudColors.background,
            appBar: const AsoudHeader(
                title: 'جزئیات دستور', subtitle: 'کارتابل من / دستورات'),
            bottomNavigationBar:
                DirectiveBottomBar(company: widget.company, enabled: !busy),
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (error != null)
                            DirectiveError(error!, onRetry: _load),
                          if (d != null) ...[
                            Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 12,
                                children: [
                                  Text(d.number,
                                      style: const TextStyle(
                                          color: AsoudColors.primary)),
                                  Chip(label: Text(d.status))
                                ]),
                            const SizedBox(height: 12),
                            AsoudSegmentedControl<int>(
                                value: tab,
                                options: const [
                                  AsoudSegmentedOption(
                                      value: 0, label: 'جزئیات'),
                                  AsoudSegmentedOption(
                                      value: 1, label: 'گزارش‌ها'),
                                  AsoudSegmentedOption(value: 2, label: 'سوابق')
                                ],
                                onChanged: (v) => setState(() => tab = v)),
                            const SizedBox(height: 12),
                            if (tab == 0) ...[
                              DirectiveSection(
                                  title: 'مشخصات دستور',
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _line('موضوع دستور', d.subject),
                                        _line('شرح دستور', d.body),
                                        _line('صادرکننده', d.issuer.name),
                                        _line('تاریخ صدور',
                                            directiveDate(d.issueDate)),
                                        _line('مهلت انجام',
                                            directiveDate(d.dueDate)),
                                        _line('اولویت', d.priorityLabel),
                                      ])),
                              DirectiveSection(
                                  title: 'پیوست‌های دستور',
                                  color: AsoudColors.warning,
                                  collapsible: true,
                                  child: Column(children: [
                                    if (d.attachments.isEmpty)
                                      const Text('پیوستی ثبت نشده است.'),
                                    for (final f in d.attachments)
                                      DirectiveAttachmentTile(
                                          file: f,
                                          repository: repo,
                                          company: widget.company),
                                  ])),
                              DirectiveSection(
                                  title: 'وضعیت مجریان',
                                  color: AsoudColors.cyan,
                                  child: Column(children: [
                                    for (final e in d.executors)
                                      ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(e.person.name),
                                          subtitle: Text(
                                              '${e.isPrimary ? 'مسئول اصلی' : 'مجری'} · ${e.status}${e.overdue ? ' · معوق' : ''}'),
                                          trailing: const Icon(
                                              Icons.person_outline,
                                              color: AsoudColors.cyan)),
                                  ])),
                              DirectiveSection(
                                  title: 'مدیریت دستور',
                                  color: AsoudColors.purple,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (d.can('save_draft'))
                                          FilledButton(
                                              onPressed: () async {
                                                await Navigator.of(context).push<
                                                        void>(
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            DirectiveCreatePage(
                                                                company:
                                                                    d.company,
                                                                id: d.id,
                                                                repository:
                                                                    repo)));
                                                if (mounted) await _load();
                                              },
                                              child:
                                                  const Text('ادامه پیش‌نویس')),
                                        if (d.can('report'))
                                          FilledButton(
                                              onPressed: () =>
                                                  _action('report'),
                                              child: const Text(
                                                  'ثبت و ارسال گزارش')),
                                        if (d.currentUserId == d.issuer.id)
                                          OutlinedButton(
                                              onPressed: () =>
                                                  setState(() => tab = 1),
                                              child:
                                                  const Text('بررسی گزارش‌ها')),
                                        if (d.can('transfer'))
                                          OutlinedButton(
                                              onPressed: () =>
                                                  _action('transfer'),
                                              child:
                                                  const Text('انتقال مسئولیت')),
                                        if (d.can('close'))
                                          FilledButton(
                                              onPressed: () => _action('close'),
                                              child: const Text(
                                                  'تأیید نهایی و مختومه کردن')),
                                        if (!d.can('close') &&
                                            !d.isDraft &&
                                            d.currentUserId == d.issuer.id)
                                          const Text(
                                              'اختتام پس از تأیید مستقل همه گزارش‌ها و بسته‌شدن اقدامات الزامی ممکن است.',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AsoudColors.muted)),
                                      ])),
                            ],
                            if (tab == 1) ...[
                              if (reports.isEmpty)
                                const Text('گزارشی ثبت نشده است.'),
                              for (final r in reports)
                                DirectiveSection(
                                    title:
                                        '${r.author.name} · نسخه ${toPersianDigits(r.version)}',
                                    color: AsoudColors.cyan,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _line('تاریخ انجام',
                                              directiveDate(r.doneDate)),
                                          _line(
                                              'زمان ثبت',
                                              formatJalaliDateTimeIso(
                                                  r.createdAt)),
                                          _line('شرح اقدامات', r.body),
                                          _line('وضعیت', r.status),
                                          if (r.reviewNote.isNotEmpty)
                                            _line(
                                                'نظر صادرکننده', r.reviewNote),
                                          for (final f in r.attachments)
                                            DirectiveAttachmentTile(
                                                file: f,
                                                repository: repo,
                                                company: widget.company),
                                          if (r.allowedActions
                                              .contains('approve'))
                                            FilledButton(
                                                onPressed: () => _action(
                                                    'approve',
                                                    report: r),
                                                child:
                                                    const Text('تأیید گزارش')),
                                          if (r.allowedActions
                                              .contains('request_changes'))
                                            OutlinedButton(
                                                onPressed: () => _action(
                                                    'return',
                                                    report: r),
                                                child: const Text(
                                                    'درخواست اصلاح')),
                                        ])),
                              if (reportCursor != null)
                                TextButton(
                                    onPressed: busy ? null : () => _more(true),
                                    child: const Text('گزارش‌های بیشتر')),
                            ],
                            if (tab == 2) ...[
                              if (history.isEmpty)
                                const Text('رویدادی در دسترس نیست.'),
                              for (final h in history)
                                DirectiveSection(
                                    title: h.action,
                                    color: AsoudColors.purple,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(h.actor),
                                          Text(
                                              formatJalaliDateTimeIso(
                                                  h.createdAt),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AsoudColors.muted)),
                                          if (h.description.isNotEmpty)
                                            Text(h.description),
                                          if (h.reference.isNotEmpty)
                                            Text(h.reference),
                                        ])),
                              if (historyCursor != null)
                                TextButton(
                                    onPressed: busy ? null : () => _more(false),
                                    child: const Text('سوابق بیشتر')),
                            ],
                          ],
                        ]))));
  }
}

class _DirectiveActionPage extends StatefulWidget {
  const _DirectiveActionPage(
      {required this.detail,
      required this.company,
      required this.repository,
      required this.action,
      this.report});
  final DirectiveDetail detail;
  final String company, action;
  final DirectiveRepository repository;
  final DirectiveReport? report;
  @override
  State<_DirectiveActionPage> createState() => _DirectiveActionPageState();
}

class _DirectiveActionPageState extends State<_DirectiveActionPage> {
  final text = TextEditingController();
  DateTime? date;
  DirectivePerson? target;
  String? source, error;
  List<DirectiveAttachment> attachments = [];
  bool busy = false, uploading = false;
  Future<void> Function()? pending;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  String get title => switch (widget.action) {
        'report' => 'ثبت و ارسال گزارش',
        'approve' => 'تأیید گزارش',
        'return' => 'درخواست اصلاح',
        'transfer' => 'انتقال مسئولیت',
        _ => 'مختومه کردن دستور'
      };
  Future<void> _submit() async {
    if (busy || uploading) return;
    if (pending == null) {
      final action = widget.action;
      final reason = text.text.trim();
      final d = widget.detail;
      if ((['report', 'return', 'transfer'].contains(action) &&
              reason.isEmpty) ||
          (action == 'report' && date == null) ||
          (action == 'transfer' &&
              (target == null ||
                  (d.currentUserId == d.issuer.id && source == null)))) {
        setState(() => error = 'اطلاعات الزامی را کامل کنید.');
        return;
      }
      final key = directiveRequestKey();
      final repo = widget.repository;
      final company = widget.company;
      final chosenDate = date,
          chosenTarget = target,
          chosenSource = source,
          files = List<DirectiveAttachment>.of(attachments);
      pending = () => switch (action) {
            'report' => repo.report(company, d.id,
                doneDate: chosenDate!,
                body: reason,
                attachments: files,
                requestKey: key),
            'approve' || 'return' => repo.review(
                company, d.id, widget.report!.id,
                approve: action == 'approve', reason: reason, requestKey: key),
            'transfer' => repo.transfer(company, d.id,
                recipientId: chosenTarget!.id,
                executorId: chosenSource,
                reason: reason,
                requestKey: key),
            _ => repo.close(company, d.id, requestKey: key),
          };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await pending!();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = directiveError(e);
          if (e is ApiException &&
              [
                ApiFailureKind.validation,
                ApiFailureKind.forbidden,
                ApiFailureKind.conflict
              ].contains(e.kind)) {
            pending = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = busy || pending != null;
    final d = widget.detail;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: AsoudColors.background,
            appBar: AsoudHeader(title: title),
            bottomNavigationBar: DirectiveBottomBar(
                company: widget.company, enabled: !busy && !uploading),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              if (error != null) DirectiveError(error!),
              DirectiveSection(
                  title: d.subject,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.action == 'report')
                          DirectiveDateField(
                              label: 'تاریخ انجام *',
                              value: date,
                              firstDate: d.issueDate ?? d.today,
                              lastDate: d.today,
                              onChanged: locked
                                  ? null
                                  : (v) => setState(() => date = v)),
                        if (widget.action == 'transfer') ...[
                          if (d.currentUserId == d.issuer.id)
                            DropdownButtonFormField<String>(
                                initialValue: source,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'انتقال مسئولیت از *'),
                                items: d.executors
                                    .where((e) => [
                                          'در انتظار انجام',
                                          'نیازمند اصلاح'
                                        ].contains(e.status))
                                    .map((e) => DropdownMenuItem(
                                        value: e.person.id,
                                        child: Text(e.person.name)))
                                    .toList(),
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() => source = v)),
                          OutlinedButton(
                              onPressed: locked
                                  ? null
                                  : () async {
                                      final p = await pickDirectivePerson(
                                          context, d.transferChoices);
                                      if (p != null && mounted) {
                                        setState(() => target = p);
                                      }
                                    },
                              child:
                                  Text(target?.name ?? 'انتخاب گیرنده جدید *')),
                          const Text(
                              'مسئولیت از مجری قبلی به گیرنده جدید منتقل می‌شود؛ سابقه حذف نمی‌شود.'),
                        ],
                        if (widget.action != 'close')
                          TextField(
                              controller: text,
                              readOnly: locked,
                              minLines: 4,
                              maxLines: 8,
                              decoration: InputDecoration(
                                  labelText: widget.action == 'report'
                                      ? 'شرح اقدامات انجام‌شده *'
                                      : widget.action == 'approve'
                                          ? 'توضیح (اختیاری)'
                                          : 'دلیل *')),
                        if (widget.action == 'close')
                          const Text(
                              'آیا تأیید نهایی و اختتام دستور را ثبت می‌کنید؟ این اقدام آن را خودکار بایگانی نمی‌کند.'),
                      ])),
              if (widget.action == 'report')
                DirectiveSection(
                    title: 'پیوست گزارش',
                    color: AsoudColors.warning,
                    collapsible: true,
                    child: DirectiveAttachmentPicker(
                        repository: widget.repository,
                        company: widget.company,
                        directiveId: d.id,
                        policy: d.filePolicy,
                        attachments: attachments,
                        enabled: !locked,
                        onChanged: (v) => setState(() => attachments = v),
                        onBusyChanged: (v) => setState(() => uploading = v))),
              if (busy) const LinearProgressIndicator(),
              FilledButton(
                  onPressed: busy || uploading ? null : _submit,
                  child: Text(pending != null ? 'تلاش دوباره' : title)),
            ])));
  }
}
