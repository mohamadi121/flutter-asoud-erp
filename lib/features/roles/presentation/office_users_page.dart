import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/auth/personnel_representation.dart';
import '../../../core/theme/asoud_colors.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/jalali_date.dart' show toPersianDigits;
import '../../../core/widgets/asoud_ui.dart';
import '../data/access_management_repository.dart';
import 'access_profiles_page.dart';

part 'office_access_layout.dart';

class OfficeUsersPage extends StatefulWidget {
  const OfficeUsersPage({required this.company, this.repository, super.key});
  final String company;
  final AccessManagementRepository? repository;
  @override
  State<OfficeUsersPage> createState() => _OfficeUsersState();
}

class _OfficeUsersState extends State<OfficeUsersPage> {
  late final repo = widget.repository ??
      AccessManagementRepository(context.read<FrappeApiClient>());
  List<AccessMap> people = [];
  final search = TextEditingController();
  String selectedDepartment = '', selectedStatus = '', selectedProfile = '';
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = accessRows(
          await repo.call('list_accounts', {'company': widget.company}));
      if (mounted) setState(() => people = rows);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await load();
  }

  static const _groups = [
    ('', 'همه پرسنل', AsoudColors.primary),
    ('finance', 'مالی و حسابداری', AsoudColors.primary),
    ('hr', 'منابع انسانی', AsoudColors.success),
    ('sales', 'فروش و بازرگانی', AsoudColors.warning),
    ('operations', 'عملیات و انبار', AsoudColors.purple),
    ('it', 'فناوری اطلاعات', AsoudColors.cyan),
  ];
  static const _statusLabels = {
    '': 'همه وضعیت‌ها',
    'no_account': 'بدون حساب',
    'active': 'فعال',
    'pending': 'در انتظار فعال‌سازی',
    'disabled': 'غیرفعال',
  };

  String _department(AccessMap person) =>
      '${person['department'] ?? ''}'.trim();

  String _group(String department) {
    final value = department.toLowerCase().replaceAll('‌', ' ');
    const keywords = {
      'finance': ['مالی', 'حسابداری', 'finance', 'accounting', 'accounts'],
      'hr': ['منابع انسانی', 'human resource', 'hr'],
      'sales': ['فروش', 'بازرگانی', 'بازاریابی', 'sales', 'marketing'],
      'operations': [
        'انبار',
        'عملیات',
        'تولید',
        'operations',
        'warehouse',
        'production'
      ],
      'it': [
        'فناوری اطلاعات',
        'تکنولوژی اطلاعات',
        'information technology',
        'it'
      ],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any((word) => word.length == 2
          ? value.split(RegExp(r'[^a-z]+')).contains(word)
          : value.contains(word))) {
        return entry.key;
      }
    }
    return department;
  }

  String _status(AccessMap person) =>
      '${person['account_status'] ?? (('${person['user_id'] ?? ''}'.isEmpty) ? 'no_account' : 'active')}';

  bool _matchesUnit(AccessMap person, String unit) =>
      unit.isEmpty ||
      (unit.startsWith('unit:')
          ? _department(person) == unit.substring(5)
          : _group(_department(person)) == unit);

  List<AccessMap> get filteredPeople {
    final query = search.text.trim().toLowerCase();
    return people
        .where((p) =>
            _matchesUnit(p, selectedDepartment) &&
            (selectedStatus.isEmpty || _status(p) == selectedStatus) &&
            (selectedProfile.isEmpty || p['profile'] == selectedProfile) &&
            '${p['employee_name'] ?? ''} ${p['name'] ?? ''} ${p['designation'] ?? ''} ${_department(p)}'
                .toLowerCase()
                .contains(query))
        .toList();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<(String, String, String)>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OfficePeopleFilters(
        initial: (selectedDepartment, selectedStatus, selectedProfile),
        statuses: _statusLabels,
        units: {
          '': 'همه واحدها',
          for (final (key, title, _) in _groups.skip(1))
            if (selectedDepartment == key) key: 'گروه $title',
          for (final department
              in people.map(_department).where((d) => d.isNotEmpty).toSet())
            'unit:$department': department,
        },
        loadProfiles: () async {
          final data = await repo
              .call('list_profiles', {'company': widget.company}) as Map;
          return accessRows(data['profiles'])
              .where((p) => p['readonly'] != true)
              .toList();
        },
        profileAvailable: people.isEmpty ||
            people.any((person) => person.containsKey('profile')),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        selectedDepartment = result.$1;
        selectedStatus = result.$2;
        selectedProfile = result.$3;
      });
    }
  }

  Widget _departmentSummary() => _OfficePanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ساختار سازمانی',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 6) / 2;
            return Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (key, title, color) in _groups)
                SizedBox(
                    width: tileWidth,
                    height: 55,
                    child: Material(
                      key: ValueKey('office-group:$key'),
                      color: color.withValues(alpha: .10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                            color: selectedDepartment == key
                                ? color
                                : Colors.transparent),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => selectedDepartment = key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                              Text(
                                  '${toPersianDigits(people.where((p) => _matchesUnit(p, key)).length)} نفر',
                                  style: TextStyle(color: color, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    )),
            ]);
          }),
        ]),
      );

  Widget _personCard(AccessMap person) {
    final login =
        '${person['user_id'] ?? ''}'.replaceFirst('@users.asoud.invalid', '');
    final status = _status(person);
    final color = _officeStatusColor(status);
    final name = '${person['employee_name'] ?? 'پرسنل'}';
    return _OfficePanel(
      borderColor: color.withValues(alpha: .28),
      child: Column(children: [
        _OfficePersonHeading(
            name: name,
            designation: '${person['designation'] ?? ''}',
            department: _department(person),
            code: '${person['name'] ?? ''}',
            status: _statusLabels[status] ?? '',
            color: color),
        const Divider(height: 16, color: AsoudColors.border),
        Row(children: [
          Expanded(
              child: Text(login.isEmpty ? 'حساب ثبت نشده است' : login,
                  style:
                      const TextStyle(fontSize: 11, color: AsoudColors.muted),
                  overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => login.isNotEmpty
                ? open(OfficeAccountDetails(
                    company: widget.company,
                    employee: '${person['name']}',
                    repository: repo))
                : open(OfficeAccountCreate(
                    company: widget.company,
                    people: people,
                    repository: repo,
                    initialEmployee: '${person['name']}')),
            style: FilledButton.styleFrom(
                backgroundColor: login.isEmpty
                    ? AsoudColors.primary
                    : const Color(0xFFE8F1FF),
                foregroundColor:
                    login.isEmpty ? Colors.white : AsoudColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: Text(login.isEmpty ? 'ایجاد حساب' : 'مدیریت حساب'),
          ),
          if (person['can_represent'] == true)
            PopupMenuButton<String>(
              tooltip: 'گزینه‌های $name',
              onSelected: (_) => _represent(person),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'represent',
                  child: Text('ورود به نمایندگی از پرسنل')),
              ],
            ),
        ]),
      ]),
    );
  }

  Future<void> _represent(AccessMap person) async {
    PersonnelRepresentationLauncher? launcher;
    try {
      launcher = context.read<PersonnelRepresentationLauncher>();
    } catch (_) {}
    if (launcher == null) return;
    final reason = await showDialog<String>(context: context,
      builder: (_) => _RepresentationReason(name: '${person['employee_name']}'));
    if (!mounted || reason == null) return;
    try {
      await launcher.open(context, widget.company, '${person['name']}', reason);
    } catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(failure))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AsoudColors.background,
          appBar: const _OfficeAccessHeader(
              title: 'مدیریت کاربران',
              subtitle: 'حساب‌های کاربری پرسنل سازمان'),
          body: busy
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    children: [
                      _departmentSummary(),
                      if (error != null) ...[
                        Text(error!,
                            style: const TextStyle(color: AsoudColors.danger)),
                        TextButton(
                            onPressed: load, child: const Text('تلاش دوباره')),
                      ] else ...[
                        Row(children: [
                          const Expanded(
                              child: Text('فهرست پرسنل',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800))),
                          Text('${toPersianDigits(filteredPeople.length)} نفر',
                              style: const TextStyle(
                                  color: AsoudColors.muted, fontSize: 11)),
                        ]),
                        const SizedBox(height: 7),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: search,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                      hintText: 'نام یا کد پرسنلی',
                                      isDense: true,
                                      prefixIcon: Icon(Icons.search, size: 19),
                                      filled: true,
                                      fillColor: Colors.white))),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                              onPressed: _openFilters,
                              icon: const Icon(Icons.tune, size: 17),
                              label: const Text('فیلتر')),
                        ]),
                        const SizedBox(height: 8),
                        if (people.isEmpty)
                          const _OfficePanel(
                              child: Text(
                                  'در این دفتر هنوز پروندهٔ پرسنلی فعال ثبت نشده است.'))
                        else if (filteredPeople.isEmpty)
                          const _OfficePanel(
                              child: Text(
                                  'پرسنلی با این جست‌وجو یا فیلتر پیدا نشد.'))
                        else
                          for (final person in filteredPeople)
                            _personCard(person),
                      ],
                    ],
                  ),
                ),
        ),
      );
}

class OfficeAccountCreate extends StatefulWidget {
  const OfficeAccountCreate(
      {required this.company,
      required this.people,
      required this.repository,
      this.initialEmployee,
      super.key});
  final String company;
  final List<AccessMap> people;
  final AccessManagementRepository repository;
  final String? initialEmployee;
  @override
  State<OfficeAccountCreate> createState() => _OfficeAccountCreateState();
}

class _OfficeAccountCreateState extends State<OfficeAccountCreate> {
  String? employee, error;
  String method = 'mobile';
  bool manualCode = false;
  bool busy = false;
  List<String> get methods {
    for (final person in widget.people) {
      if (person['name'] == employee) {
        return (person['contact_methods'] as List? ?? [])
            .whereType<String>()
            .where((value) => value == 'mobile' || value == 'email')
            .toList();
      }
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    employee = widget.initialEmployee;
    if (methods.isNotEmpty) method = methods.first;
  }

  Future<void> save() async {
    if (busy) return;
    if (employee == null || !methods.contains(method)) {
      setState(() => error =
          'پرسنلی را انتخاب کنید که شماره موبایل یا ایمیل معتبر در پرونده دارد.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.call('create_account', {
        'company': widget.company,
        'employee': employee,
        'method': method,
        'invite': 1,
        if (manualCode) 'delivery': 'manual_code',
      });
      if (!mounted) return;
      await showActivation(
          context, result is Map ? result['activation'] : null);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: AsoudColors.background,
          appBar: const AsoudHeader(title: 'ایجاد حساب کاربری'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.people.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                          'برای ایجاد حساب، پروندهٔ پرسنلیِ موجود باید از سرور دریافت شود. این فرم پرسنل جدید ایجاد نمی‌کند و تا دریافت فهرست پرسنل، امکان ثبت حساب وجود ندارد.'))),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DropdownButtonFormField<String>(
                        initialValue: employee,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'انتخاب پرسنل موجود'),
                        items: [
                          for (final p in widget.people
                              .where((p) => '${p['user_id'] ?? ''}'.isEmpty))
                            DropdownMenuItem(
                                value: '${p['name']}',
                                child: Text('${p['employee_name']}',
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                  employee = v;
                                  error = null;
                                  if (methods.isNotEmpty) {
                                    method = methods.first;
                                  }
                                })))),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      if (methods.length > 1)
                        SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'mobile', label: Text('موبایل')),
                              ButtonSegment(
                                  value: 'email', label: Text('ایمیل'))
                            ],
                            selected: {
                              method
                            },
                            onSelectionChanged: busy
                                ? null
                                : (v) => setState(() {
                                      method = v.first;
                                    })),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(employee == null
                              ? 'ابتدا پرسنل را انتخاب کنید.'
                              : methods.isEmpty
                                  ? 'شماره موبایل یا ایمیل معتبر در پرونده ثبت نشده است.'
                                  : manualCode
                                      ? 'کد و شناسهٔ ورود بعد از ساخت حساب نمایش داده می‌شوند؛ ارسال خودکار انجام نمی‌شود.'
                                      : method == 'mobile'
                                          ? 'نام کاربری و رمز موقت به موبایل ثبت‌شده پیامک می‌شود.'
                                          : 'نام کاربری و کد فعال‌سازی به ایمیل ثبت‌شده ارسال می‌شود.')),
                      CheckboxListTile(
                        title: const Text('دریافت کد دعوت دستی'),
                        value: manualCode,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: busy
                            ? null
                            : (value) =>
                                setState(() => manualCode = value == true),
                      ),
                    ]))),
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'دسترسی اولیه حساب فقط شخصی است. دفتر از پرونده پرسنلی تعیین می‌شود؛ دسترسی تخصصی بعداً در تب دسترسی‌ها تنظیم می‌شود.'))),
            if (error != null)
              Text(error!, style: const TextStyle(color: AsoudColors.danger)),
          ]),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                        child: FilledButton(
                            onPressed:
                                busy || !methods.contains(method) ? null : save,
                            child: Text(
                                busy ? 'در حال ایجاد…' : 'ایجاد حساب کاربری'))),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('انصراف')),
                  ])))));
}

Future<void> showActivation(BuildContext context, dynamic activation) async {
  if (activation is Map &&
      activation['method'] == 'manual_code' &&
      activation['code'] is String) {
    final code = activation['code'] as String;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        title: const Text('کد دعوت یک‌بارمصرف'),
        content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'این کد فقط همین بار نمایش داده می‌شود. شناسه و کد را فقط به صاحب حساب بدهید.'),
            const SizedBox(height: 8),
            const Text('شناسهٔ ورود'),
            SelectableText('${activation['login']}',
                textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            Card(
                child: ListTile(
              title: SelectableText(code, textDirection: TextDirection.ltr),
              trailing: IconButton(
                tooltip: 'کپی کد',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (dialog.mounted) {
                    ScaffoldMessenger.of(dialog).showSnackBar(
                      const SnackBar(content: Text('کد دعوت کپی شد.')),
                    );
                  }
                },
              ),
            )),
            Text('اعتبار: ${activation['expires_in_hours']} ساعت'),
            const Text(
                'صاحب حساب در صفحهٔ ورود، گزینهٔ «کد دعوت‌نامه دارید؟ فعال‌سازی حساب» را انتخاب کند.'),
          ],
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('بستن')),
        ],
      ),
    );
    return;
  }
  if (activation is Map && ['sms', 'invite'].contains(activation['method'])) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('دعوت‌نامه برای صاحب حساب ارسال شد.')),
    );
    return;
  }
  final password = activation is Map ? activation['temporary_password'] : null;
  if (password == null) return;
  await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
              title: const Text('رمز موقت حساب'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'این رمز فقط یک بار نمایش داده می‌شود؛ آن را به صاحب حساب تحویل دهید.'),
                SelectableText('$password', textDirection: TextDirection.ltr),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('بستن'))
              ]));
}

class OfficeAccountDetails extends StatefulWidget {
  const OfficeAccountDetails(
      {required this.company,
      required this.employee,
      required this.repository,
      super.key});
  final String company, employee;
  final AccessManagementRepository repository;
  @override
  State<OfficeAccountDetails> createState() => _OfficeAccountDetailsState();
}

class _OfficeAccountDetailsState extends State<OfficeAccountDetails> {
  AccessMap? account;
  List<AccessMap> profiles = [], catalog = [];
  AccessMap? catalogLayout;
  Map<String, List<String>> grants = {};
  String? selected, error;
  bool busy = true;
  Map<String, dynamic> get args =>
      {'company': widget.company, 'employee': widget.employee};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final a = Map<String, dynamic>.from(
          await widget.repository.call('get_account', args) as Map);
      final p = await widget.repository
          .call('list_profiles', {'company': widget.company}) as Map;
      if (mounted) {
        setState(() {
          account = a;
          catalog = accessRows(a['catalog']);
          catalogLayout = accessRows([a['catalog_layout']]).firstOrNull;
          grants = accessGrants(a['grants']);
          profiles = accessRows(p['profiles'])
              .where((p) => p['readonly'] != true)
              .toList();
          selected = profiles.any((p) => p['name'] == a['profile'])
              ? a['profile'] as String?
              : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || account?['token'] == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.call('save_account_access', {
        ...args,
        'grants': grants,
        'token': account!['token'],
        'profile': selected
      });
      if (mounted) {
        await load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('دسترسی‌ها ذخیره شدند.')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> invite({bool manual = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.call('invite_account', {
        ...args,
        'registered': account?['registered_delivery'] == true ? 1 : 0,
        if (manual) 'delivery': 'manual_code',
      });
      if (mounted) await showActivation(context, result);
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
          length: 2,
          child: Scaffold(
              backgroundColor: AsoudColors.background,
              appBar: const _OfficeAccessHeader(
                  title: 'مدیریت حساب',
                  subtitle: 'حساب کاربری و دسترسی‌های پرسنل'),
              body: account == null
                  ? (busy
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: Text(error ?? 'اطلاعات حساب دریافت نشد.')))
                  : Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: _OfficePanel(
                            child: _OfficePersonHeading(
                          name: '${account!['title'] ?? ''}',
                          designation: '${account!['designation'] ?? ''}',
                          department: '${account!['department'] ?? ''}',
                          code: toPersianDigits(
                              '${account!['employee'] ?? widget.employee}'),
                          status: account!['activation_pending'] == true
                              ? 'در انتظار فعال‌سازی'
                              : switch (account!['account_status']) {
                                  'active' => 'فعال',
                                  'disabled' => 'غیرفعال',
                                  _ => '',
                                },
                          color: account!['activation_pending'] == true
                              ? AsoudColors.primary
                              : _officeStatusColor(
                                  '${account!['account_status'] ?? 'disabled'}'),
                        )),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AsoudColors.primary.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TabBar(
                          dividerHeight: 0,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AsoudColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tabs: const [
                            Tab(height: 39, text: 'حساب کاربری'),
                            Tab(height: 39, text: 'دسترسی‌ها'),
                          ],
                        ),
                      ),
                      Expanded(
                          child: TabBarView(children: [
                        ListView(padding: const EdgeInsets.all(12), children: [
                          SelectableText(
                              '${account!['login'] ?? account!['user']}',
                              textDirection: TextDirection.ltr),
                          if (account!['activation_pending'] == true) ...[
                            OutlinedButton(
                                onPressed: busy ? null : () => invite(),
                                child:
                                    const Text('تحویل دعوت‌نامه و فعال‌سازی')),
                            OutlinedButton(
                              onPressed:
                                  busy ? null : () => invite(manual: true),
                              child: const Text('صدور مجدد کد دعوت دستی'),
                            ),
                          ],
                          if (error != null) Text(error!),
                        ]),
                        ListView(padding: const EdgeInsets.all(12), children: [
                          if (account!['legacy'] == true)
                            const Text(
                                'مجوزهای قبلی بدون دفتر هستند؛ تا بررسی و تأیید اتصال دفتر فقط قابل مشاهده‌اند.'),
                          _OfficePanel(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('الگوی مجوزهای این حساب',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                  initialValue: selected ?? '',
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      labelText: 'پروفایل دسترسی (اختیاری)'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '',
                                        child: Text('فقط دسترسی پایه شخصی')),
                                    for (final p in profiles)
                                      DropdownMenuItem(
                                          value: '${p['name']}',
                                          child: Text('${p['title']}'))
                                  ],
                                  onChanged: busy || account!['legacy'] == true
                                      ? null
                                      : (v) => setState(() {
                                            selected = v == '' ? null : v;
                                            if (selected != null) {
                                              for (final entry in accessGrants(
                                                      profiles.firstWhere((p) =>
                                                          p['name'] ==
                                                          selected)['grants'])
                                                  .entries) {
                                                grants[entry.key] = <String>{
                                                  ...?grants[entry.key],
                                                  ...entry.value
                                                }.toList();
                                              }
                                            }
                                          })),
                              const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AsoudColors.muted),
                                      'انتخاب پروفایل، مجوزها را برای بازبینی اضافه می‌کند؛ تغییرات دستی حذف نمی‌شوند. اعمال فقط با ذخیره انجام می‌شود.')),
                            ],
                          )),
                          AccessPermissionMatrix(
                              catalog: catalog,
                              layout: catalogLayout,
                              grants: grants,
                              enabled: !busy && account!['token'] != null,
                              onChanged: () => setState(() {})),
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                  'تغییرات فقط برای همین حساب و همین دفتر است.')),
                          if (error != null)
                            Text(error!,
                                style:
                                    const TextStyle(color: AsoudColors.danger)),
                          FilledButton(
                              onPressed: busy || account!['token'] == null
                                  ? null
                                  : save,
                              child: Text(
                                  busy ? 'در حال ذخیره…' : 'ذخیره دسترسی‌ها')),
                        ]),
                      ])),
                    ]))));
}
