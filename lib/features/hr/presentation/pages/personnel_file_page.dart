part of 'personnel_page.dart';

String _fileValue(String? value) =>
    value == null || value.trim().isEmpty ? '—' : value;

/// Latin/ASCII-number values (O+, emails, codes) are laid out LTR; anything
/// with Persian/Arabic script, including Persian digits, stays RTL.
bool _isLtrValue(String value) =>
    !RegExp(r'\p{Script=Arabic}', unicode: true).hasMatch(value) &&
    RegExp(r'[A-Za-z0-9]').hasMatch(value);

Widget _fileValueText(String value,
    {TextStyle? style, TextAlign? textAlign, int? maxLines}) {
  final ltr = _isLtrValue(value);
  return Directionality(
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      child: Text(_fileValue(value),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis));
}

String _fileDate(String value) => _fileValue(formatJalaliIso(value));
String _fileError(Object error) => switch (error) {
      ApiException() => error.message,
      StateError() => error.message,
      FormatException() => error.message,
      _ => 'دریافت یا ذخیره اطلاعات انجام نشد؛ دوباره تلاش کنید.',
    };
String _fileLabel(String value) =>
    const {
      'Male': 'مرد',
      'Female': 'زن',
      'Other': 'سایر',
      'Single': 'مجرد',
      'Married': 'متأهل',
      'Divorced': 'مطلقه',
      'Widowed': 'همسر فوت‌شده',
      'Active': 'فعال',
      'Inactive': 'غیرفعال',
      'Left': 'پایان همکاری',
      'Suspended': 'تعلیق',
      'Full-time': 'تمام وقت',
      'Part-time': 'پاره وقت',
      'Contract': 'قراردادی',
      'Intern': 'کارآموز',
      'Internship': 'کارآموزی',
      'Temporary': 'موقت',
      'Permanent': 'دائم',
      'Graduate': 'کارشناسی',
      'Post Graduate': 'کارشناسی ارشد',
      'Under Graduate': 'دانشجو',
      'Casual Leave': 'مرخصی استحقاقی',
      'Sick Leave': 'مرخصی استعلاجی',
      'Privilege Leave': 'مرخصی استحقاقی',
      'Leave Without Pay': 'مرخصی بدون حقوق',
    }[value] ??
    _fileValue(value);

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .take(2)
    .map((word) => word.characters.first)
    .join(' ');

String _fileDetails(String details) {
  var result = details;
  for (final entry in const {
    'Designation': 'سمت',
    'Department': 'واحد',
    'Branch': 'شعبه',
    'Reports To': 'مدیر مستقیم',
    'Salary Structure': 'ساختار حقوقی',
  }.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

ContractSummary? _currentContract(PersonnelFile file) {
  for (final contract in file.contracts) {
    if (contract.state == 'active' || contract.state == 'upcoming') {
      return contract;
    }
  }
  return null;
}

String _daysRemaining(ContractSummary contract) =>
    contract.daysRemaining == null
        ? '—'
        : '${toPersianDigits(contract.daysRemaining!)} روز مانده';

/// The overview speaks in contract terms, not employee-status terms, so an
/// active contract reads «در جریان» rather than the generic «فعال».
String _contractStateLabel(ContractSummary contract) =>
    switch (contract.state) {
      'active' => 'در جریان',
      'upcoming' => 'آینده',
      'expired' => 'منقضی',
      _ => contract.stateLabel,
    };

IconData _fileEventIcon(String kind, String title) => switch (kind) {
      'joining' => Icons.person_add,
      'internal' => Icons.swap_horiz,
      'promotion' => Icons.trending_up,
      'transfer' => Icons.compare_arrows,
      'contract' => Icons.description,
      'salary' => Icons.payments,
      'attendance' => Icons.event_available_outlined,
      'evaluation' => Icons.star_border_rounded,
      'document' => Icons.description_outlined,
      'photo' => Icons.photo_outlined,
      'relieving' => Icons.logout,
      _ => _fileTitleIcon(title),
    };

/// The activity feed carries no `kind`, so the icon is read off the Persian
/// title instead of always showing the generic history glyph.
IconData _fileTitleIcon(String title) {
  for (final (words, icon) in [
    (['قرارداد', 'تمدید'], Icons.description),
    (['ارتقا', 'تغییر سمت', 'سمت'], Icons.trending_up),
    (['حقوق', 'دستمزد', 'مزایا'], Icons.payments),
    (['حضور', 'غیاب', 'کارکرد'], Icons.event_available_outlined),
    (['مدرک', 'مدارک', 'گواهی'], Icons.description_outlined),
    (['تصویر', 'پروفایل'], Icons.photo_outlined),
  ]) {
    if (words.any(title.contains)) return icon;
  }
  return Icons.history;
}

Color _fileEventColor(String kind) => switch (kind) {
      'joining' => AsoudColors.success,
      'promotion' => AsoudColors.purple,
      'salary' => AsoudColors.warning,
      'relieving' => AsoudColors.danger,
      'transfer' => AsoudColors.cyan,
      _ => AsoudColors.primary,
    };

class PersonnelFilePage extends StatefulWidget {
  const PersonnelFilePage(
      {required this.profileId,
      this.repository,
      this.personnel,
      this.initialTab = 0,
      super.key})
      : mine = false;
  const PersonnelFilePage.mine(
      {this.repository, this.personnel, this.initialTab = 0, super.key})
      : profileId = null,
        mine = true;
  final String? profileId;
  final PersonnelFileRepository? repository;
  final PersonnelRepository? personnel;
  final int initialTab;
  final bool mine;
  @override
  State<PersonnelFilePage> createState() => _PersonnelFilePageState();
}

class _PersonnelFilePageState extends State<PersonnelFilePage>
    with SingleTickerProviderStateMixin {
  late final PersonnelFileRepository repository;
  late final PersonnelRepository personnel;
  late final TabController tabs;
  PersonnelFile? file;
  String? error;
  bool loading = true;
  bool legacy = false;
  String category = '';
  Map<String, dynamic>? detail;
  bool _importing = false;
  String? _operationMessage;
  Future<void> _import(Map<String, dynamic> target) async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _operationMessage = null;
    });
    try {
      final candidates = await personnel.localImportCandidates();
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
                    'سوابق «${selected['display_name']}» (${selected['id']}) به پرونده «${target['display_name']}» (${file!.profileId}) منتقل شود؟\nمشخصات پایه و مالی تغییر نمی‌کنند و نسخه محلی باقی می‌ماند.'),
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
      await personnel.importLocalRecords('${selected['id']}', file!.profileId);
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
      await personnel.retryFailed(file!.profileId);
      if (mounted) {
        final extra = await personnel.detail(file!.profileId);
        setState(() => detail = extra);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _operationMessage =
            'ارسال مجدد انجام نشد؛ اتصال، دسترسی یا تعارض ویرایش را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  int request = 0;
  bool get canEdit => !widget.mine && file?.canEdit == true;

  @override
  void initState() {
    super.initState();
    repository = widget.repository ??
        PersonnelFileRepository(context.read<FrappeApiClient>());
    personnel = widget.personnel ??
        PersonnelRepository(context.read<FrappeApiClient>());
    tabs = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    tabs.addListener(_tabChanged);
    reload();
  }

  void _tabChanged() => setState(() {});
  @override
  void dispose() {
    tabs.dispose();
    if (widget.personnel == null) personnel.dispose();
    super.dispose();
  }

  /// Falls back to the older detail payload when the file API is unreachable,
  /// missing on the server, or the profile exists only on this device.
  Future<(PersonnelFile, bool)> _load() async {
    if (widget.mine) return (await repository.myFile(), false);
    final id = widget.profileId!;
    try {
      return (await repository.file(id), false);
    } catch (error, stack) {
      if (!canUseLegacyPersonnelFile(error) &&
          !isLocalPersonnelId(id) &&
          !personnel.localDemo) {
        rethrow;
      }
      try {
        detail = await personnel.detail(id);
        return (personnelFileFromLegacy(detail!), true);
      } catch (_) {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }

  Future<void> reload() async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final (value, fallback) = await _load();
      if (mounted && current == request) {
        setState(() {
          file = value;
          legacy = fallback;
        });
      }
      if (!fallback) {
        try {
          final extra = await personnel.detail(value.profileId);
          if (mounted && current == request) setState(() => detail = extra);
        } catch (_) {
          /* The file endpoint remains usable without the legacy endpoint. */
        }
      }
    } catch (e) {
      if (mounted && current == request) setState(() => error = _fileError(e));
    } finally {
      if (mounted && current == request) setState(() => loading = false);
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.push<void>(
        context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await reload();
  }

  void edit() => tabs.animateTo(1);
  Future<void> more() async {
    final choice = await showModalBottomSheet<int>(
        context: context,
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (index, title) in [
                'افزودن قرارداد',
                'ثبت ارتقا یا تغییر سمت',
                'افزودن مدرک',
                if (!isLocalPersonnelId(file!.profileId))
                  'انتقال سوابق پرسنل محلی'
              ].indexed)
                if (!legacy || index >= 2)
                  ListTile(
                      title: Text(title),
                      onTap: () => Navigator.pop(context, index)),
            ]))));
    if (!mounted || choice == null || !canEdit) return;
    switch (choice) {
      case 0:
        await open(ContractFormPage(
            profileId: file!.profileId, repository: repository));
      case 1:
        await open(PromotionFormPage(
            profileId: file!.profileId,
            repository: repository,
            personnel: personnel));
      case 2:
        await open(_RecordForm(
            personId: file!.profileId,
            kind: 'document',
            repository: personnel));
      case 3:
        await _import({'display_name': file!.header.name});
    }
  }

  Widget overview(PersonnelFile value) {
    final contract = _currentContract(value);
    final manager = value.organization.reportsTo;
    final attention = value.documents
        .where((doc) => doc.status == 'expired' || doc.status == 'expiring')
        .length;
    // Fixed reading order: who you report to, how you are employed, since when,
    // how long, on what contract, and what still needs paperwork.
    final summaries = <_FileSummarySpec>[
      _FileSummarySpec(
          icon: Icons.supervisor_account_outlined,
          label: 'مدیر مستقیم',
          value: _fileValue(manager?.name),
          hint: manager == null ? null : _fileValue(manager.designation),
          onTap: manager == null || manager.employee.isEmpty
              ? null
              : () => open(PersonnelFilePage(
                  profileId: manager.employee,
                  repository: repository,
                  personnel: personnel))),
      _FileSummarySpec(
          icon: Icons.work_outline,
          label: 'نوع همکاری',
          value: _fileLabel(value.header.employmentType),
          hint: _fileValue(value.header.departmentName)),
      _FileSummarySpec(
          icon: Icons.calendar_month_outlined,
          label: 'تاریخ شروع همکاری',
          value: value.header.dateOfJoining.isEmpty
              ? 'ثبت نشده'
              : _fileDate(value.header.dateOfJoining)),
      _FileSummarySpec(
          icon: Icons.timelapse,
          label: 'سابقه خدمت',
          value: value.header.serviceLength?.label ?? 'ثبت نشده'),
      _FileSummarySpec(
          icon: Icons.description_outlined,
          label: 'قرارداد جاری',
          value: contract == null ? 'ثبت نشده' : _fileDate(contract.endDate),
          hint: contract == null ? null : _daysRemaining(contract),
          chip: contract == null
              ? null
              : _FileChip(_contractStateLabel(contract),
                  color: contract.state == 'active'
                      ? AsoudColors.success
                      : contract.state == 'expired'
                          ? AsoudColors.danger
                          : AsoudColors.warning),
          onTap: () => open(_FileSectionPage(
              section: 'قراردادها',
              file: value,
              canEdit: canEdit,
              mine: widget.mine,
              repository: repository,
              personnel: personnel))),
      _FileSummarySpec(
          icon: Icons.folder_outlined,
          label: 'وضعیت مدارک',
          value: attention == 0
              ? 'همه معتبر'
              : '${toPersianDigits(attention)} مورد نیازمند اقدام',
          hint: 'از ${toPersianDigits(value.documents.length)} مورد',
          onTap: () => tabs.animateTo(3)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AsoudSectionTitle(title: 'خلاصه اطلاعات'),
      for (var i = 0; i < summaries.length; i += 2)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (var j = i; j < i + 2 && j < summaries.length; j++) ...[
                    if (j > i) const SizedBox(width: 8),
                    Expanded(child: _FileSummary(spec: summaries[j])),
                  ],
                ]))),
      Row(children: [
        const Expanded(child: AsoudSectionTitle(title: 'آخرین فعالیت‌ها')),
        TextButton(
            onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => _FileDetailShell(
                            title: 'آخرین فعالیت‌ها',
                            header: value.header,
                            personnel: personnel,
                            children: [
                              for (final activity in value.activity)
                                _activityRow(value, activity)
                            ]))),
            child: const Text('مشاهده همه')),
      ]),
      if (value.activity.isEmpty) const Text('هنوز فعالیتی ثبت نشده است.'),
      for (final activity in value.activity.take(5))
        _activityRow(value, activity),
    ]);
  }

  /// Tapping an activity opens the personnel record it came from, when that
  /// record is part of the legacy payload the page still reads.
  Widget _activityRow(PersonnelFile file, ActivityItem activity) {
    final rows = (detail?['records'] as List? ?? []).cast<Map>();
    final record = rows
        .where((row) =>
            row['title'] == activity.title &&
            row['record_date'] == activity.date)
        .firstOrNull;
    return InkWell(
        onTap: record == null
            ? null
            : () => open(_RecordDetailPage(
                personId: file.profileId,
                recordId: '${record['name']}',
                canEdit: canEdit,
                repository: personnel)),
        child: _FileActivity(activity: activity));
  }

  Widget information(PersonnelFile value) => Column(children: [
        for (final section in _fileSections)
          _PersonnelInfoSection(
              title: section.$1,
              subtitle: section.$2,
              icon: section.$3,
              color: AsoudColors.primary,
              onTap: () => open(_FileSectionPage(
                  section: section.$1,
                  file: value,
                  canEdit: canEdit,
                  mine: widget.mine,
                  repository: repository,
                  personnel: personnel))),
      ]);
  Widget records(PersonnelFile value) {
    final rows = (detail?['records'] as List? ?? []).cast<Map>();
    Widget list(String kind, List<Map> records) => _RecordsPage(
        personId: value.profileId,
        kind: kind,
        canEdit: canEdit,
        repository: personnel,
        records: records);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AsoudSectionTitle(title: 'تاریخچه همکاری'),
      _FileHistory(events: value.history),
      const SizedBox(height: 8),
      Row(children: [
        const Expanded(child: AsoudSectionTitle(title: 'سوابق و فعالیت‌ها')),
        TextButton(
            onPressed: () => open(list('all', rows)),
            child: const Text('مشاهده سوابق')),
      ]),
      if (rows.isEmpty) const Text('سابقه‌ای ثبت نشده است.'),
      for (final kind in personnelRecordKinds)
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_recordIcon(kind), color: _recordColor(kind)),
            title: Text(personnelRecordKindLabel(kind)),
            trailing: Text(toPersianDigits(
                rows.where((row) => row['kind'] == kind).length)),
            onTap: () => open(
                list(kind, rows.where((row) => row['kind'] == kind).toList()))),
    ]);
  }

  Widget documents(PersonnelFile value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final key in ['', ...personnelDocumentCategories])
                Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                        label: Text(
                            key.isEmpty ? 'همه' : documentCategoryLabel(key)),
                        selected: category == key,
                        selectedColor:
                            AsoudColors.primary.withValues(alpha: .15),
                        onSelected: (_) => setState(() => category = key))),
            ])),
        const SizedBox(height: 12),
        if (!value.documents
            .any((doc) => category.isEmpty || doc.category == category))
          const Text('مدرکی ثبت نشده است.'),
        for (final doc in value.documents
            .where((doc) => category.isEmpty || doc.category == category))
          _FileDocumentRow(
              document: doc,
              onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _FileDocumentPage(
                          file: value, document: doc, personnel: personnel)))),
        if (canEdit)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                  onPressed: () => open(_RecordForm(
                      personId: value.profileId,
                      kind: 'document',
                      repository: personnel)),
                  icon: const Icon(Icons.add),
                  label: const Text('افزودن مدرک'))),
      ]);
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
            title: widget.mine ? 'اطلاعات من' : 'پرونده پرسنلی',
            action: canEdit
                ? buildPersonnelAccountMenu(
                    context: context,
                    profile: detail?['profile'] is Map
                        ? Map<String, dynamic>.from(detail!['profile'] as Map)
                        : {
                            'id': file!.profileId,
                            'display_name': file!.header.name,
                            'company': file!.header.company,
                          },
                    repository: personnel)
                : null),
        bottomNavigationBar: !loading && error == null && canEdit
            ? SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                        height: 48,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: FilledButton(
                                      onPressed: edit,
                                      child: const Text('ویرایش پرونده',
                                          maxLines: 1))),
                              const SizedBox(width: 8),
                              Expanded(
                                  flex: 2,
                                  child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8)),
                                      onPressed: more,
                                      child: const Text('عملیات بیشتر',
                                          maxLines: 1))),
                            ]))))
            : null,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(error!),
                              TextButton(
                                  onPressed: reload,
                                  child: const Text('تلاش دوباره'))
                            ])))
                : Column(children: [
                    if (_importing) const LinearProgressIndicator(),
                    if (_operationMessage != null) Text(_operationMessage!),
                    if (detail?['offline'] == true ||
                        detail?['pending_sync'] == true ||
                        detail?['sync_failed'] == true)
                      _SyncNotice(
                          offline: detail?['offline'] == true,
                          pending: detail?['pending_sync'] == true,
                          failed: detail?['sync_failed'] == true),
                    if (canEdit && detail?['sync_failed'] == true)
                      TextButton(
                          onPressed: _importing ? null : _retrySync,
                          child: const Text('تلاش مجدد برای همگام‌سازی')),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _FileHeader(
                            header: file!.header, personnel: personnel)),
                    if (legacy)
                      Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: AsoudColors.warning.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text(
                              'اطلاعات ذخیره‌شده روی گوشی؛ برای نمایش کامل پرونده به سرور متصل شوید.',
                              style: TextStyle(
                                  fontSize: 11, color: AsoudColors.warning))),
                    TabBar(
                        controller: tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: const [
                          Tab(text: 'نمای کلی'),
                          Tab(text: 'اطلاعات پرسنلی'),
                          Tab(text: 'سوابق'),
                          Tab(text: 'مدارک')
                        ]),
                    Expanded(
                        child: RefreshIndicator(
                            onRefresh: reload,
                            child: SingleChildScrollView(
                                key: ValueKey(tabs.index),
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                child: switch (tabs.index) {
                                  0 => overview(file!),
                                  1 => information(file!),
                                  2 => records(file!),
                                  _ => documents(file!),
                                }))),
                  ]),
      ));
}

class _FileChip extends StatelessWidget {
  const _FileChip(this.label, {this.color = AsoudColors.muted});
  final String label;
  final Color color;
  // Vertical padding stays below the 18px tile icon so a chip never makes its
  // tile taller than its neighbour in the same row.
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12)),
      child: _fileValueText(label,
          maxLines: 1,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)));
}

class _FileHeader extends StatelessWidget {
  const _FileHeader({required this.header, required this.personnel});
  final PersonnelHeader header;
  final PersonnelRepository personnel;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (header.photoRecord != null)
            ClipOval(
                child: _PersonnelPhoto(
                    recordId: header.photoRecord,
                    repository: personnel,
                    size: 56))
          else
            CircleAvatar(radius: 28, child: Text(_initials(header.name))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_fileValue(header.name),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                Text(_fileValue(header.designation),
                    style: const TextStyle(fontSize: 11)),
                Text(_fileValue(header.departmentName),
                    style: const TextStyle(
                        color: AsoudColors.muted, fontSize: 10)),
              ])),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _FileChip(header.isActive ? 'فعال' : 'غیرفعال',
              color: header.isActive ? AsoudColors.success : AsoudColors.muted),
          const Text('کد پرسنلی'),
          _FileChip(
              header.employeeCode == null ||
                      header.employeeCode!.isEmpty ||
                      header.employeeCode!.startsWith('LOCAL-')
                  ? 'در انتظار ثبت'
                  : header.employeeCode!,
              color: AsoudColors.primary),
        ]),
      ]));
}

/// One overview tile, described before it is built so the row order can stay
/// fixed without any index arithmetic.
class _FileSummarySpec {
  const _FileSummarySpec(
      {required this.icon,
      required this.label,
      required this.value,
      this.hint,
      this.onTap,
      this.chip});
  final IconData icon;
  final String label, value;
  final String? hint;
  final VoidCallback? onTap;
  final Widget? chip;
}

class _FileSummary extends StatelessWidget {
  const _FileSummary({required this.spec});
  final _FileSummarySpec spec;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: spec.onTap,
      child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AsoudColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(spec.icon, size: 18, color: AsoudColors.primary),
              if (spec.chip != null) ...[const Spacer(), spec.chip!],
            ]),
            const SizedBox(height: 5),
            Text(spec.label,
                style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
            const SizedBox(height: 4),
            _fileValueText(spec.value,
                maxLines: 2,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            if (spec.hint != null)
              _fileValueText(spec.hint!,
                  maxLines: 1,
                  style:
                      const TextStyle(fontSize: 10, color: AsoudColors.muted)),
          ])));
}

class _FileActivity extends StatelessWidget {
  const _FileActivity({required this.activity});
  final ActivityItem activity;
  @override
  Widget build(BuildContext context) {
    final color = _fileEventColor(activity.kind);
    final caption = [
      if (activity.details.isNotEmpty) _fileDetails(activity.details),
      if (activity.by.isNotEmpty) 'توسط ${activity.by}',
    ].join(' · ');
    return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(_fileEventIcon(activity.kind, activity.title),
                      size: 18, color: color)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    if (caption.isNotEmpty)
                      Text(caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                  ])),
              const SizedBox(width: 6),
              // The moment stays in its own column so it is never truncated
              // away by a long caption on a narrow phone.
              _fileValueText(formatJalaliDateTimeIso(activity.date),
                  maxLines: 1,
                  style:
                      const TextStyle(fontSize: 10, color: AsoudColors.muted)),
            ])));
  }
}

class _FileHistory extends StatelessWidget {
  const _FileHistory({required this.events});
  final List<HistoryEvent> events;
  @override
  Widget build(BuildContext context) {
    final sorted = [...events]..sort((a, b) => b.date.compareTo(a.date));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (sorted.isEmpty) const Text('سابقه‌ای ثبت نشده است.'),
      for (final event in sorted)
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 36,
              child: Column(children: [
                Icon(_fileEventIcon(event.kind, event.title),
                    color: _fileEventColor(event.kind)),
                Expanded(child: Container(width: 2, color: AsoudColors.border)),
              ])),
          const SizedBox(width: 8),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text(_fileDetails(event.details)),
                        Text(_fileDate(event.date),
                            style: const TextStyle(color: AsoudColors.muted)),
                      ]))),
        ])),
    ]);
  }
}
