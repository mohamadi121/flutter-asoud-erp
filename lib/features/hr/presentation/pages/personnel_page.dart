import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/auth/capabilities.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../domain/personnel_file.dart';
import '../../domain/personnel_record.dart';
import '../../data/personnel_file_repository.dart';
import '../../data/personnel_repository.dart';
import '../cubit/personnel_cubit.dart';

import '../../../parties/domain/entities/party_profile.dart';
import '../../../parties/presentation/pages/party_form_page.dart';
import '../../../parties/domain/repositories/party_repository.dart';
import 'hr_home_page.dart';
part 'personnel_design.dart';
part 'personnel_forms.dart';
part 'personnel_file_capabilities.dart';
part 'personnel_cap_contracts.dart';
part 'personnel_cap_documents.dart';
part 'personnel_cap_activity.dart';
part 'personnel_photo_editor.dart';

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

const _personal = {
  'display_name': 'نام و نام خانوادگی',
  'national_id': 'کد ملی',
  'birth_date': 'تاریخ تولد',
  'employee_gender': 'جنسیت',
  'father_name': 'نام پدر',
  'marital_status': 'وضعیت تأهل',
  'blood_group': 'گروه خونی',
  'company_email': 'ایمیل سازمانی',
  'emergency_contact_name': 'نام تماس اضطراری',
  'emergency_phone': 'تلفن اضطراری',
  'emergency_relation': 'نسبت تماس اضطراری',
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
  'employment_type': 'نوع همکاری',
  'branch': 'شعبه',
  'reports_to': 'مدیر مستقیم',
  'final_confirmation_date': 'پایان دوره آزمایشی',
  'contract_end_date': 'پایان قرارداد',
  'notice_number_of_days': 'مهلت اعلام (روز)',
};
const _benefits = {
  'base_salary': 'حقوق پایه',
  'housing_allowance': 'حق مسکن',
  'transport_allowance': 'حق ایاب و ذهاب',
  'other_allowances': 'سایر مزایا',
  'deductions': 'کسورات',
  'net_salary': 'حقوق خالص'
};

class _PersonnelPhoto extends StatefulWidget {
  const _PersonnelPhoto(
      {required this.recordId, required this.repository, this.size = 52,
      this.portrait = false, super.key});
  final double size;
  final String? recordId;
  final PersonnelRepository repository;
  final bool portrait;
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
    if (oldWidget.recordId != widget.recordId ||
        oldWidget.repository != widget.repository) {
      load();
    }
  }

  void load() {
    photo = widget.recordId == null
        ? null
        : widget.repository.record(widget.recordId!);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<Map<String, dynamic>>(
          future: photo,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const CircleAvatar(
                  child: Icon(Icons.broken_image_outlined));
            }
            final file = snapshot.connectionState == ConnectionState.done
                ? (snapshot.data?['file'])
                : null;
            if (file is! String || file.isEmpty) {
              return Container(
                  decoration: BoxDecoration(
                      color: widget.portrait ? Colors.white : const Color(0xFFE5F0FA),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.person_outline_rounded,
                      color: widget.portrait ? _blue : const Color(0xFF8BAAC1),
                      size: widget.size * (widget.portrait ? .34 : .65)));
            }
            Uint8List bytes;
            try {
              bytes = base64Decode(file);
            } on FormatException {
              return const Icon(Icons.broken_image_outlined);
            }
            final image = ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                    cacheWidth: (widget.size * 2).round(),
                    errorBuilder: (_, error, trace) =>
                        const Icon(Icons.broken_image_outlined)));
            if (!widget.portrait) return image;
            return InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(alignment: Alignment.topLeft, children: [
                    AspectRatio(aspectRatio: 1, child: Image.memory(bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, trace) =>
                            const Icon(Icons.broken_image_outlined))),
                    CloseButton(onPressed: () => Navigator.pop(context)),
                  ]),
                ),
              ),
              child: Semantics(label: 'مشاهده عکس پرسنل', child: image),
            );
          }));
}

class PersonnelDetailPage extends StatefulWidget {
  const PersonnelDetailPage(
      {required this.id,
      required this.repository,
      this.fileRepository,
      this.imagePicker,
      super.key});
  final String id;
  final PersonnelRepository repository;
  final PersonnelFileRepository? fileRepository;
  final ImagePicker? imagePicker;
  @override
  State<PersonnelDetailPage> createState() => _PersonnelDetailState();
}

class _PersonnelDetailState extends State<PersonnelDetailPage> {
  int _selectedTab = 0;
  void _selectTab(int value) => setState(() => _selectedTab = value);
  bool _importing = false;
  String? _operationMessage;
  PersonnelFileRepository? _fileRepository;
  late Future<_PersonnelBundle> future;
  late Future<Capabilities> _capabilities;

  @override
  void initState() {
    super.initState();
    _fileRepository = widget.fileRepository ?? _contextFileRepository();
    _capabilities = capabilitiesOf(context);
    future = _load();
  }

  /// The file repository comes from the injected one, or from the app-wide
  /// client. Pages built without a client (e.g. injected repositories in tests)
  /// simply skip the file-only capabilities.
  PersonnelFileRepository? _contextFileRepository() {
    try {
      return PersonnelFileRepository(context.read<FrappeApiClient>());
    } catch (_) {
      return null;
    }
  }

  Future<_PersonnelBundle> _load() async {
    final photoSession =
        context.read<FrappeApiClient?>()?.isAuthenticated ?? false;
    final data = await widget.repository.detail(widget.id);
    final file = await loadPersonnelFile(
      id: widget.id,
      repository: widget.repository,
      fileRepository: _fileRepository,
      detail: data,
    );
    final capabilities = await _capabilities;
    return _PersonnelBundle(
      data: data,
      file: file,
      allowedEdit:
          capabilities.canWritePersonnel && data['can_edit'] == true,
      allowedPhotoEdit: capabilities.canManageOrganization &&
          data['can_edit'] == true && data['offline'] != true &&
          !isLocalPersonnelId(widget.id) &&
          data['profile']['needs_employee_details'] != true &&
          photoSession,
    );
  }

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

  void reload() => setState(() {
        future = _load();
      });
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: _personnelHeader(context, 'پرونده پرسنلی',
            action: IconButton(
                tooltip: 'مدارک پرسنلی',
                onPressed: () => _selectTab(3),
                icon: const Icon(Icons.description_outlined, size: 20))),
        body: FutureBuilder<_PersonnelBundle>(
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
              final bundle = snapshot.data!;
              final data = bundle.data;
              final profile = Map<String, dynamic>.from(data['profile'] as Map);
              final records = (data['records'] as List).cast<Map>();
              final canEdit = bundle.allowedEdit;
              return ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16,
                      MediaQuery.viewPaddingOf(context).bottom + 88),
                  children: [
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
                _PersonnelOverview(
                    tab: _selectedTab,
                    onTab: _selectTab,
                    imagePicker: widget.imagePicker,
                    profile: profile,
                    records: records,
                    repository: widget.repository,
                    file: bundle.file,
                    fileRepository: _fileRepository,
                    canEdit: canEdit,
                    canEditPhoto: bundle.allowedPhotoEdit,
                    onPhotoSaved: reload,
                    onCategory: (category) async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (_) => _PersonnelCategoryPage(
                          category: category,
                          profile: profile,
                          repository: widget.repository,
                          fileRepository: _fileRepository,
                          canEdit: canEdit,
                        )),
                      );
                      if (mounted) reload();
                    },
                    onProfile: (title, labels) async {
                      await Navigator.push<bool>(
                          context,
                          MaterialPageRoute<bool>(
                              builder: (_) => title.startsWith('ویرایش')
                                      ? _ProfileEditor(
                                          title: title,
                                          labels: labels,
                                          profile: profile,
                                          revision: '${data['revision']}',
                                          repository: widget.repository)
                                      : _ProfileFields(
                                          title: title,
                                          labels: labels,
                                          profile: profile,
                                          canEdit: canEdit,
                                          revision: '${data['revision']}',
                                          repository: widget.repository)));
                      if (mounted) reload();
                    },
                    onRecord: (record) async {
                      await Navigator.push<bool>(
                          context,
                          MaterialPageRoute<bool>(
                              builder: (_) => _RecordDetailPage(
                                  personId: widget.id,
                                  recordId: '${record['name']}',
                                  canEdit: canEdit,
                                  repository: widget.repository)));
                      if (mounted) reload();
                    },
                    onRecords: (kind) async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => _RecordsPage(
                                  personId: widget.id,
                                  kind: kind,
                                  canEdit: canEdit,
                                  repository: widget.repository,
                                  records: records
                                      .where((r) =>
                                          kind == 'all' || r['kind'] == kind)
                                      .toList())));
                      if (mounted) reload();
                    }),
                if (canEdit && !widget.id.startsWith('LOCAL-'))
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: const Text('انتقال سوابق پرسنل محلی'),
                          subtitle: const Text(
                              'انتخاب و تأیید پرونده مبدأ؛ بدون تغییر اطلاعات مالی'),
                          onTap: _importing ? null : () => _import(profile))),
              ]);
            }),
      ));
}

class _PersonnelBundle {
  const _PersonnelBundle(
      {required this.data, required this.file, required this.allowedEdit,
      required this.allowedPhotoEdit});
  final Map<String, dynamic> data;
  final PersonnelFile? file;

  /// Server edit flag combined with the presentation capability policy, so an
  /// HR Manager keeps read access without edit or transfer controls.
  final bool allowedEdit;
  final bool allowedPhotoEdit;
}
