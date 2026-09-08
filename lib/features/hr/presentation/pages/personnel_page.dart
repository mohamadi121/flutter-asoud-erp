import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/personnel_repository.dart';
import '../cubit/personnel_cubit.dart';

class PersonnelPage extends StatelessWidget {
  const PersonnelPage({required this.company, this.repository, super.key});
  final String company;
  final PersonnelRepository? repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PersonnelCubit(
            repository ?? PersonnelRepository(context.read<FrappeApiClient>()),
            company)
          ..load(),
        child: const _PersonnelList(),
      );
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice(
      {required this.offline, required this.pending, required this.failed});
  final bool offline, pending, failed;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading:
              Icon(failed ? Icons.error_outline : Icons.cloud_off_outlined),
          title: Text(failed
              ? 'همگام‌سازی نیازمند بررسی است'
              : pending
                  ? 'ذخیره روی گوشی؛ در انتظار همگام‌سازی'
                  : 'نمایش نسخه ذخیره‌شده روی گوشی'),
          subtitle: Text(failed
              ? 'سرور تغییر را نپذیرفته است؛ اطلاعات محلی حذف نشده‌اند.'
              : 'برای بررسی اتصال و ارسال تغییرات، فهرست پرسنل را تازه کنید.'),
        ),
      );
}

class _PersonnelList extends StatelessWidget {
  const _PersonnelList();
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AsoudHeader(
            title: 'لیست پرسنل', subtitle: 'پرونده‌های پرسنلی دفتر'),
        body: BlocBuilder<PersonnelCubit, PersonnelState>(
            builder: (context, state) {
          final cubit = context.read<PersonnelCubit>();
          return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                      onChanged: (v) => cubit.filter(query: v),
                      decoration: const InputDecoration(
                          hintText: 'جست‌وجوی نام، کد ملی یا سمت',
                          prefixIcon: Icon(Icons.search))),
                  const SizedBox(height: 12),
                  if (cubit.repository.localDemo)
                    const Text(
                        'حالت تست محلی: فقط پرسنل محلی این دفتر؛ سوابق جدید فعلاً به سرور ارسال نمی‌شوند.'),
                  if (state.offline || state.pendingSync || state.syncFailed)
                    _SyncNotice(
                        offline: state.offline,
                        pending: state.pendingSync,
                        failed: state.syncFailed),
                  Wrap(spacing: 8, children: [
                    for (final entry in {
                      'all': 'همه',
                      'active': 'فعال',
                      'inactive': 'غیرفعال'
                    }.entries)
                      ChoiceChip(
                          label: Text(entry.value),
                          selected: state.status == entry.key,
                          onSelected: (_) => cubit.filter(status: entry.key)),
                    ActionChip(
                        label: const Text('فیلتر واحد'),
                        avatar: const Icon(Icons.filter_list),
                        onPressed: () async {
                          final departments = state.rows
                              .map((r) => '${r['department'] ?? ''}')
                              .where((s) => s.isNotEmpty)
                              .toSet();
                          final value = await showModalBottomSheet<String>(
                              context: context,
                              builder: (ctx) => SafeArea(
                                      child:
                                          ListView(shrinkWrap: true, children: [
                                    ListTile(
                                        title: const Text('همه واحدها'),
                                        onTap: () => Navigator.pop(ctx, '')),
                                    for (final d in departments)
                                      ListTile(
                                          title: Text(d),
                                          onTap: () => Navigator.pop(ctx, d)),
                                  ])));
                          if (value != null && context.mounted) {
                            cubit.filter(department: value);
                          }
                        }),
                  ]),
                  if (state.department.isNotEmpty)
                    Text('واحد: ${state.department}'),
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.error != null)
                    ListTile(
                        title: Text(state.error!),
                        trailing: IconButton(
                            onPressed: cubit.load,
                            icon: const Icon(Icons.refresh))),
                  if (!state.loading &&
                      state.error == null &&
                      state.visible.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('پرسنلی با این مشخصات وجود ندارد.')),
                  for (final person in state.visible)
                    Card(
                        child: ListTile(
                      leading: _PersonnelPhoto(
                          recordId: person['photo_record'] as String?,
                          repository: cubit.repository),
                      title: Text('${person['display_name']}'),
                      subtitle: Text(
                          '${person['job_title']}\n${person['department']}'),
                      isThreeLine: true,
                      trailing: Chip(
                          label: Text(
                              person['disabled'] == true ? 'غیرفعال' : 'فعال')),
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => PersonnelDetailPage(
                                    id: person['id'] as String,
                                    repository: cubit.repository)));
                        if (context.mounted) await cubit.load();
                      },
                    )),
                ],
              ));
        }),
      ));
}

const _personal = {
  'display_name': 'نام و نام خانوادگی',
  'national_id': 'کد ملی',
  'birth_date': 'تاریخ تولد',
  'employee_gender': 'جنسیت',
  'father_name': 'نام پدر',
  'mobile': 'موبایل',
  'phone': 'تلفن',
  'email': 'ایمیل',
  'province': 'استان',
  'city': 'شهر',
  'address_line': 'نشانی',
  'postal_code': 'کد پستی'
};
const _organization = {
  'job_title': 'سمت',
  'department': 'واحد سازمانی',
  'date_of_joining': 'تاریخ استخدام',
  'employment_type': 'نوع همکاری'
};
const _sections = {
  'attendance': 'کارکرد و سوابق حضور',
  'document': 'مدارک و مستندات',
  'evaluation': 'ارزیابی عملکرد',
  'history': 'تاریخچه',
  'photo': 'تصویر پرسنل'
};

class _PersonnelPhoto extends StatefulWidget {
  const _PersonnelPhoto({required this.recordId, required this.repository});
  final String? recordId;
  final PersonnelRepository repository;
  @override
  State<_PersonnelPhoto> createState() => _PersonnelPhotoState();
}

class _PersonnelPhotoState extends State<_PersonnelPhoto> {
  Future<Map<String, dynamic>>? photo;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(_PersonnelPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId) load();
  }

  void load() {
    photo = widget.recordId == null
        ? null
        : widget.repository.record(widget.recordId!);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 52,
      height: 52,
      child: FutureBuilder<Map<String, dynamic>>(
          future: photo,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const CircleAvatar(
                  child: Icon(Icons.broken_image_outlined));
            }
            final file = snapshot.data?['file'];
            if (file is! String) {
              return const CircleAvatar(child: Icon(Icons.person_outline));
            }
            return ClipOval(
                child: Image.memory(base64Decode(file),
                    fit: BoxFit.cover,
                    cacheWidth: 104,
                    errorBuilder: (_, error, trace) =>
                        const Icon(Icons.broken_image_outlined)));
          }));
}

class PersonnelDetailPage extends StatefulWidget {
  const PersonnelDetailPage(
      {required this.id, required this.repository, super.key});
  final String id;
  final PersonnelRepository repository;
  @override
  State<PersonnelDetailPage> createState() => _PersonnelDetailState();
}

class _PersonnelDetailState extends State<PersonnelDetailPage> {
  bool _importing = false;
  String? _operationMessage;
  Future<void> _import(Map<String, dynamic> target) async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _operationMessage = null;
    });
    try {
      final candidates = await widget.repository.localImportCandidates();
      if (!mounted) return;
      if (candidates.isEmpty) {
        setState(() => _operationMessage =
            'پرسنل محلی برای انتقال در این دفتر وجود ندارد.');
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          builder: (ctx) => SafeArea(
                  child: ListView(shrinkWrap: true, children: [
                const ListTile(title: Text('انتخاب پرسنل محلی')),
                for (final person in candidates)
                  ListTile(
                      title: Text('${person['display_name']}'),
                      subtitle: Text(
                          'کد ملی: ${person['national_id']} · ${person['id']}'),
                      onTap: () => Navigator.pop(ctx, person)),
              ])));
      if (selected == null || !mounted) return;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('تأیید اتصال پرونده‌ها'),
                content: Text(
                    'سوابق «${selected['display_name']}» (${selected['id']}) به پرونده «${target['display_name']}» (${widget.id}) منتقل شود؟\nمشخصات پایه و مالی تغییر نمی‌کنند و نسخه محلی باقی می‌ماند.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأیید انتقال'))
                ],
              ));
      if (confirmed != true) return;
      await widget.repository
          .importLocalRecords('${selected['id']}', widget.id);
      if (mounted) {
        setState(() => _operationMessage =
            'انتقال ثبت شد؛ وضعیت ارسال در پرونده نمایش داده می‌شود.');
        reload();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _operationMessage =
            'انتقال تکمیل نشد؛ ${error is StateError ? error.message : 'اتصال و دسترسی را بررسی کنید.'}');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _retrySync() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await widget.repository.retryFailed(widget.id);
      if (mounted) reload();
    } catch (_) {
      if (mounted) {
        setState(() => _operationMessage =
            'ارسال مجدد انجام نشد؛ اتصال، دسترسی یا تعارض ویرایش را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  late Future<Map<String, dynamic>> future =
      widget.repository.detail(widget.id);
  void reload() => setState(() => future = widget.repository.detail(widget.id));
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AsoudHeader(
            title: 'پرونده پرسنلی', subtitle: 'اطلاعات فردی و سازمانی'),
        body: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return Center(
                    child: TextButton(
                        onPressed: reload,
                        child:
                            const Text('دریافت پرونده ممکن نشد؛ تلاش دوباره')));
              }
              final data = snapshot.data!;
              final profile = Map<String, dynamic>.from(data['profile'] as Map);
              final records = (data['records'] as List).cast<Map>();
              final canEdit = data['can_edit'] == true;
              return ListView(padding: const EdgeInsets.all(16), children: [
                if (_importing) const LinearProgressIndicator(),
                if (_operationMessage != null) Text(_operationMessage!),
                if (data['offline'] == true ||
                    data['pending_sync'] == true ||
                    data['sync_failed'] == true)
                  _SyncNotice(
                      offline: data['offline'] == true,
                      pending: data['pending_sync'] == true,
                      failed: data['sync_failed'] == true),
                if (canEdit && data['sync_failed'] == true)
                  TextButton(
                      onPressed: _importing ? null : _retrySync,
                      child: const Text('تلاش مجدد برای همگام‌سازی')),
                if (canEdit && !widget.id.startsWith('LOCAL-'))
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: const Text('انتقال سوابق پرسنل محلی'),
                          subtitle: const Text(
                              'انتخاب و تأیید پرونده مبدأ؛ بدون تغییر اطلاعات مالی'),
                          onTap: _importing ? null : () => _import(profile))),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          _PersonnelPhoto(
                              recordId: profile['photo_record'] as String?,
                              repository: widget.repository),
                          Text('${profile['display_name']}',
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(
                              '${profile['job_title']} · ${profile['department']}'),
                          Chip(
                              label: Text(profile['disabled'] == true
                                  ? 'غیرفعال'
                                  : 'فعال')),
                        ]))),
                for (final section in {
                  'اطلاعات فردی': _personal,
                  'اطلاعات سازمانی': _organization
                }.entries)
                  Card(
                      child: ListTile(
                          title: Text(section.key),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => _ProfileFields(
                                        title: section.key,
                                        labels: section.value,
                                        profile: profile,
                                        canEdit: canEdit,
                                        revision: '${data['revision']}',
                                        repository: widget.repository)));
                            if (mounted) reload();
                          })),
                for (final section in _sections.entries)
                  Card(
                      child: ListTile(
                          title: Text(section.value),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => _RecordsPage(
                                        personId: widget.id,
                                        kind: section.key,
                                        canEdit: canEdit,
                                        repository: widget.repository,
                                        records: records
                                            .where(
                                                (r) => r['kind'] == section.key)
                                            .toList())));
                            if (mounted) reload();
                          })),
              ]);
            }),
      ));
}

class _ProfileFields extends StatefulWidget {
  const _ProfileFields(
      {required this.title,
      required this.labels,
      required this.profile,
      required this.canEdit,
      required this.revision,
      required this.repository});
  final String title, revision;
  final Map<String, String> labels;
  final Map<String, dynamic> profile;
  final bool canEdit;
  final PersonnelRepository repository;
  @override
  State<_ProfileFields> createState() => _ProfileFieldsState();
}

class _ProfileFieldsState extends State<_ProfileFields> {
  late final fields = {
    for (final key in widget.labels.keys)
      key: TextEditingController(text: '${widget.profile[key] ?? ''}')
  };
  bool editing = false, saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AsoudHeader(
              title: widget.title,
              subtitle: 'اطلاعات مشترک با اشخاص و شرکت‌ها'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final entry in widget.labels.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                      controller: fields[entry.key],
                      readOnly: !editing || saving,
                      decoration: InputDecoration(labelText: entry.value))),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (widget.canEdit)
              FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!editing) {
                            setState(() => editing = true);
                            return;
                          }
                          setState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await widget.repository.update(
                                '${widget.profile['id']}',
                                {
                                  for (final e in fields.entries)
                                    e.key: e.value.text.trim()
                                },
                                widget.revision);
                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                saving = false;
                                error =
                                    'ذخیره انجام نشد؛ اتصال، مقادیر و تغییر هم‌زمان پرونده را بررسی کنید.';
                              });
                            }
                          }
                        },
                  child: Text(saving
                      ? 'در حال ذخیره'
                      : editing
                          ? 'ذخیره'
                          : 'ویرایش')),
          ])));
}

class _RecordsPage extends StatelessWidget {
  const _RecordsPage(
      {required this.personId,
      required this.kind,
      required this.canEdit,
      required this.repository,
      required this.records});
  final String personId, kind;
  final bool canEdit;
  final PersonnelRepository repository;
  final List<Map> records;
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AsoudHeader(
              title: _sections[kind]!, subtitle: 'سوابق ثبت‌شده پرسنل'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (records.isEmpty) const Text('هنوز موردی ثبت نشده است.'),
            for (final record in records)
              Card(
                  child: ListTile(
                title: Text('${record['title']}'),
                subtitle: Text(
                    '${record['record_date']}${record['pending_sync'] == true ? ' · ذخیره روی گوشی' : ''}'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                              appBar: AsoudHeader(
                                  title: '${record['title']}', subtitle: ''),
                              body: FutureBuilder<Map<String, dynamic>>(
                                  future:
                                      repository.record('${record['name']}'),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Center(
                                          child:
                                              Text('دریافت سابقه ممکن نشد.'));
                                    }
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    final value = snapshot.data!;
                                    return ListView(
                                        padding: const EdgeInsets.all(16),
                                        children: [
                                          for (final key in [
                                            'date',
                                            'notes',
                                            'start',
                                            'end',
                                            'score'
                                          ])
                                            if (value[key] != null)
                                              ListTile(
                                                  title: Text({
                                                    'date': 'تاریخ',
                                                    'notes': 'توضیحات',
                                                    'start': 'ورود',
                                                    'end': 'خروج',
                                                    'score': 'امتیاز'
                                                  }[key]!),
                                                  subtitle:
                                                      Text('${value[key]}')),
                                          if (value['file'] != null &&
                                              kind == 'photo')
                                            Image.memory(base64Decode(
                                                value['file'] as String)),
                                          if (value['file'] != null)
                                            TextButton(
                                                onPressed: () async {
                                                  await FilePicker.platform
                                                      .saveFile(
                                                          fileName:
                                                              '${value['filename'] ?? 'document'}',
                                                          bytes: base64Decode(
                                                              value['file']
                                                                  as String));
                                                },
                                                child:
                                                    const Text('ذخیره فایل')),
                                        ]);
                                  }),
                            ))),
              )),
            if (canEdit)
              FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('ثبت مورد جدید'),
                  onPressed: () async {
                    final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(
                            builder: (_) => _RecordForm(
                                personId: personId,
                                kind: kind,
                                repository: repository)));
                    if (saved == true && context.mounted) {
                      Navigator.pop(context);
                    }
                  }),
          ])));
}

class _RecordForm extends StatefulWidget {
  const _RecordForm(
      {required this.personId, required this.kind, required this.repository});
  final String personId, kind;
  final PersonnelRepository repository;
  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final fields = {
    for (final k in ['title', 'date', 'notes', 'start', 'end', 'score'])
      k: TextEditingController()
  };
  final requestId = 'mobile-${DateTime.now().microsecondsSinceEpoch}';
  PlatformFile? file;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AsoudHeader(
              title: 'ثبت ${_sections[widget.kind]}',
              subtitle: 'اطلاعات واقعی پرسنل'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final entry in {
              'title': 'عنوان',
              'date': 'تاریخ میلادی YYYY-MM-DD',
              'notes': 'توضیحات',
              if (widget.kind == 'attendance') ...{
                'start': 'ورود HH:mm',
                'end': 'خروج HH:mm'
              },
              if (widget.kind == 'evaluation') 'score': 'امتیاز از ۱۰۰'
            }.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                      enabled: !saving,
                      controller: fields[entry.key],
                      decoration: InputDecoration(labelText: entry.value))),
            if (widget.kind == 'photo' || widget.kind == 'document')
              OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                              withData: true,
                              type: FileType.custom,
                              allowedExtensions: widget.kind == 'photo'
                                  ? ['jpg', 'jpeg', 'png']
                                  : ['pdf', 'jpg', 'jpeg', 'png']);
                          if (result != null && mounted) {
                            setState(() => file = result.files.single);
                          }
                        },
                  child: Text(file?.name ?? 'انتخاب فایل؛ حداکثر ۵ مگابایت')),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (fields['title']!.text.trim().isEmpty ||
                            DateTime.tryParse(fields['date']!.text) == null ||
                            ((widget.kind == 'photo' ||
                                    widget.kind == 'document') &&
                                (file?.bytes == null ||
                                    file!.size > 5 * 1024 * 1024))) {
                          setState(() =>
                              error = 'عنوان، تاریخ و فایل را بررسی کنید.');
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await widget.repository.add(
                              widget.personId,
                              {
                                'kind': widget.kind,
                                for (final e in fields.entries)
                                  if (e.key != 'score')
                                    e.key: e.value.text.trim(),
                                if (widget.kind == 'evaluation')
                                  'score': num.tryParse(fields['score']!.text),
                                if (file?.bytes != null) ...{
                                  'file': base64Encode(file!.bytes!),
                                  'filename': file!.name
                                },
                              },
                              requestId);
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              saving = false;
                              error =
                                  'ثبت انجام نشد؛ مقادیر، اتصال و دسترسی را بررسی کنید.';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'در حال ثبت' : 'ذخیره')),
          ])));
}
