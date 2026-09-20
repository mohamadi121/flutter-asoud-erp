part of 'personnel_page.dart';

const _profileGroups = {
  'اطلاعات اصلی': [
    'display_name',
    'national_id',
    'birth_date',
    'employee_gender',
    'father_name'
  ],
  'حقوق و مزایا': [
    'base_salary',
    'housing_allowance',
    'transport_allowance',
    'other_allowances',
    'deductions',
    'net_salary'
  ],
  'راه‌های ارتباطی': ['mobile', 'phone', 'email'],
  'آدرس و موقعیت': ['province', 'city', 'address_line', 'postal_code'],
  'اطلاعات سازمانی': [
    'job_title',
    'department',
    'date_of_joining',
    'employment_type'
  ],
};
const _genderOptions = {'Male': 'مرد', 'Female': 'زن', 'Other': 'سایر'};
const _recordLabels = {
  'title': 'عنوان',
  'date': 'تاریخ',
  'start': 'ساعت ورود',
  'end': 'ساعت خروج',
  'score': 'امتیاز هدف از ۱۰۰',
  'appraisal_cycle': 'دوره ارزیابی',
  'notes': 'توضیحات'
};

String _recordTitle(String kind) =>
    kind == 'all' ? 'سوابق و فعالیت‌ها' : _sections[kind]!;
IconData _recordIcon(String kind) => switch (kind) {
      'attendance' => Icons.event_available_outlined,
      'evaluation' => Icons.star_border_rounded,
      'photo' => Icons.photo_outlined,
      'document' => Icons.description_outlined,
      _ => Icons.history_rounded,
    };
Color _recordColor(String kind) => switch (kind) {
      'attendance' => const Color(0xFF04B985),
      'evaluation' => const Color(0xFFFFA42A),
      'photo' => const Color(0xFF8A52FA),
      _ => _blue,
    };

class _HrSummary extends StatelessWidget {
  const _HrSummary(
      {required this.title,
      required this.subtitle,
      required this.icon,
      this.color = _blue});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .055),
          border: Border.all(color: color.withValues(alpha: .13)),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF8392B8), fontSize: 11)),
        ])),
      ]));
}

class _HrInfoCard extends StatelessWidget {
  const _HrInfoCard({required this.title, required this.values});
  final String title;
  final Map<String, String> values;
  IconData get icon => switch (title) {
        'اطلاعات اصلی' || 'اطلاعات فردی' => Icons.person_outline_rounded,
        'راه‌های ارتباطی' => Icons.call_outlined,
        'آدرس و موقعیت' => Icons.location_on_outlined,
        'اطلاعات سازمانی' || 'جایگاه سازمانی' => Icons.apartment_outlined,
        'اطلاعات تکمیلی' => Icons.info_outline_rounded,
        _ => Icons.description_outlined,
      };
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: _blue, size: 21),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: _ink, fontWeight: FontWeight.w900, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        for (final entry in values.entries.indexed)
          Column(children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text(entry.$2.key,
                              style: const TextStyle(
                                  color: Color(0xFF8392B8), fontSize: 11))),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 3,
                          child: SelectableText(entry.$2.value,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700))),
                    ])),
            if (entry.$1 < values.length - 1)
              const Divider(height: 1, color: _line),
          ]),
      ]));
}

class _ProfileDetailHero extends StatelessWidget {
  const _ProfileDetailHero({required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  Widget build(BuildContext context) => Container(
      height: 156,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF244D78), Color(0xFF6F94A9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFB9D8E8))),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _PersonnelPhoto(
                recordId: profile['photo_record'] as String?,
                repository: repository,
                size: 140)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child:
                      _EmploymentStatus(disabled: profile['disabled'] == true)),
              const SizedBox(height: 10),
              Text(_valueOf(profile, 'display_name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900)),
              Text(_valueOf(profile, 'job_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
              Text(_valueOf(profile, 'department'),
                  style:
                      const TextStyle(color: Color(0xFFDDEBFF), fontSize: 10)),
            ])),
      ]));
}

class _HrActionBar extends StatelessWidget {
  const _HrActionBar(
      {required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _line))),
          child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))))));
}

class _PersonnelInfoPage extends StatefulWidget {
  const _PersonnelInfoPage(
      {required this.profile,
      required this.revision,
      required this.canEdit,
      required this.repository});
  final Map<String, dynamic> profile;
  final String revision;
  final bool canEdit;
  final PersonnelRepository repository;
  @override
  State<_PersonnelInfoPage> createState() => _PersonnelInfoPageState();
}

class _PersonnelInfoPageState extends State<_PersonnelInfoPage> {
  late Map<String, dynamic> profile = widget.profile;
  late String revision = widget.revision;
  late bool canEdit = widget.canEdit;
  bool loading = false;

  Future<void> edit() async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => _ProfileEditor(
                title: 'اطلاعات فردی',
                labels: {..._personal, ..._organization},
                profile: profile,
                revision: revision,
                repository: widget.repository)));
    if (saved != true || !mounted) return;
    setState(() => loading = true);
    try {
      final data = await widget.repository.detail('${profile['id']}');
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(data['profile'] as Map);
        revision = '${data['revision']}';
        canEdit = data['can_edit'] == true;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openProfile(String title, Map<String, String> labels) {
    Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => _ProfileFields(
                title: title,
                labels: labels,
                profile: profile,
                canEdit: canEdit,
                revision: revision,
                repository: widget.repository)));
  }

  Future<void> openRecords(String kind) async {
    final data = await widget.repository.detail('${profile['id']}');
    if (!mounted) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => _RecordsPage(
                personId: '${profile['id']}',
                kind: kind,
                canEdit: data['can_edit'] == true,
                repository: widget.repository,
                records: (data['records'] as List)
                    .where((record) => record['kind'] == kind)
                    .cast<Map>()
                    .toList())));
  }

  void openCategory(String category) {
    Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => _PersonnelCategoryPage(
                category: category,
                profile: profile,
                repository: widget.repository,
                canEdit: canEdit)));
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: _canvas,
            appBar: _personnelHeader(context, 'اطلاعات پرسنلی',
                action: IconButton(
                    tooltip: 'سوابق پرسنلی',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.description_outlined, size: 20))),
            bottomNavigationBar:
                _PersonnelNavigation(company: '${p['company'] ?? ''}'),
            body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                children: [
                  _PersonnelInfoHero(profile: p, repository: widget.repository),
                  const SizedBox(height: 10),
                  _PersonnelInfoMetrics(profile: p),
                  const SizedBox(height: 12),
                  _PersonnelInfoSection(
                      title: 'اطلاعات فردی',
                      subtitle: 'نام و نام خانوادگی',
                      icon: Icons.person_outline_rounded,
                      color: const Color(0xFF8A52FA),
                      onTap: () => openProfile('اطلاعات فردی', _personal)),
                  _PersonnelInfoSection(
                      title: 'اطلاعات سازمانی',
                      subtitle: 'واحد، سمت و نوع همکاری',
                      icon: Icons.apartment_rounded,
                      color: _blue,
                      onTap: () =>
                          openProfile('اطلاعات سازمانی', _organization)),
                  _PersonnelInfoSection(
                      title: 'اطلاعات استخدامی',
                      subtitle: 'نوع همکاری، تاریخ شروع و وضعیت',
                      icon: Icons.work_outline_rounded,
                      color: const Color(0xFF04B985),
                      onTap: () => openCategory('employment')),
                  _PersonnelInfoSection(
                      title: 'قراردادها',
                      subtitle: 'قرارداد جاری و مستندات همکاری',
                      icon: Icons.description_outlined,
                      color: const Color(0xFFFF8B1F),
                      onTap: () => openCategory('contracts')),
                  _PersonnelInfoSection(
                      title: 'حقوق و مزایا',
                      subtitle: 'اطلاعات مالی در API فعلی ارائه نشده است',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFFF2485B),
                      onTap: () => openCategory('benefits')),
                  _PersonnelInfoSection(
                      title: 'حضور و غیاب',
                      subtitle: 'شیفت‌ها، تردد و ساعات کاری',
                      icon: Icons.access_time_rounded,
                      color: const Color(0xFF8A52FA),
                      onTap: () => Navigator.pop(context)),
                  Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE7F2FF),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFFD4E8FF))),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: _blue, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    'اطلاعات حقوق و مزایا فقط برای کاربران مجاز نمایش داده می‌شود.',
                                    style: const TextStyle(
                                        color: Color(0xFF6680A8),
                                        fontSize: 10,
                                        height: 1.7))),
                          ])),
                  const SizedBox(height: 10),
                  if (loading) const LinearProgressIndicator(),
                  if (canEdit)
                    FilledButton.icon(
                        onPressed: loading ? null : edit,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('ویرایش اطلاعات')),
                ])));
  }
}

class _PersonnelInfoHero extends StatelessWidget {
  const _PersonnelInfoHero({required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  Widget build(BuildContext context) => Container(
      height: 137,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFE5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD5E9FF))),
      child: Row(children: [
        _PersonnelPhoto(
            recordId: profile['photo_record'] as String?,
            repository: repository,
            size: 116),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              _EmploymentStatus(disabled: profile['disabled'] == true),
              const SizedBox(height: 15),
              Text(_valueOf(profile, 'display_name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _ink, fontSize: 20, fontWeight: FontWeight.w900)),
              Text(_valueOf(profile, 'job_title'),
                  style: const TextStyle(color: _ink, fontSize: 11)),
              Text(_valueOf(profile, 'department'),
                  style:
                      const TextStyle(color: Color(0xFF6680A8), fontSize: 10)),
            ]))
      ]));
}

class _PersonnelInfoMetrics extends StatelessWidget {
  const _PersonnelInfoMetrics({required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line)),
      child: Row(children: [
        _ProfileMetric(
            icon: Icons.verified_outlined,
            title: _valueOf(profile, 'employment_type'),
            subtitle: 'نوع همکاری'),
        _ProfileMetric(
            icon: Icons.apartment_rounded,
            title: _valueOf(profile, 'department'),
            subtitle: 'واحد سازمانی'),
        _ProfileMetric(
            icon: Icons.badge_outlined,
            title: _valueOf(profile, 'employee_code', _valueOf(profile, 'id')),
            subtitle: 'کد پرسنلی'),
      ]));
}

class _PersonnelInfoSection extends StatelessWidget {
  const _PersonnelInfoSection(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
          color: color.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: color.withValues(alpha: .12))),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: color, size: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF8294BA), fontSize: 9)),
                        ])),
                    const Icon(Icons.chevron_left_rounded,
                        color: Color(0xFF6680A8), size: 22),
                  ])))));
}

class _PersonnelCategoryPage extends StatefulWidget {
  const _PersonnelCategoryPage(
      {required this.category,
      required this.profile,
      required this.repository,
      required this.canEdit});
  final String category;
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  final bool canEdit;
  @override
  State<_PersonnelCategoryPage> createState() => _PersonnelCategoryPageState();
}

class _PersonnelCategoryPageState extends State<_PersonnelCategoryPage> {
  late Future<Map<String, dynamic>> future =
      widget.repository.detail('${widget.profile['id']}');

  String get title => switch (widget.category) {
        'employment' => 'اطلاعات استخدامی',
        'contracts' => 'قراردادها',
        _ => 'حقوق و مزایا',
      };

  Future<void> openRecords() async {
    final data = await future;
    if (!mounted) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => _RecordsPage(
                personId: '${widget.profile['id']}',
                kind: 'document',
                canEdit: data['can_edit'] == true,
                repository: widget.repository,
                records: (data['records'] as List)
                    .where((record) => record['kind'] == 'document')
                    .cast<Map>()
                    .toList())));
    if (mounted) {
      setState(() {
        future = widget.repository.detail('${widget.profile['id']}');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, title),
          bottomNavigationBar: _PersonnelNavigation(
              company: '${widget.profile['company'] ?? ''}'),
          body: FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: TextButton(
                          onPressed: () => setState(() {
                                future = widget.repository
                                    .detail('${widget.profile['id']}');
                              }),
                          child: const Text(
                              'دریافت اطلاعات ناموفق؛ تلاش دوباره')));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final profile =
                    Map<String, dynamic>.from(data['profile'] as Map);
                final records = (data['records'] as List)
                    .cast<Map>()
                    .where((record) => record['kind'] == 'document')
                    .toList();
                return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      _ProfileDetailHero(
                          profile: profile, repository: widget.repository),
                      const SizedBox(height: 10),
                      _ProfileMetricStrip(profile: profile),
                      const SizedBox(height: 12),
                      if (widget.category == 'employment')
                        _EmploymentCategory(profile: profile),
                      if (widget.category == 'contracts')
                        _ContractsCategory(
                            records: records,
                            canEdit: data['can_edit'] == true,
                            onRecords: openRecords),
                      if (widget.category == 'benefits')
                        _BenefitsCategory(
                            profile: profile,
                            canEdit: data['can_edit'] == true,
                            onEdit: () async {
                              await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => _ProfileEditor(
                                          title: 'حقوق و مزایا',
                                          labels: _benefits,
                                          profile: profile,
                                          revision: '${data['revision']}',
                                          repository: widget.repository)));
                              if (mounted) {
                                setState(() {
                                  future = widget.repository
                                      .detail('${widget.profile['id']}');
                                });
                              }
                            }),
                    ]);
              })));
}

class _EmploymentCategory extends StatelessWidget {
  const _EmploymentCategory({required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) => Column(children: [
        _CategoryCard(
            title: 'اطلاعات استخدامی',
            icon: Icons.work_outline_rounded,
            color: const Color(0xFF04B985),
            values: {
              'نوع همکاری': _valueOf(profile, 'employment_type'),
              'تاریخ شروع همکاری': _valueOf(profile, 'date_of_joining'),
              'سمت شغلی': _valueOf(profile, 'job_title'),
              'واحد سازمانی': _valueOf(profile, 'department'),
              'کد پرسنلی':
                  _valueOf(profile, 'employee_code', _valueOf(profile, 'id')),
            }),
        const SizedBox(height: 10),
        _CategoryCard(
            title: 'وضعیت همکاری',
            icon: Icons.verified_outlined,
            color: const Color(0xFF087CFF),
            values: {
              'وضعیت': profile['disabled'] == true ? 'غیرفعال' : 'فعال',
              'نوع استخدام': _valueOf(profile, 'employment_type'),
            }),
      ]);
}

class _ContractsCategory extends StatelessWidget {
  const _ContractsCategory(
      {required this.records, required this.canEdit, required this.onRecords});
  final List<Map> records;
  final bool canEdit;
  final VoidCallback onRecords;
  @override
  Widget build(BuildContext context) => Column(children: [
        _CategoryCard(
            title: 'مدارک مرتبط با قرارداد',
            icon: Icons.description_outlined,
            color: const Color(0xFF04B985),
            values: {
              'وضعیت قرارداد': 'از روی مدارک قابل تعیین نیست',
              'آخرین سند': records.isEmpty
                  ? 'هنوز قراردادی ثبت نشده است'
                  : '${records.first['title']}',
              if (records.isNotEmpty)
                'تاریخ ثبت': '${records.first['record_date']}',
            }),
        const SizedBox(height: 10),
        for (final record in records.take(3))
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CategoryRow(
                  title: '${record['title']}',
                  subtitle: '${record['record_date']}',
                  icon: Icons.description_outlined,
                  color: const Color(0xFFFF8B1F))),
        const SizedBox(height: 4),
        FilledButton.icon(
            onPressed: onRecords,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(
                canEdit ? 'مشاهده و مدیریت قراردادها' : 'مشاهده قراردادها')),
      ]);
}

class _BenefitsCategory extends StatelessWidget {
  const _BenefitsCategory(
      {required this.profile, required this.canEdit, required this.onEdit});
  final Map<String, dynamic> profile;
  final bool canEdit;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Column(children: [
        _CategoryCard(
            title: 'حقوق و مزایا',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFFF2485B),
            values: const {
              'وضعیت': 'ثبت موقت اطلاعات مالی',
              'سطح دسترسی': 'فقط مدیر منابع انسانی',
            }),
        const SizedBox(height: 10),
        _CategoryCard(
            title: 'جزئیات پرداخت',
            icon: Icons.payments_outlined,
            color: const Color(0xFFF2485B),
            values: {
              for (final entry in _benefits.entries)
                entry.value: _valueOf(profile, entry.key),
            }),
        if (canEdit) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('ثبت و ویرایش حقوق و مزایا')),
        ],
      ]);
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.values});
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 13, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 7),
        for (final entry in values.entries)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(
                    child: Text(entry.key,
                        style: const TextStyle(
                            color: Color(0xFF8392B8), fontSize: 10))),
                Expanded(
                    child: Text(entry.value,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w800))),
              ])),
      ]));
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line)),
      child: Row(children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: _ink, fontSize: 11, fontWeight: FontWeight.w800)),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF8392B8), fontSize: 10)),
        ])),
        const Icon(Icons.chevron_left_rounded, color: _blue),
      ]));
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
  late Map<String, dynamic> profile = widget.profile;
  late String revision = widget.revision;
  late bool canEdit = widget.canEdit;
  bool loading = false;
  String? error;
  Future<void> edit() async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => _ProfileEditor(
                title: widget.title,
                labels: widget.labels,
                profile: profile,
                revision: revision,
                repository: widget.repository)));
    if (saved != true || !mounted) return;
    setState(() {
      loading = true;
      error = null;
      canEdit = false;
    });
    try {
      final data = await widget.repository.detail('${profile['id']}');
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(data['profile'] as Map);
        revision = '${data['revision']}';
        canEdit = data['can_edit'] == true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'اطلاعات ذخیره شد؛ برای دریافت نسخه تازه، صفحه را دوباره باز کنید.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, widget.title),
          bottomNavigationBar:
              Column(mainAxisSize: MainAxisSize.min, children: [
            if (canEdit)
              _HrActionBar(
                  label: 'ویرایش اطلاعات',
                  icon: Icons.edit_outlined,
                  onPressed: loading ? null : edit),
            _PersonnelNavigation(company: '${profile['company'] ?? ''}'),
          ]),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _ProfileDetailHero(profile: profile, repository: widget.repository),
            const SizedBox(height: 10),
            _ProfileMetricStrip(profile: profile),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            for (final group in _profileGroups.entries)
              if (group.value.any(widget.labels.containsKey))
                _HrInfoCard(title: group.key, values: {
                  for (final key
                      in group.value.where(widget.labels.containsKey))
                    widget.labels[key]!: key == 'employee_gender'
                        ? (_genderOptions[profile[key]] ??
                            _valueOf(profile, key))
                        : _valueOf(profile, key),
                }),
          ])));
}

class _ProfileMetricStrip extends StatelessWidget {
  const _ProfileMetricStrip({required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line)),
      child: Row(children: [
        _ProfileMetric(
            icon: Icons.verified_outlined,
            title: _valueOf(profile, 'employment_type'),
            subtitle: 'نوع همکاری'),
        _ProfileMetric(
            icon: Icons.apartment_rounded,
            title: _valueOf(profile, 'department'),
            subtitle: 'واحد سازمانی'),
        _ProfileMetric(
            icon: Icons.badge_outlined,
            title: _valueOf(profile, 'employee_code', _valueOf(profile, 'id')),
            subtitle: 'کد پرسنلی'),
      ]));
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor(
      {required this.title,
      required this.labels,
      required this.profile,
      required this.revision,
      required this.repository});
  final String title, revision;
  final Map<String, String> labels;
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final formKey = GlobalKey<FormState>();
  late final fields = {
    for (final key in widget.labels.keys)
      key: TextEditingController(text: '${widget.profile[key] ?? ''}')
  };
  bool saving = false;
  Map<String, dynamic> linkOptions = {};
  bool loadingOptions = false;

  @override
  void initState() {
    super.initState();
    if (!widget.repository.localDemo &&
        ['department', 'job_title', 'employment_type']
            .any(widget.labels.containsKey)) {
      loadOptions();
    }
  }

  Future<void> loadOptions() async {
    setState(() => loadingOptions = true);
    try {
      final result =
          await widget.repository.profileOptions('${widget.profile['id']}');
      if (mounted) setState(() => linkOptions = result);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'دریافت فهرست اطلاعات سازمانی ممکن نشد؛ دوباره فرم را باز کنید.');
      }
    } finally {
      if (mounted) setState(() => loadingOptions = false);
    }
  }

  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!formKey.currentState!.validate()) {
      setState(() => error = 'فیلدهای مشخص‌شده در بخش‌های فرم را بررسی کنید.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.update(
          '${widget.profile['id']}',
          {for (final e in fields.entries) e.key: e.value.text.trim()},
          widget.revision);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'ذخیره انجام نشد؛ اتصال یا تغییر هم‌زمان اطلاعات را بررسی کنید. اطلاعات فرم حفظ شده است.';
        });
      }
    }
  }

  Widget field(String key) {
    final label = widget.labels[key]!;
    if (!widget.repository.localDemo &&
        ['department', 'job_title', 'employment_type'].contains(key)) {
      final current = fields[key]!.text;
      return AsoudFormDropdown(
          controller: fields[key]!,
          label: label,
          enabled: !saving && !loadingOptions,
          options: {
            for (final value in linkOptions[key] as List? ?? [])
              '$value': '$value',
            if (current.isNotEmpty) current: current,
          });
    }
    if (financialPersonnelFields.contains(key)) {
      return AsoudFormField(
          controller: fields[key]!,
          label: label,
          enabled: !saving,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) return null;
            final amount = num.tryParse(value);
            return amount == null ||
                    !amount.isFinite ||
                    amount < 0 ||
                    amount > 1e15
                ? 'مبلغ معتبر و غیرمنفی وارد کنید.'
                : null;
          });
    }
    if (key == 'employee_gender') {
      return AsoudFormDropdown(
          controller: fields[key]!,
          label: label,
          enabled: !saving,
          options: _genderOptions);
    }
    if (key == 'employment_type') {
      return AsoudFormDropdown(
          controller: fields[key]!,
          label: label,
          enabled: !saving,
          options: const {
            'تمام وقت': 'تمام وقت',
            'پاره وقت': 'پاره وقت',
            'قراردادی': 'قراردادی',
            'کارآموز': 'کارآموز'
          });
    }
    if (key == 'birth_date' || key == 'date_of_joining') {
      return AsoudFormDateField(
          controller: fields[key]!, label: label, enabled: !saving);
    }
    return AsoudFormField(
        controller: fields[key]!,
        label: label,
        enabled: !saving,
        lines: key == 'address_line' ? 3 : 1,
        keyboardType: ['mobile', 'phone'].contains(key)
            ? TextInputType.phone
            : key == 'email'
                ? TextInputType.emailAddress
                : null,
        validator: key == 'display_name'
            ? (v) => (v?.trim().isEmpty ?? true)
                ? 'نام و نام خانوادگی الزامی است.'
                : null
            : null);
  }

  @override
  Widget build(BuildContext context) => AsoudFormPage(
          title: widget.title.startsWith('ویرایش')
              ? widget.title
              : 'ویرایش ${widget.title}',
          subtitle: _valueOf(widget.profile, 'display_name'),
          formKey: formKey,
          saving: saving,
          error: error,
          onSave: save,
          children: [
            for (final group in _profileGroups.entries)
              if (group.value.any(widget.labels.containsKey))
                AsoudFormSection(
                    title: group.key,
                    children: group.value
                        .where(widget.labels.containsKey)
                        .map(field)
                        .toList()),
          ]);
}

class _RecordsPage extends StatefulWidget {
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
  State<_RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<_RecordsPage> {
  late List<Map> rows = [...widget.records];
  late bool canEdit = widget.canEdit;
  String query = '', filter = 'all';
  String? error;
  bool loading = false;
  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.detail(widget.personId);
      if (!mounted) return;
      setState(() {
        rows = (value['records'] as List).cast<Map>();
        canEdit = value['can_edit'] == true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'دریافت سوابق ممکن نشد؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    String? kind = widget.kind;
    if (kind == 'all') {
      kind = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                  child: ListView(shrinkWrap: true, children: [
                const ListTile(
                    title: Text('نوع سابقه جدید',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                for (final e in _sections.entries)
                  ListTile(
                      leading:
                          Icon(_recordIcon(e.key), color: _recordColor(e.key)),
                      title: Text(e.value),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => Navigator.pop(ctx, e.key)),
              ]))));
    }
    if (kind == null || !mounted) return;
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => _RecordForm(
                personId: widget.personId,
                kind: kind!,
                repository: widget.repository)));
    if (saved == true && mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final items = rows
        .where((r) =>
            (widget.kind == 'all' || r['kind'] == widget.kind) &&
            (filter == 'all' || r['kind'] == filter) &&
            '${r['title']} ${r['record_date']}'.contains(query.trim()))
        .toList()
      ..sort((a, b) => '${b['record_date']}'.compareTo('${a['record_date']}'));
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: _canvas,
            appBar: _personnelHeader(context, _recordTitle(widget.kind)),
            bottomNavigationBar: canEdit
                ? _HrActionBar(
                    label: 'ثبت مورد جدید',
                    icon: Icons.add,
                    onPressed: loading ? null : create)
                : null,
            body: RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HrSummary(
                          title: _recordTitle(widget.kind),
                          subtitle: '${items.length} مورد ثبت‌شده',
                          icon: _recordIcon(widget.kind),
                          color: _recordColor(widget.kind)),
                      TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(
                              hintText: 'جستجوی عنوان یا تاریخ',
                              prefixIcon: Icon(Icons.search, color: _blue))),
                      const SizedBox(height: 12),
                      if (widget.kind == 'all')
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              for (final e
                                  in {'all': 'همه', ..._sections}.entries)
                                Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: ChoiceChip(
                                        label: Text(e.value,
                                            style:
                                                const TextStyle(fontSize: 10)),
                                        selected: filter == e.key,
                                        onSelected: (_) =>
                                            setState(() => filter = e.key))),
                            ])),
                      if (loading) const LinearProgressIndicator(),
                      if (error != null)
                        ListTile(
                            title: Text(error!),
                            trailing: IconButton(
                                onPressed: reload,
                                icon: const Icon(Icons.refresh))),
                      if (!loading && items.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 35),
                            child: Column(children: [
                              Icon(_recordIcon(widget.kind),
                                  size: 50, color: const Color(0xFFAFBEDA)),
                              const SizedBox(height: 12),
                              Text(
                                  query.isEmpty
                                      ? 'هنوز موردی ثبت نشده است.'
                                      : 'سابقه‌ای با این مشخصات پیدا نشد.',
                                  style: const TextStyle(
                                      color: _ink, fontSize: 12)),
                            ])),
                      for (final record in items)
                        Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: _SummaryTile(
                                title:
                                    '${record['record_date'] ?? ''}${record['pending_sync'] == true ? ' • در انتظار همگام‌سازی' : ''}',
                                value: '${record['title']}',
                                icon: _recordIcon('${record['kind']}'),
                                color: _recordColor('${record['kind']}'),
                                onTap: () async {
                                  final changed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => _RecordDetailPage(
                                              personId: widget.personId,
                                              recordId: '${record['name']}',
                                              canEdit: canEdit,
                                              repository: widget.repository)));
                                  if (changed == true && mounted) {
                                    await reload();
                                  }
                                })),
                    ]))));
  }
}

class _RecordDetailPage extends StatefulWidget {
  const _RecordDetailPage(
      {required this.personId,
      required this.recordId,
      required this.canEdit,
      required this.repository});
  final String personId, recordId;
  final bool canEdit;
  final PersonnelRepository repository;
  @override
  State<_RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<_RecordDetailPage> {
  late Future<Map<String, dynamic>> future =
      widget.repository.record(widget.recordId);
  bool changed = false;
  void reload() => setState(() {
        future = widget.repository.record(widget.recordId);
      });
  Future<void> edit(Map<String, dynamic> value) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => _RecordForm(
                personId: widget.personId,
                kind: '${value['kind']}',
                repository: widget.repository,
                recordId: widget.recordId,
                initial: value)));
    if (saved == true && mounted) {
      changed = true;
      reload();
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
          canPop: !changed,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              setState(() => changed = false);
              Navigator.pop(context, true);
            }
          },
          child: FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (context, snapshot) {
                final value = snapshot.data;
                final ready = value != null &&
                    snapshot.connectionState != ConnectionState.waiting;
                return Scaffold(
                    backgroundColor: _canvas,
                    appBar: _personnelHeader(context, 'جزئیات سابقه'),
                    bottomNavigationBar: ready &&
                            widget.canEdit &&
                            value['_can_edit'] == true &&
                            value['pending_sync'] != true
                        ? _HrActionBar(
                            label: 'ویرایش سابقه',
                            icon: Icons.edit_outlined,
                            onPressed: () => edit(value))
                        : null,
                    body: !ready
                        ? Center(
                            child: snapshot.hasError
                                ? TextButton(
                                    onPressed: reload,
                                    child: const Text(
                                        'دریافت سابقه ممکن نشد؛ تلاش دوباره'))
                                : const CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                                _HrSummary(
                                    title: '${value['title']}',
                                    subtitle: _recordTitle('${value['kind']}'),
                                    icon: _recordIcon('${value['kind']}'),
                                    color: _recordColor('${value['kind']}')),
                                if (value['offline'] == true ||
                                    value['pending_sync'] == true)
                                  _SyncNotice(
                                      offline: value['offline'] == true,
                                      pending: value['pending_sync'] == true,
                                      failed: value['sync_failed'] == true),
                                if (value['_legacy'] == true)
                                  const _HrInfoCard(
                                      title: 'سابقه قبلی',
                                      values: {
                                        'وضعیت':
                                            'اطلاعات محفوظ است؛ ویرایش پس از انتقال به منابع انسانی فعال می‌شود.'
                                      }),
                                _HrInfoCard(title: 'اطلاعات سابقه', values: {
                                  for (final key in [
                                    'date',
                                    if (value['kind'] == 'attendance') ...[
                                      'start',
                                      'end'
                                    ],
                                    if (value['kind'] == 'evaluation') ...[
                                      'score',
                                      'appraisal_cycle'
                                    ]
                                  ])
                                    _recordLabels[key]!: _valueOf(value, key)
                                }),
                                if (_valueOf(value, 'notes', '').isNotEmpty)
                                  _HrInfoCard(
                                      title: 'توضیحات',
                                      values: {'شرح': '${value['notes']}'}),
                                if (value['file'] is String)
                                  _RecordAttachment(value: value),
                              ]));
              })));
}

class _RecordAttachment extends StatelessWidget {
  const _RecordAttachment({required this.value});
  final Map<String, dynamic> value;
  @override
  Widget build(BuildContext context) {
    Uint8List bytes;
    try {
      bytes = base64Decode('${value['file']}');
    } catch (_) {
      return const Text('فایل قابل نمایش نیست.');
    }
    final pdf = bytes.length >= 4 &&
        bytes[0] == 37 &&
        bytes[1] == 80 &&
        bytes[2] == 68 &&
        bytes[3] == 70;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!pdf)
        InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                        backgroundColor: _canvas,
                        appBar: _personnelHeader(context, 'نمایش تصویر'),
                        body: Center(
                            child: InteractiveViewer(
                                child: Image.memory(bytes,
                                    errorBuilder: (_, e, s) => const Text(
                                        'تصویر قابل نمایش نیست.'))))))),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(bytes,
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, s) =>
                        const Text('تصویر قابل نمایش نیست.')))),
      if (pdf)
        _HrSummary(
            title: _valueOf(value, 'filename', 'سند PDF'),
            subtitle: 'سند پیوست',
            icon: Icons.picture_as_pdf_outlined),
      const SizedBox(height: 12),
      OutlinedButton.icon(
          icon: const Icon(Icons.download_outlined),
          label: const Text('ذخیره فایل'),
          onPressed: () async {
            try {
              final filename = _valueOf(
                      value, 'filename', pdf ? 'document.pdf' : 'image.png')
                  .split(RegExp(r'[/\\]'))
                  .last;
              await FilePicker.platform
                  .saveFile(fileName: filename, bytes: bytes);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('ذخیره فایل انجام نشد؛ دوباره تلاش کنید.')));
              }
            }
          }),
    ]);
  }
}

class _RecordForm extends StatefulWidget {
  const _RecordForm(
      {required this.personId,
      required this.kind,
      required this.repository,
      this.recordId,
      this.initial});
  final String personId, kind;
  final String? recordId;
  final Map<String, dynamic>? initial;
  final PersonnelRepository repository;
  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final formKey = GlobalKey<FormState>();
  late final fields = {
    for (final key in _recordLabels.keys)
      key: TextEditingController(
          text:
              '${widget.initial?[key] ?? (key == 'date' ? DateTime.now().toIso8601String().substring(0, 10) : '')}')
  };
  final requestId = 'record-${DateTime.now().microsecondsSinceEpoch}';
  PlatformFile? file;
  bool saving = false;
  Map<String, String> appraisalCycles = {};
  bool loadingCycles = false;
  String? cycleError;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'evaluation' && !widget.repository.localDemo) {
      loadCycles();
    }
  }

  Future<void> loadCycles() async {
    setState(() {
      loadingCycles = true;
      cycleError = null;
    });
    try {
      final result = await widget.repository.recordOptions(widget.personId);
      if (!mounted) return;
      setState(() {
        appraisalCycles = {
          for (final row in result['appraisal_cycles'] as List? ?? [])
            '${row['name']}': '${row['name']}'
        };
        if (widget.initial?['appraisal_cycle'] case final String cycle) {
          appraisalCycles.putIfAbsent(cycle, () => cycle);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => cycleError = 'دریافت دوره‌های ارزیابی ممکن نشد.');
      }
    } finally {
      if (mounted) setState(() => loadingCycles = false);
    }
  }

  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    final value = <String, dynamic>{
      'kind': widget.kind,
      'title': fields['title']!.text.trim(),
      'date': fields['date']!.text.trim(),
      'notes': fields['notes']!.text.trim(),
      if (widget.kind == 'attendance') ...{
        'start': fields['start']!.text.trim(),
        'end': fields['end']!.text.trim()
      },
      if (widget.kind == 'evaluation') ...{
        'score': num.tryParse(fields['score']!.text),
        if (!widget.repository.localDemo)
          'appraisal_cycle': fields['appraisal_cycle']!.text,
      },
      if (file?.bytes != null) ...{
        'file': base64Encode(file!.bytes!),
        'filename': file!.name
      } else if (widget.initial?['file'] != null) ...{
        'file': widget.initial!['file'],
        'filename': widget.initial!['filename']
      },
    };
    try {
      validatePersonnelRecord(value);
    } on FormatException catch (e) {
      setState(() => error = e.message);
      formKey.currentState!.validate();
      return;
    }
    if (!formKey.currentState!.validate()) {
      setState(() => error = 'فیلدهای مشخص‌شده در بخش‌های فرم را بررسی کنید.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (widget.recordId == null) {
        await widget.repository.add(widget.personId, value, requestId);
      } else {
        await widget.repository.updateRecord(widget.personId, widget.recordId!,
            value, '${widget.initial!['_revision']}', requestId);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is StateError
              ? e.message
              : 'ذخیره انجام نشد؛ اتصال یا تغییر هم‌زمان سابقه را بررسی کنید. اطلاعات فرم حفظ شده است.';
        });
      }
    }
  }

  Widget time(String key) => AsoudFormField(
      controller: fields[key]!,
      label: _recordLabels[key]!,
      enabled: !saving,
      keyboardType: TextInputType.datetime,
      hint: 'HH:mm',
      validator: (v) => !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v ?? '')
          ? 'ساعت معتبر وارد کنید.'
          : null,
      suffixIcon: IconButton(
          tooltip: 'انتخاب ساعت',
          icon: const Icon(Icons.schedule),
          onPressed: saving
              ? null
              : () async {
                  final parts = fields[key]!.text.split(':');
                  final hour = int.tryParse(parts.first) ?? 8,
                      minute =
                          parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
                  final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                          hour: hour.clamp(0, 23),
                          minute: minute.clamp(0, 59)));
                  if (selected != null) {
                    fields[key]!.text =
                        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
                  }
                }));
  @override
  Widget build(BuildContext context) => AsoudFormPage(
          title:
              '${widget.recordId == null ? 'ثبت' : 'ویرایش'} ${_recordTitle(widget.kind)}',
          subtitle: 'پرونده پرسنلی',
          formKey: formKey,
          saving: saving,
          error: error,
          onSave: save,
          children: [
            AsoudFormSection(title: 'اطلاعات اصلی', children: [
              AsoudFormField(
                  controller: fields['title']!,
                  label: 'عنوان *',
                  enabled: !saving,
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.trim().length > 140
                          ? 'عنوان بین ۱ تا ۱۴۰ نویسه وارد کنید.'
                          : null),
              AsoudFormDateField(
                  controller: fields['date']!,
                  label: 'تاریخ *',
                  required: true,
                  enabled: !saving),
            ]),
            if (widget.kind == 'attendance')
              AsoudFormSection(title: 'ساعات حضور', children: [
                Row(children: [
                  Expanded(child: time('start')),
                  const SizedBox(width: 8),
                  Expanded(child: time('end'))
                ]),
              ]),
            if (widget.kind == 'evaluation')
              AsoudFormSection(title: 'نتیجه ارزیابی', children: [
                if (!widget.repository.localDemo) ...[
                  if (loadingCycles) const LinearProgressIndicator(),
                  if (cycleError != null)
                    TextButton(onPressed: loadCycles, child: Text(cycleError!)),
                  AsoudFormDropdown(
                      controller: fields['appraisal_cycle']!,
                      label: 'دوره ارزیابی *',
                      options: appraisalCycles,
                      required: true,
                      enabled:
                          !saving && !loadingCycles && widget.recordId == null),
                  const Text(
                      'این فرم برای دوره‌های دارای یک معیار با وزن ۱۰۰٪ است. دوره و الگو باید در منابع انسانی تعریف و به پرسنل اختصاص داده شوند.',
                      style: TextStyle(fontSize: 11)),
                  const SizedBox(height: 12),
                ],
                AsoudFormField(
                    controller: fields['score']!,
                    label: 'امتیاز هدف از ۱۰۰ *',
                    keyboardType: TextInputType.number,
                    enabled: !saving,
                    validator: (v) {
                      final score = num.tryParse(v ?? '');
                      return score == null ||
                              !score.isFinite ||
                              score < 0 ||
                              score > 100
                          ? 'امتیاز بین صفر و صد وارد کنید.'
                          : null;
                    }),
              ]),
            if (widget.kind == 'document' || widget.kind == 'photo')
              AsoudFormSection(title: 'فایل پیوست', children: [
                if (widget.initial?['file'] != null && file == null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                          'فایل فعلی: ${widget.initial!['filename'] ?? 'پیوست'}',
                          style: const TextStyle(fontSize: 11))),
                OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(file?.name ?? 'انتخاب فایل'),
                    onPressed: saving
                        ? null
                        : () async {
                            try {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                      withData: true,
                                      type: FileType.custom,
                                      allowedExtensions: widget.kind == 'photo'
                                          ? ['jpg', 'jpeg', 'png']
                                          : ['pdf', 'jpg', 'jpeg', 'png']);
                              if (result == null || !mounted) return;
                              final selected = result.files.single;
                              if (selected.bytes == null ||
                                  selected.size > 5 * 1024 * 1024) {
                                setState(() =>
                                    error = 'فایل تا ۵ مگابایت انتخاب کنید.');
                                return;
                              }
                              setState(() {
                                file = selected;
                                error = null;
                              });
                            } catch (_) {
                              if (mounted) {
                                setState(() => error =
                                    'انتخاب فایل انجام نشد؛ دوباره تلاش کنید.');
                              }
                            }
                          }),
                const SizedBox(height: 8),
                Text(
                    widget.kind == 'photo'
                        ? 'JPG یا PNG، حداکثر ۵ مگابایت'
                        : 'PDF، JPG یا PNG، حداکثر ۵ مگابایت',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF8392B8))),
              ]),
            AsoudFormSection(title: 'توضیحات', children: [
              AsoudFormField(
                  controller: fields['notes']!,
                  label: 'شرح و توضیحات',
                  lines: 4,
                  enabled: !saving,
                  validator: (v) => (v?.length ?? 0) > 5000
                      ? 'حداکثر ۵۰۰۰ نویسه وارد کنید.'
                      : null)
            ]),
          ]);
}
