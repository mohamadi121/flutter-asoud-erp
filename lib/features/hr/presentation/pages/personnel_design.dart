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
                    if (state.canEdit)
                      Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('مدیریت و پیشنهاد پرسنل نمونه'),
                              onPressed: state.loading
                                  ? null
                                  : () async {
                                      await Navigator.push<void>(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  PartyManagementPage(
                                                      company: cubit.company,
                                                      initialRole:
                                                          PartyRole.employee)));
                                      if (context.mounted) await cubit.load();
                                    })),
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
                          canManage: state.canEdit,
                          repository: cubit.repository,
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => PersonnelFilePage(
                                        profileId: '${person['id']}',
                                        personnel: cubit.repository)));
                            if (context.mounted) await cubit.load();
                          }),
                  ])),
        );
      }));
}

class _PersonnelRow extends StatelessWidget {
  const _PersonnelRow(
      {required this.profile,
      required this.repository,
      required this.onTap,
      required this.canManage});
  final bool canManage;
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
                      if (canManage)
                        _PersonnelAccountMenu(
                            profile: profile, repository: repository),
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

class _EmployeeUserDetailsPage extends StatefulWidget {
  const _EmployeeUserDetailsPage(
      {required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  State<_EmployeeUserDetailsPage> createState() =>
      _EmployeeUserDetailsPageState();
}

class _EmployeeUserDetailsPageState extends State<_EmployeeUserDetailsPage> {
  late Future<Map<String, dynamic>> future = _load();
  Future<Map<String, dynamic>> _load() async {
    final value = await context.read<FrappeApiClient>().callAsoudMethod(
        'asoud_erp.api.v1.auth.get_employee_access',
        data: {'party_profile': '${widget.profile['id']}'});
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> remove() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('حذف دسترسی کاربر'),
                content: const Text(
                    'اتصال و نقش‌های واگذارشدهٔ این پرونده حذف شود؟ حساب ورود سراسری حذف نمی‌شود.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف دسترسی')),
                ]));
    if (confirm != true || !mounted) return;
    try {
      await context.read<FrappeApiClient>().callAsoudMethod(
          'asoud_erp.api.v1.auth.delete_employee_access',
          data: {'party_profile': '${widget.profile['id']}'});
      if (mounted) {
        setState(() {
          future = _load();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'حذف دسترسی انجام نشد؛ اتصال و مجوز مدیر را بررسی کنید.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'جزئیات کاربر'),
          body: FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: TextButton(
                          onPressed: () => setState(() {
                                future = _load();
                              }),
                          child: const Text('دریافت ناموفق؛ تلاش دوباره')));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final matrix = Map<String, dynamic>.from(
                    data['access_matrix'] as Map? ?? {});
                return ListView(padding: const EdgeInsets.all(16), children: [
                  _AccessHeaderCard(
                      profile: widget.profile,
                      enabled: data['enabled'] == true),
                  const SizedBox(height: 14),
                  _AccessInfoCard(
                      title: 'دسترسی‌ها',
                      icon: Icons.admin_panel_settings_outlined,
                      rows: {
                        'نقش‌ها':
                            (data['roles'] as List? ?? const []).join('، '),
                        'وضعیت': data['enabled'] == true ? 'فعال' : 'غیرفعال',
                        'شماره موبایل': _valueOf(widget.profile, 'mobile'),
                        'ایمیل': '${data['email'] ?? 'ثبت نشده'}',
                        'روش ورود': 'ایمیل (دعوت)',
                      }),
                  const SizedBox(height: 10),
                  _AccessInfoCard(
                      title: 'مجوزهای ماژول',
                      icon: Icons.grid_view_rounded,
                      rows: {
                        for (final entry in matrix.entries)
                          entry.key:
                              '${(entry.value as List? ?? const []).length} مجوز',
                      }),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                      onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PersonnelRolesPage(
                                  employeeName:
                                      _valueOf(widget.profile, 'display_name'),
                                  employeeCode: _valueOf(
                                      widget.profile,
                                      'employee_code',
                                      _valueOf(widget.profile, 'id')),
                                  mobile: _valueOf(widget.profile, 'mobile'),
                                  initialValue:
                                      (data['roles'] as List? ?? const [])
                                          .map((item) => '$item')
                                          .toSet(),
                                  initialStep: 2,
                                  onConfirm: (roles, matrix) async {
                                    await context
                                        .read<FrappeApiClient>()
                                        .callAsoudMethod(
                                            'asoud_erp.api.v1.auth.sync_employee_access',
                                            data: {
                                          'party_profile':
                                              '${widget.profile['id']}',
                                          'email': data['email'],
                                          'personnel_roles': roles.toList(),
                                          'access_matrix': matrix
                                        });
                                    if (mounted) {
                                      setState(() {
                                        future = _load();
                                      });
                                    }
                                  }))),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('ویرایش دسترسی‌ها')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: remove,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('حذف دسترسی از دفتر',
                          style: TextStyle(color: Colors.red))),
                ]);
              })));
}

class _EmployeeInvitationsPage extends StatefulWidget {
  const _EmployeeInvitationsPage(
      {required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  State<_EmployeeInvitationsPage> createState() =>
      _EmployeeInvitationsPageState();
}

class _EmployeeInvitationsPageState extends State<_EmployeeInvitationsPage> {
  late Future<List<Map<String, dynamic>>> future = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    final value = await context.read<FrappeApiClient>().callAsoudMethod(
        'asoud_erp.api.v1.auth.list_employee_invitations',
        data: {'company': '${widget.profile['company']}'});
    return (Map<String, dynamic>.from(value as Map)['rows'] as List? ??
            const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'دعوت‌های ارسال‌شده'),
          body: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: TextButton(
                          onPressed: () => setState(() {
                                future = _load();
                              }),
                          child: const Text('دریافت ناموفق؛ تلاش دوباره')));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                return ListView(padding: const EdgeInsets.all(16), children: [
                  _PersonnelAccessSteps(active: 2),
                  const SizedBox(height: 12),
                  const Text('وضعیت دعوت‌ها از صف ارسال سرور دریافت می‌شود.'),
                  const SizedBox(height: 10),
                  for (final row in rows) _InvitationCard(row: row),
                  if (rows.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('دعوتی ارسال نشده است.',
                            textAlign: TextAlign.center)),
                ]);
              }),
          bottomNavigationBar: _HrActionBar(
              label: 'ارسال دعوت',
              icon: Icons.send_outlined,
              onPressed: () async {
                await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _InviteReviewPage(
                            profile: widget.profile,
                            repository: widget.repository)));
                if (mounted) {
                  setState(() {
                    future = _load();
                  });
                }
              })));
}

class _InviteReviewPage extends StatefulWidget {
  const _InviteReviewPage({required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  State<_InviteReviewPage> createState() => _InviteReviewPageState();
}

class _InviteReviewPageState extends State<_InviteReviewPage> {
  late final email =
      TextEditingController(text: _valueOf(widget.profile, 'email', ''));
  String method = 'ایمیل';
  Set<String> roles = {};
  Map<String, List<String>> matrix = {};
  bool saving = false;
  String? error;
  final requestId = 'invite-${DateTime.now().microsecondsSinceEpoch}';
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> pickAccess() async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => PersonnelRolesPage(
                employeeName: _valueOf(widget.profile, 'display_name'),
                employeeCode: _valueOf(widget.profile, 'employee_code',
                    _valueOf(widget.profile, 'id')),
                mobile: _valueOf(widget.profile, 'mobile'),
                onConfirm: (value, selected) async {
                  roles = value;
                  matrix = selected;
                })));
    if (mounted) setState(() {});
  }

  Future<void> send() async {
    if (email.text.trim().isEmpty || roles.isEmpty) return;
    setState(() => saving = true);
    try {
      await context.read<FrappeApiClient>().callAsoudMethod(
          'asoud_erp.api.v1.auth.send_employee_invitation',
          data: {
            'party_profile': '${widget.profile['id']}',
            'email': email.text.trim(),
            'personnel_roles': roles.toList(),
            'access_matrix': matrix,
            'method': method,
            'request_id': requestId,
          });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'دعوت ثبت نشد؛ تنظیم ایمیل خروجی، نقش و اتصال را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'بررسی و ارسال دعوت'),
          bottomNavigationBar: _HrActionBar(
              label: 'ارسال دعوت',
              icon: Icons.send_outlined,
              onPressed: saving ? null : send),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            _PersonnelAccessSteps(active: 3),
            const SizedBox(height: 12),
            _AccessHeaderCard(profile: widget.profile, enabled: false),
            const SizedBox(height: 10),
            _AccessInfoCard(
                title: 'خلاصه دسترسی‌ها',
                icon: Icons.admin_panel_settings_outlined,
                rows: {
                  'نقش‌ها': roles.isEmpty ? 'انتخاب نشده' : roles.join('، '),
                  'مجوزها': '${matrix.length} ماژول انتخاب شده',
                }),
            const SizedBox(height: 10),
            _AccessField(
                label: 'ایمیل گیرنده دعوت',
                icon: Icons.email_outlined,
                child: TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress)),
            const SizedBox(height: 8),
            _AccessField(
                label: 'روش ارسال',
                icon: Icons.send_outlined,
                child: DropdownButton<String>(
                    value: method,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ایمیل', child: Text('ایمیل'))
                    ],
                    onChanged: (value) => setState(() => method = value!))),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: pickAccess,
                icon: const Icon(Icons.tune_outlined),
                label: const Text('انتخاب نقش و دسترسی')),
          ])));
}

class _PersonnelAccessSteps extends StatelessWidget {
  const _PersonnelAccessSteps({required this.active});
  final int active;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (final entry in const [
          (1, 'انتخاب شخص'),
          (2, 'نقش و دسترسی'),
          (3, 'بررسی و ارسال')
        ])
          Expanded(
              child: Column(children: [
            CircleAvatar(
                radius: 12,
                backgroundColor: entry.$1 == active ? _blue : _line,
                child: Text('${entry.$1}',
                    style: TextStyle(
                        color: entry.$1 == active ? Colors.white : _ink,
                        fontSize: 10))),
            const SizedBox(height: 4),
            Text(entry.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color:
                        entry.$1 == active ? _blue : const Color(0xFF8392B8))),
          ])),
      ]);
}

class _AccessHeaderCard extends StatelessWidget {
  const _AccessHeaderCard({required this.profile, required this.enabled});
  final Map<String, dynamic> profile;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(_valueOf(profile, 'display_name'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(_valueOf(profile, 'mobile')),
          trailing: Chip(
              label: Text(enabled ? 'فعال' : 'دعوت نشده',
                  style: const TextStyle(fontSize: 9)))));
}

class _AccessInfoCard extends StatelessWidget {
  const _AccessInfoCard(
      {required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final Map<String, String> rows;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, color: _blue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900))
            ]),
            const SizedBox(height: 6),
            for (final row in rows.entries)
              ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.key,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF8392B8))),
                  trailing: Text(row.value,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700)))
          ])));
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('${row['personnel']}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              '${row['email']}\nزمان ارسال تأییدشده: ${row['sent_at'] ?? 'ثبت نشده'}'),
          isThreeLine: true,
          trailing: Chip(
              label: Text('${row['status']}',
                  style: const TextStyle(fontSize: 9)))));
}

class _PersonnelAccessPage extends StatefulWidget {
  const _PersonnelAccessPage({required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  State<_PersonnelAccessPage> createState() => _PersonnelAccessPageState();
}

class _PersonnelAccessPageState extends State<_PersonnelAccessPage> {
  late final TextEditingController email =
      TextEditingController(text: '${widget.profile['email'] ?? ''}');
  Set<String> roles = {};
  Map<String, List<String>> accessMatrix = {};
  bool loading = true;
  bool loaded = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final data = await context.read<FrappeApiClient>().callAsoudMethod(
          'asoud_erp.api.v1.auth.get_employee_access',
          data: {'party_profile': '${widget.profile['id']}'});
      email.text = '${data['email'] ?? ''}';
      roles = (data['roles'] as List? ?? []).map((value) => '$value').toSet();
      accessMatrix = {};
      loaded = true;
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'دریافت دسترسی فعلی ناموفق بود؛ فرم را دوباره باز کنید.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (email.text.trim().isEmpty || roles.isEmpty) {
      setState(() => error = 'ایمیل و حداقل یک نقش را انتخاب کنید.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await context
          .read<FrappeApiClient>()
          .callAsoudMethod('asoud_erp.api.v1.auth.sync_employee_access', data: {
        'party_profile': '${widget.profile['id']}',
        'email': email.text.trim().toLowerCase(),
        'personnel_roles': roles.toList(),
        'access_matrix': accessMatrix,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'ذخیره دسترسی انجام نشد؛ نقش، ایمیل و دسترسی مدیر سیستم را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> selectRoles() async {
    final result = await Navigator.push<Set<String>>(
        context,
        MaterialPageRoute(
            builder: (_) => PersonnelRolesPage(
                initialValue: roles,
                employeeName: _valueOf(widget.profile, 'display_name'),
                employeeCode: _valueOf(widget.profile, 'employee_code',
                    _valueOf(widget.profile, 'id')),
                mobile: _valueOf(widget.profile, 'mobile'),
                onConfirm: (value, matrix) async {
                  roles = value;
                  accessMatrix = matrix;
                })));
    if (result != null && mounted) setState(() => roles = result);
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: _canvas,
          appBar: _personnelHeader(context, 'مدیریت دسترسی'),
          bottomNavigationBar: _HrActionBar(
              label: 'ذخیره دسترسی',
              icon: Icons.save_outlined,
              onPressed: saving || loading || !loaded ? null : save),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _PersonnelAccessHeader(profile: widget.profile),
            const SizedBox(height: 12),
            _AccessField(
                label: 'ایمیل حساب کاربری',
                icon: Icons.email_outlined,
                child: TextField(
                    controller: email,
                    enabled: !saving,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        hintText: 'employee@example.com'))),
            const SizedBox(height: 10),
            _AccessField(
                label: 'نقش‌ها و دسترسی‌های عملیاتی',
                icon: Icons.admin_panel_settings_outlined,
                child: InkWell(
                    onTap: saving ? null : selectRoles,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          Expanded(
                              child: Text(roles.isEmpty
                                  ? 'انتخاب نقش‌ها'
                                  : roles.join('، '))),
                          const Icon(Icons.chevron_left_rounded, color: _blue),
                        ])))),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: const TextStyle(color: Color(0xFFD83B55)))),
            const SizedBox(height: 12),
            const _AccessNotice(),
          ])));
}

class _PersonnelAccessHeader extends StatelessWidget {
  const _PersonnelAccessHeader({required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line)),
      child: Row(children: [
        const Icon(Icons.person_outline_rounded, color: _blue, size: 28),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_valueOf(profile, 'display_name'),
              style: const TextStyle(
                  color: _ink, fontSize: 14, fontWeight: FontWeight.w900)),
          Text(_valueOf(profile, 'job_title'),
              style: const TextStyle(color: Color(0xFF8392B8), fontSize: 10)),
        ])),
      ]));
}

class _AccessField extends StatelessWidget {
  const _AccessField(
      {required this.label, required this.icon, required this.child});
  final String label;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: _blue, size: 20),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: _ink, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        child,
      ]));
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFE7F2FF),
          borderRadius: BorderRadius.circular(13)),
      child: const Text(
          'این عملیات فقط برای مدیر منابع انسانی مجاز است. ایجاد حساب، اتصال کارمند و نقش‌ها در سرور بررسی می‌شود.',
          style:
              TextStyle(color: Color(0xFF6680A8), fontSize: 10, height: 1.7)));
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

class _PersonnelAccountMenu extends StatelessWidget {
  const _PersonnelAccountMenu(
      {required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final PersonnelRepository repository;
  @override
  Widget build(BuildContext context) => buildPersonnelAccountMenu(
      context: context, profile: profile, repository: repository);
}

/// The single declaration of the employee-account actions. The personnel list
/// row and the personnel file page both build their ⋮ menu from this list, so
/// the two entry points can never drift apart.
const personnelAccountMenuEntries =
    <({String value, String title, IconData icon})>[
  (
    value: 'access',
    title: 'مدیریت دسترسی',
    icon: Icons.admin_panel_settings_outlined
  ),
  (
    value: 'account',
    title: 'ایجاد/تغییر حساب کاربری',
    icon: Icons.person_outline
  ),
  (value: 'invite', title: 'ارسال مجدد دعوت', icon: Icons.mail_outline),
  (value: 'logs', title: 'مشاهده سوابق ورود', icon: Icons.description_outlined),
];

Widget buildPersonnelAccountMenu({
  required BuildContext context,
  required Map<String, dynamic> profile,
  required PersonnelRepository repository,
}) {
  return PopupMenuButton<String>(
    tooltip: 'مدیریت دسترسی',
    icon: const Icon(Icons.more_vert_rounded, color: _ink, size: 20),
    onSelected: (value) {
      if (value == 'access' || value == 'account') {
        Navigator.push<void>(
            context,
            MaterialPageRoute(
                builder: (_) => _EmployeeUserDetailsPage(
                    profile: profile, repository: repository)));
      } else if (value == 'invite') {
        Navigator.push<void>(
            context,
            MaterialPageRoute(
                builder: (_) => _EmployeeInvitationsPage(
                    profile: profile, repository: repository)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('این قابلیت هنوز به سرویس متصل نشده است.')));
      }
    },
    itemBuilder: (_) => [
      for (final entry in personnelAccountMenuEntries)
        PopupMenuItem(
            value: entry.value,
            child:
                ListTile(leading: Icon(entry.icon), title: Text(entry.title))),
    ],
  );
}
