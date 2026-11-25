part of 'personnel_page.dart';

const _ink = Color(0xFF24266B);
const _blue = Color(0xFF087CFF);
const _canvas = Color(0xFFF8FBFF);
const _line = Color(0xFFE9EEFA);

AppBar _personnelHeader(BuildContext context, String title, {Widget? action}) =>
    AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _ink,
      centerTitle: true,
      toolbarHeight: 54,
      automaticallyImplyLeading: false,
      leading: action,
      title: Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
            tooltip: 'بازگشت',
            onPressed: () => Navigator.maybePop(context),
            icon: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.chevron_left_rounded)))
      ],
    );

String _valueOf(Map profile, String key, [String fallback = '—']) {
  if (key == 'employee_code') {
    return capEmployeeCode('${profile['employee_code'] ?? ''}');
  }
  final value = '${profile[key] ?? ''}'.trim();
  if (value.isEmpty ||
      isLocalPersonnelId(value) ||
      value.contains('LOCAL-') ||
      value.contains('personnel-import-')) {
    return fallback;
  }
  if (key == 'birth_date' ||
      key == 'date_of_joining' ||
      key == 'date' ||
      key == 'record_date' ||
      key == 'final_confirmation_date' ||
      key == 'contract_end_date' ||
      key.endsWith('_date')) {
    return formatJalaliIso(value);
  }
  if (key == 'employment_type') {
    return const {
          'Full-time': 'تمام وقت',
          'Part-time': 'پاره وقت',
          'Contract': 'قراردادی',
          'Intern': 'کارآموز',
        }[value] ??
        value;
  }
  if (key == 'marital_status') {
    return const {'Married': 'متأهل', 'Single': 'مجرد'}[value] ?? value;
  }
  return value;
}

class _PersonnelList extends StatelessWidget {
  const _PersonnelList();
  Future<void> _department(BuildContext context, PersonnelState state) async {
    final cubit = context.read<PersonnelCubit>();
    final values = state.rows
        .map((r) => _valueOf(r, 'department', ''))
        .where((s) => s.isNotEmpty)
        .toSet();
    final value = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
                child: ListView(shrinkWrap: true, children: [
              ListTile(
                  title: const Text('همه واحدها'),
                  onTap: () => Navigator.pop(ctx, '')),
              for (final d in values)
                ListTile(title: Text(d), onTap: () => Navigator.pop(ctx, d)),
            ]))));
    if (value != null && context.mounted) cubit.filter(department: value);
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<PersonnelCubit, PersonnelState>(
          builder: (context, state) {
        final cubit = context.read<PersonnelCubit>();
        return FutureBuilder<Capabilities>(
            future: capabilitiesOf(context),
            builder: (context, capsSnap) {
              final caps = capsSnap.data ?? Capabilities.fromRoles(const []);
              // Keep the create entry point available during a failed list
              // refresh. The repository/server still authorizes persistence;
              // offline saves remain drafts in the existing local outbox.
              final canWritePersonnel = caps.canWritePersonnel;
              return Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'پرسنل',
              action: canWritePersonnel
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: IconButton.filled(
                          style: IconButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          tooltip: 'افزودن پرسنل',
                          icon: const Icon(Icons.add, size: 21),
                          onPressed: () async {
                            final saved = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PartyFormPage(
                                        initialRole: PartyRole.employee,
                                        company: cubit.company,
                                        pageTitle: 'ایجاد پرسنل')));
                            if (saved == true && context.mounted) {
                              await cubit.load();
                            }
                          }))
                  : null),
          body: RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    Row(children: [
                      IconButton(
                          tooltip: 'فیلتر واحد',
                          onPressed: () => _department(context, state),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _ink),
                          icon:
                              const Icon(Icons.filter_alt_outlined, size: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              onChanged: (v) => cubit.filter(query: v),
                              style: const TextStyle(fontSize: 12, color: _ink),
                              decoration: InputDecoration(
                                  hintText:
                                      'جستجو در نام، کد پرسنلی، سمت و واحد...',
                                  hintStyle: const TextStyle(
                                      fontSize: 10, color: Color(0xFF9CA9CB)),
                                  suffixIcon: const Icon(Icons.search,
                                      size: 20, color: Color(0xFF8C9BCC)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          const BorderSide(color: _line)),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))))),
                    ]),
                    const SizedBox(height: 9),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final entry in {
                            'all': 'همه',
                            'active': 'فعال',
                            'inactive': 'غیرفعال'
                          }.entries)
                            Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                    label: Text(
                                        '${entry.value} (${toPersianDigits(state.rows.where((r) => PersonnelState.matchesStatus(r, entry.key)).length)})'),
                                    selected: state.status == entry.key,
                                    showCheckmark: false,
                                    selectedColor: entry.key == 'active'
                                        ? const Color(0xFFDBFFF1)
                                        : _blue,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: _line),
                                    labelStyle: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: state.status == entry.key
                                            ? (entry.key == 'active'
                                                ? const Color(0xFF03B67C)
                                                : Colors.white)
                                            : const Color(0xFF8392BB)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    onSelected: (_) =>
                                        cubit.filter(status: entry.key))),
                          ActionChip(
                              label: Text(
                                  state.department.isEmpty
                                      ? 'واحد سازمانی'
                                      : state.department,
                                  style: const TextStyle(
                                      fontSize: 10, color: _ink)),
                              onPressed: () => _department(context, state)),
                        ])),
                    const SizedBox(height: 8),
                    if (state.offline || state.pendingSync || state.syncFailed)
                      _SyncNotice(
                          offline: state.offline,
                          pending: state.pendingSync,
                          failed: state.syncFailed),
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
                      _PersonnelRow(
                          profile: person,
                          repository: cubit.repository,
                          onTap: () async {
                            if (person['needs_employee_details'] == true &&
                                canWritePersonnel) {
                              try {
                                final profiles = await context.read<PartyRepository>().list(
                                  company: cubit.company,
                                  role: PartyRole.employee,
                                  search: '${person['display_name'] ?? ''}',
                                );
                                if (!context.mounted) return;
                                final profile = profiles.where((p) => p.id == person['id']).firstOrNull;
                                if (profile == null) {
                                  throw const FormatException('پرونده برای تکمیل در دسترس نیست.');
                                }
                                final saved = await Navigator.push<bool>(context,
                                  MaterialPageRoute(builder: (_) => PartyFormPage(
                                    initialRole: PartyRole.employee,
                                    company: cubit.company,
                                    profile: profile,
                                    pageTitle: 'تکمیل پرونده پرسنلی')));
                                if (saved == true && context.mounted) await cubit.load();
                              } catch (failure) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(failure is FormatException
                                      ? failure.message : failureMessage(failure))));
                                }
                              }
                              return;
                            }
                            await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => PersonnelDetailPage(
                                        id: '${person['id']}',
                                        repository: cubit.repository)));
                            if (context.mounted) await cubit.load();
                          }),
                  ])),
        );
            });
      }));
}

class _PersonnelRow extends StatelessWidget {
  const _PersonnelRow(
      {required this.profile,
      required this.repository,
      required this.onTap});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(13)),
                child: Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PersonnelPhoto(
                          recordId: profile['photo_record'] as String?,
                          repository: repository,
                          size: 66),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              textDirection: TextDirection.ltr,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_valueOf(profile, 'display_name'),
                                maxLines: 2,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(_valueOf(profile, 'job_title'),
                                style:
                                    const TextStyle(color: _ink, fontSize: 10)),
                            Text(_valueOf(profile, 'department'),
                                style: const TextStyle(
                                    color: Color(0xFF7A8DBB), fontSize: 10)),
                            capValueText(
                                capEmployeeCode(profile['employee_code']),
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Color(0xFF7A8DBB), fontSize: 10)),
                          ])),
                      const SizedBox(width: 5),
                      if (profile['needs_employee_details'] == true)
                        const Text('نیازمند تکمیل',
                            style: TextStyle(color: AsoudColors.warning, fontSize: 10))
                      else
                        _EmploymentStatus(disabled: profile['disabled'] == true),
                    ])),
          )));
}

class _EmploymentStatus extends StatelessWidget {
  const _EmploymentStatus({required this.disabled});
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    final color = disabled ? const Color(0xFFEE5370) : const Color(0xFF04B985);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 5),
      Text(disabled ? 'غیرفعال' : 'فعال',
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _PersonnelNavigation extends StatelessWidget {
  const _PersonnelNavigation({required this.company});
  final String company;
  @override
  Widget build(BuildContext context) => NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFEAF3FF),
          selectedIndex: 1,
          labelTextStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 10, color: _ink)),
          onDestinationSelected: (index) {
            if (index == 1) return;
            final page = switch (index) {
              0 => HrHomePage(company: company),
              2 => WorkReportsPage(company: company),
              _ => HrCommunicationsPage(company: company),
            };
            Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => page));
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined, size: 22, color: _ink),
                label: 'خانه'),
            NavigationDestination(
                icon:
                    Icon(Icons.people_outline_rounded, size: 22, color: _blue),
                label: 'پرسنل'),
            NavigationDestination(
                icon: Icon(Icons.assignment_outlined, size: 22, color: _ink),
                label: 'گزارش‌ها'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded,
                    size: 22, color: _ink),
                label: 'پیام‌ها'),
          ]);
}

class _PersonnelOverview extends StatefulWidget {
  const _PersonnelOverview(
      {required this.tab,
      required this.onTab,
      this.imagePicker,
      required this.profile,
      required this.records,
      required this.repository,
      required this.canEdit,
      required this.onProfile,
      required this.onCategory,
      required this.onPhotoSaved,
      required this.canEditPhoto,
      required this.onRecords,
      required this.onRecord,
      this.file,
      this.fileRepository});
  final Map<String, dynamic> profile;
  final int tab;
  final ValueChanged<int> onTab;
  final ImagePicker? imagePicker;
  final List<Map> records;
  final PersonnelRepository repository;
  final PersonnelFile? file;
  final PersonnelFileRepository? fileRepository;
  final bool canEdit;
  final bool canEditPhoto;
  final VoidCallback onPhotoSaved;
  final ValueChanged<String> onCategory;
  final void Function(String, Map<String, String>) onProfile;
  final ValueChanged<String> onRecords;
  final ValueChanged<Map> onRecord;
  @override
  State<_PersonnelOverview> createState() => _PersonnelOverviewState();
}

class _PersonnelOverviewState extends State<_PersonnelOverview> {
  int get tab => widget.tab;
  bool showTenure = false;
  void selectTab(int value) => widget.onTab(value);

  Widget _header(Map<String, dynamic> profile) {
    final header = widget.file?.header;
    final photo = header?.photoRecord ?? profile['photo_record'] as String?;
    String field(String? value, String key) =>
        value == null || value.trim().isEmpty ? _valueOf(profile, key) : capText(value);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FD),
        border: Border.all(color: const Color(0xFFBDD9FC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBDD9FC)),
          ),
          child: _PersonnelPhoto(
            key: const ValueKey('personnel-file-portrait'),
            recordId: photo,
            repository: widget.repository,
            size: 130,
            portrait: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD6F3E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _EmploymentStatus(disabled: profile['disabled'] == true ||
                (header != null && header.status.isNotEmpty && !header.isActive)),
          ),
          const SizedBox(height: 5),
          Text(field(header?.name, 'display_name'),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
          Text(field(header?.designation, 'job_title'),
              style: const TextStyle(color: _ink, fontSize: 12)),
          Text(field(header?.departmentName, 'department'),
              style: const TextStyle(color: Color(0xFF536B8D), fontSize: 11)),
          capValueText(capEmployeeCode(isLocalPersonnelId('${profile['id'] ?? ''}')
              ? null
              : (header?.employeeCode ?? profile['employee_code']?.toString())),
              maxLines: 1,
              style: const TextStyle(color: Color(0xFF536B8D), fontSize: 10)),
          if (widget.canEditPhoto)
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () async {
                final saved = await _pickPersonnelPhoto(
                  context, widget.repository, '${profile['id']}',
                  widget.imagePicker,
                );
                if (saved && mounted) widget.onPhotoSaved();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                side: const BorderSide(color: Color(0xFFBFD1E7)),
              ),
              child: Text(photo == null ? 'افزودن عکس' : 'تعویض عکس',
                  textAlign: TextAlign.center),
            )),
        ])),
      ]),
    );
  }

  Widget _summary() {
    final file = widget.file;
    final valid = (file?.contracts ?? const <ContractSummary>[])
        .where((row) => row.state == 'active' || row.state == 'expired')
        .toList()..sort((a, b) => b.startDate.compareTo(a.startDate));
    final contract = valid.firstOrNull;
    final leave = file?.leave;
    final attendance = file?.attendance;
    final hasAttendance = attendance != null &&
        (attendance.present + attendance.absent + attendance.onLeave +
            attendance.halfDay + attendance.lateEntries + attendance.earlyExits > 0);
    final documents = file?.documents;
    final followUp = documents?.where((row) =>
        ['pending', 'expired', 'expiring'].contains(row.status)).length;
    final leaveValue = leave == null || leave.isEmpty ? '—' :
        '${toPersianDigits(leave.fold<double>(0, (total, balance) => total + balance.remainingLeaves).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''))} روز';
    final items = <(String, String, IconData, Color, VoidCallback?)>[
      ('سابقه همکاری', file == null ? '—' : serviceLengthLabel(file),
        Icons.calendar_month_outlined, const Color(0xFF176CC4),
        () => setState(() => showTenure = !showTenure)),
      ('پایان قرارداد', contract?.state == 'expired'
            ? '${capDate(contract!.endDate)} · منقضی'
            : capDate(contract?.endDate ?? ''),
        Icons.description_outlined, const Color(0xFF7752BC),
        () => widget.onCategory('contracts')),
      ('مانده مرخصی', leaveValue, Icons.event_available_outlined,
        const Color(0xFF157950), null),
      ('غیبت و تأخیر', !hasAttendance ? '—' :
        '${toPersianDigits(attendance.absent)} غیبت · ${toPersianDigits(attendance.lateEntries)} تأخیر',
        Icons.schedule, const Color(0xFFA45910), () => widget.onRecords('attendance')),
      ('درخواست‌های باز', '—', Icons.assignment_outlined, const Color(0xFF197C8E), null),
      ('مدارک نیازمند پیگیری', followUp == null ? '—' : toPersianDigits(followUp),
        Icons.folder_open_outlined, const Color(0xFFAA4168), () => selectTab(3)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      capSectionTitle('وضعیت در یک نگاه'),
      for (var i = 0; i < items.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = i; j <= i + 1; j++) ...[
              if (j > i) const SizedBox(width: 8),
              Expanded(child: _PersonnelOverviewMetric(
                title: items[j].$1, value: items[j].$2, icon: items[j].$3,
                color: items[j].$4, onTap: items[j].$5,
                selected: j == 0 && showTenure,
              )),
            ],
          ])),
        ),
      if (showTenure)
        Card(
          color: Colors.white,
          child: ListTile(
            title: const Text('سابقه همکاری'),
            subtitle: const Text('سابقه از تاریخ شروع همکاری محاسبه می‌شود.'),
            trailing: IconButton(
              tooltip: 'بستن توضیح سابقه',
              onPressed: () => setState(() => showTenure = false),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(p),
      const SizedBox(height: 10),
      Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: const Color(0xFFEDF4FF),
              borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            for (final (i, label)
                in ['نمای کلی', 'اطلاعات پرسنلی', 'سوابق', 'مدارک'].indexed)
              Expanded(
                  child: InkWell(
                      onTap: () => selectTab(i),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: tab == i ? _blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: tab == i
                                      ? Colors.white
                                      : const Color(0xFF7E90BA))))))
          ])),
      const SizedBox(height: 10),
      if (tab == 0) ...[
        _summary(),
        const SizedBox(height: 10),
        PersonnelActivityFeedSlot(
            records: widget.records,
            onRecord: widget.onRecord),
      ],
      if (tab == 1) ...[
        for (final item in [
          ('اطلاعات فردی', Icons.badge_outlined, const Color(0xFF7855C2)),
          ('اطلاعات سازمانی', Icons.apartment_rounded, _blue),
          ('اطلاعات استخدامی', Icons.work_outline, const Color(0xFF087B5A)),
          ('قراردادها', Icons.edit_document, const Color(0xFFA65D17)),
          ('حقوق و مزایا', Icons.account_balance_wallet_outlined, const Color(0xFF217D93)),
          ('حضور و غیاب', Icons.event_available_outlined, const Color(0xFF7855C2)),
        ])
          _PersonnelInfoSection(
            title: item.$1,
            icon: item.$2,
            color: item.$3,
            onTap: () => switch (item.$1) {
              'اطلاعات فردی' => widget.onProfile(item.$1, _personal),
              'اطلاعات سازمانی' => widget.onProfile(item.$1, _organization),
              'اطلاعات استخدامی' => widget.onCategory('employment'),
              'قراردادها' => widget.onCategory('contracts'),
              'حقوق و مزایا' => widget.onCategory('benefits'),
              _ => widget.onRecords('attendance'),
            },
          ),
        PersonnelManagerAndTenureSlot(
          file: widget.file,
          repository: widget.repository,
          fileRepository: widget.fileRepository,
        ),
      ],
      if (tab == 2 || tab == 3)
        for (final kind in (tab == 2
            ? ['attendance', 'evaluation', 'history']
            : ['document', 'photo']))
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SummaryTile(
                  title: personnelRecordKindLabel(kind),
                  value:
                      formatCount(widget.records.where((r) => r['kind'] == kind).length, 'مورد ثبت‌شده'),
                  icon: kind == 'photo'
                      ? Icons.photo_outlined
                      : Icons.folder_outlined,
                  color: _blue,
                  onTap: () => widget.onRecords(kind))),
      if (tab == 3)
        PersonnelDocumentsSlot(file: widget.file, personnel: widget.repository),
      if (tab == 2 && widget.file != null)
        TextButton(
          onPressed: () => Navigator.push<void>(context, MaterialPageRoute(
            builder: (_) => _ActivityFeedPage(file: widget.file!),
          )),
          child: const Text('مشاهده همه فعالیت‌ها'),
        ),
      const SizedBox(height: 10),
      Row(children: [
        if (widget.canEdit)
          Expanded(
              child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () => widget.onProfile(
                      'ویرایش اطلاعات', {..._personal, ..._organization}),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('ویرایش اطلاعات',
                      style: TextStyle(fontSize: 11)))),
        const SizedBox(width: 10),
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () => widget.onRecords('all'),
                icon: const Icon(Icons.history, size: 17),
                label:
                    const Text('مشاهده سوابق', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))))),
      ]),
    ]);
  }
}

class _PersonnelOverviewMetric extends StatelessWidget {
  const _PersonnelOverviewMetric({
    required this.title, required this.value, required this.icon,
    required this.color, required this.onTap, required this.selected,
  });
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: Color.alphaBlend(color.withValues(alpha: .10), Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: selected ? BorderSide(color: color) : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 5),
          Expanded(child: Text(title, style: const TextStyle(color: _ink, fontSize: 11))),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    )),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Expanded(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(children: [
            Icon(icon, size: 20, color: _blue),
            const SizedBox(width: 5),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          color: _ink,
                          fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 8, color: Color(0xFF8493B9))),
                ])),
          ])));
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color,
      this.onTap});
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: color.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: .13))),
              child: Row(textDirection: TextDirection.ltr, children: [
                Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(icon, color: color, size: 21)),
                const SizedBox(width: 9),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Tooltip(
                        message: value,
                        child: Text(value,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 3),
                      Tooltip(
                        message: title,
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF8192B9), fontSize: 9)),
                      ),
                    ])),
              ]))));
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.record, required this.onTap});
  final Map record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line))),
          child: Row(children: [
            Icon(capEventIcon('${record['kind']}', '${record['title']}'),
                size: 17, color: capEventColor('${record['kind']}')),
            const SizedBox(width: 9),
            Expanded(
                child: Text('${record['title']}',
                    style: const TextStyle(fontSize: 11, color: _ink))),
            capValueText(capDate('${record['record_date'] ?? ''}'),
                style: const TextStyle(fontSize: 10, color: Color(0xFF8392B8))),
            const Icon(Icons.chevron_left_rounded, size: 15, color: AsoudColors.muted),
          ])));
}
