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
  final value = '${profile[key] ?? ''}'.trim();
  return value.isEmpty ? fallback : value;
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
        return Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'پرسنل',
              action: state.canEdit
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
          bottomNavigationBar: _PersonnelNavigation(company: cubit.company),
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
                                        '${entry.value} (${state.rows.where((r) => entry.key == 'all' || (r['disabled'] == true) == (entry.key == 'inactive')).length})'),
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
      }));
}

class _PersonnelRow extends StatelessWidget {
  const _PersonnelRow(
      {required this.profile, required this.repository, required this.onTap});
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
                            Text(
                                _valueOf(profile, 'employee_code',
                                    _valueOf(profile, 'id')),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                    color: Color(0xFF7A8DBB), fontSize: 10)),
                          ])),
                      const SizedBox(width: 5),
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
      {super.key,
      required this.profile,
      required this.records,
      required this.repository,
      required this.canEdit,
      required this.onProfile,
      required this.onRecords,
      required this.onRecord});
  final Map<String, dynamic> profile;
  final List<Map> records;
  final PersonnelRepository repository;
  final bool canEdit;
  final void Function(String, Map<String, String>) onProfile;
  final ValueChanged<String> onRecords;
  final ValueChanged<Map> onRecord;
  @override
  State<_PersonnelOverview> createState() => _PersonnelOverviewState();
}

class _PersonnelOverviewState extends State<_PersonnelOverview> {
  int tab = 0;
  void selectTab(int value) => setState(() => tab = value);
  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final recent = [...widget.records]
      ..sort((a, b) => '${b['record_date']}'.compareTo('${a['record_date']}'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          height: 152,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFD9E8E9),
                    Color(0xFF728F9B),
                    Color(0xFF344F73)
                  ])),
          child: Stack(children: [
            Positioned(
                left: 18,
                bottom: -10,
                child: _PersonnelPhoto(
                    recordId: p['photo_record'] as String?,
                    repository: widget.repository,
                    size: 144)),
            Positioned(
                right: 16,
                top: 15,
                bottom: 15,
                width: 160,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7)),
                          child: _EmploymentStatus(
                              disabled: p['disabled'] == true)),
                      const Spacer(),
                      Text(_valueOf(p, 'display_name'),
                          maxLines: 2,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(_valueOf(p, 'job_title'),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                      Text(_valueOf(p, 'department'),
                          style: const TextStyle(
                              color: Color(0xFFDEE8FF), fontSize: 10)),
                    ])),
          ])),
      Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line)),
          child: Row(children: [
            _ProfileMetric(
                icon: Icons.verified_outlined,
                title: _valueOf(p, 'employment_type'),
                subtitle: 'نوع همکاری'),
            _ProfileMetric(
                icon: Icons.apartment_rounded,
                title: _valueOf(p, 'department'),
                subtitle: 'واحد سازمانی'),
            _ProfileMetric(
                icon: Icons.badge_outlined,
                title: _valueOf(p, 'employee_code', _valueOf(p, 'id')),
                subtitle: 'کد پرسنلی'),
          ])),
      Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: const Color(0xFFEDF4FF),
              borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            for (final (i, label)
                in ['نمای کلی', 'اطلاعات', 'سوابق', 'مدارک'].indexed)
              Expanded(
                  child: InkWell(
                      onTap: () => setState(() => tab = i),
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
        const Text('خلاصه اطلاعات',
            style: TextStyle(
                color: _ink, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _SummaryTile(
                  title: 'واحد سازمانی',
                  value: _valueOf(p, 'department'),
                  icon: Icons.apartment_outlined,
                  color: _blue,
                  onTap: () =>
                      widget.onProfile('اطلاعات سازمانی', _organization))),
          const SizedBox(width: 10),
          Expanded(
              child: _SummaryTile(
                  title: 'سمت شغلی',
                  value: _valueOf(p, 'job_title'),
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFF00BCCD),
                  onTap: () =>
                      widget.onProfile('اطلاعات سازمانی', _organization))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _SummaryTile(
                  title: 'تاریخ استخدام',
                  value: _valueOf(p, 'date_of_joining'),
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFFFF9B2D),
                  onTap: () =>
                      widget.onProfile('اطلاعات سازمانی', _organization))),
          const SizedBox(width: 10),
          Expanded(
              child: _SummaryTile(
                  title: 'اطلاعات فردی',
                  value: _valueOf(p, 'display_name'),
                  icon: Icons.person_outline_rounded,
                  color: const Color(0xFF8A52FA),
                  onTap: () => widget.onProfile('اطلاعات فردی', _personal))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(
              child: Text('آخرین فعالیت‌ها',
                  style: TextStyle(
                      color: _ink, fontSize: 14, fontWeight: FontWeight.w900))),
          TextButton(
              onPressed: () => widget.onRecords('all'),
              child: const Text('مشاهده همه', style: TextStyle(fontSize: 10)))
        ]),
        if (recent.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('هنوز فعالیتی ثبت نشده است.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8193BA)))),
        for (final record in recent.take(4))
          _ActivityRow(record: record, onTap: () => widget.onRecord(record)),
      ],
      if (tab == 1) ...[
        _SummaryTile(
            title: 'اطلاعات فردی',
            value: 'مشخصات و راه‌های ارتباطی',
            icon: Icons.person_outline,
            color: _blue,
            onTap: () => widget.onProfile('اطلاعات فردی', _personal)),
        const SizedBox(height: 10),
        _SummaryTile(
            title: 'اطلاعات سازمانی',
            value: 'سمت، واحد و نوع همکاری',
            icon: Icons.apartment,
            color: const Color(0xFF8A52FA),
            onTap: () => widget.onProfile('اطلاعات سازمانی', _organization)),
      ],
      if (tab == 2 || tab == 3)
        for (final kind in (tab == 2
            ? ['attendance', 'evaluation', 'history']
            : ['document', 'photo']))
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SummaryTile(
                  title: _sections[kind]!,
                  value:
                      '${widget.records.where((r) => r['kind'] == kind).length} مورد ثبت‌شده',
                  icon: kind == 'photo'
                      ? Icons.photo_outlined
                      : Icons.folder_outlined,
                  color: _blue,
                  onTap: () => widget.onRecords(kind))),
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
      required this.onTap});
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
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
                      Text(value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(title,
                          style: const TextStyle(
                              color: Color(0xFF8192B9), fontSize: 9)),
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
            Icon(
                record['kind'] == 'evaluation'
                    ? Icons.star_border_rounded
                    : Icons.event_available_outlined,
                size: 21,
                color: record['kind'] == 'evaluation'
                    ? const Color(0xFFFFA42A)
                    : const Color(0xFF0CBD91)),
            const SizedBox(width: 9),
            Expanded(
                child: Text('${record['title']}',
                    style: const TextStyle(fontSize: 11, color: _ink))),
            Text('${record['record_date'] ?? ''}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF8392B8))),
          ])));
}
