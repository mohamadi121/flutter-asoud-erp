part of 'personnel_page.dart';

String _fileValue(String? value) =>
    value == null || value.trim().isEmpty ? '—' : value;

/// Latin/ASCII-number values (O+, emails, codes) are laid out LTR; anything
/// with Persian/Arabic script, including Persian digits, stays RTL.
bool _isLtrValue(String value) =>
    !RegExp(r'\p{Script=Arabic}', unicode: true).hasMatch(value) &&
    RegExp(r'[A-Za-z0-9]').hasMatch(value);

Widget _fileValueText(String value, {TextStyle? style, TextAlign? textAlign}) {
  final ltr = _isLtrValue(value);
  return Directionality(
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      child: Text(_fileValue(value), style: style, textAlign: textAlign));
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
  String category = '';
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

  Future<void> reload() async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = widget.mine
          ? await repository.myFile()
          : await repository.file(widget.profileId!);
      if (mounted && current == request) setState(() => file = value);
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

  void edit() =>
      open(PersonnelDetailPage(id: file!.profileId, repository: personnel));
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
                'مدارک و سوابق'
              ].indexed)
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
        edit();
    }
  }

  Widget overview(PersonnelFile value) {
    final contract = _currentContract(value);
    final attention = value.documents
        .where((doc) => doc.status == 'expired' || doc.status == 'expiring')
        .length;
    final summaries = [
      (
        Icons.apartment_outlined,
        'واحد سازمانی',
        _fileValue(value.header.departmentName)
      ),
      (
        Icons.supervisor_account_outlined,
        'مدیر مستقیم',
        _fileValue(value.organization.reportsTo?.name)
      ),
      (
        Icons.work_outline,
        'نوع همکاری',
        _fileLabel(value.header.employmentType)
      ),
      (
        Icons.calendar_month_outlined,
        'تاریخ شروع همکاری',
        _fileDate(value.header.dateOfJoining)
      ),
      (
        Icons.description_outlined,
        'قرارداد فعلی',
        contract == null
            ? 'ثبت نشده'
            : '${_fileDate(contract.endDate)}\n${_daysRemaining(contract)}'
      ),
      (
        Icons.folder_outlined,
        'وضعیت مدارک',
        attention == 0
            ? 'همه معتبر'
            : '${toPersianDigits(attention)} مورد نیازمند اقدام'
      ),
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
                  for (var j = i; j < i + 2; j++) ...[
                    if (j > i) const SizedBox(width: 8),
                    Expanded(
                        child: _FileSummary(
                            icon: summaries[j].$1,
                            label: summaries[j].$2,
                            value: summaries[j].$3)),
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
                                _FileActivity(activity: activity)
                            ]))),
            child: const Text('مشاهده همه')),
      ]),
      if (value.activity.isEmpty) const Text('هنوز فعالیتی ثبت نشده است.'),
      for (final activity in value.activity.take(5))
        _FileActivity(activity: activity),
    ]);
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
        appBar:
            AsoudHeader(title: widget.mine ? 'اطلاعات من' : 'پرونده پرسنلی'),
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
                                      child: const Text('ویرایش اطلاعات',
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
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _FileHeader(
                            header: file!.header, personnel: personnel)),
                    TabBar(
                        controller: tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: const [
                          Tab(text: 'نمای کلی'),
                          Tab(text: 'اطلاعات پرسنلی'),
                          Tab(text: 'مدارک'),
                          Tab(text: 'سوابق')
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
                                  2 => documents(file!),
                                  _ => _FileHistory(events: file!.history),
                                }))),
                  ]),
      ));
}

class _FileChip extends StatelessWidget {
  const _FileChip(this.label, {this.color = AsoudColors.muted});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12)),
      child: _fileValueText(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)));
}

class _FileHeader extends StatelessWidget {
  const _FileHeader({required this.header, required this.personnel});
  final PersonnelHeader header;
  final PersonnelRepository personnel;
  @override
  Widget build(BuildContext context) => Container(
      constraints: const BoxConstraints(minHeight: 150),
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
          _FileChip(header.employeeCode ?? 'در انتظار ثبت',
              color: AsoudColors.primary),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _FileChip(header.departmentName),
          _FileChip(_fileLabel(header.employmentType)),
          _FileChip(header.serviceLength?.label ?? '—'),
        ]),
      ]));
}

class _FileSummary extends StatelessWidget {
  const _FileSummary(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AsoudColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: AsoudColors.primary),
        const SizedBox(height: 5),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
        const SizedBox(height: 4),
        _fileValueText(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]));
}

class _FileActivity extends StatelessWidget {
  const _FileActivity({required this.activity});
  final ActivityItem activity;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: AsoudColors.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.history,
                    size: 18, color: AsoudColors.primary)),
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
                  Text(
                      '${_fileDetails(activity.details)} · '
                      '${_fileValue(formatJalaliDateTimeIso(activity.date))} · '
                      'توسط ${_fileValue(activity.by)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AsoudColors.muted)),
                ])),
          ])));
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
                Icon(
                    switch (event.kind) {
                      'joining' => Icons.person_add,
                      'internal' => Icons.swap_horiz,
                      'promotion' => Icons.trending_up,
                      'transfer' => Icons.compare_arrows,
                      'contract' => Icons.description,
                      'salary' => Icons.payments,
                      'relieving' => Icons.logout,
                      _ => Icons.history,
                    },
                    color: switch (event.kind) {
                      'joining' => AsoudColors.success,
                      'promotion' => AsoudColors.purple,
                      'salary' => AsoudColors.warning,
                      'relieving' => AsoudColors.danger,
                      'transfer' => AsoudColors.cyan,
                      _ => AsoudColors.primary,
                    }),
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
