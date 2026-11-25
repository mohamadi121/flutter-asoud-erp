import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/theme/asoud_colors.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/asoud_ui.dart';
import '../data/access_management_repository.dart';
import 'access_profiles_page.dart';

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
  String selectedDepartment = 'همه', selectedStatus = 'همه';
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

  List<String> get departments => {
        'همه',
        ...people
            .map((p) => '${p['department'] ?? ''}'.trim())
            .where((value) => value.isNotEmpty)
      }.toList();

  List<AccessMap> get filteredPeople {
    final query = search.text.trim().toLowerCase();
    return people.where((p) {
      final department = '${p['department'] ?? ''}'.trim();
      final status =
          '${p['account_status'] ?? (('${p['user_id'] ?? ''}'.isEmpty) ? 'no_account' : 'active')}';
      final matchesDepartment =
          selectedDepartment == 'همه' || department == selectedDepartment;
      final matchesStatus = selectedStatus == 'همه' ||
          (selectedStatus == 'بدون حساب' && status == 'no_account') ||
          (selectedStatus == 'فعال' && status == 'active') ||
          (selectedStatus == 'در انتظار فعال‌سازی' && status == 'pending') ||
          (selectedStatus == 'غیرفعال' && status == 'disabled');
      final searchable =
          '${p['employee_name'] ?? ''} ${p['name'] ?? ''} ${p['designation'] ?? ''} $department'
              .toLowerCase();
      return matchesDepartment &&
          matchesStatus &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  String _status(AccessMap person) =>
      '${person['account_status'] ?? (('${person['user_id'] ?? ''}'.isEmpty) ? 'no_account' : 'active')}';
  String _statusTitle(AccessMap person) => switch (_status(person)) {
        'no_account' => 'بدون حساب',
        'pending' => 'دعوت ارسال‌شده',
        'disabled' => 'غیرفعال',
        _ => 'فعال',
      };
  Color _statusColor(AccessMap person) => switch (_status(person)) {
        'no_account' => AsoudColors.warning,
        'pending' => AsoudColors.primary,
        'disabled' => AsoudColors.danger,
        _ => AsoudColors.success,
      };

  Widget _departmentSummary() {
    final groups = <String, int>{};
    for (final person in people) {
      final name = '${person['department'] ?? ''}'.trim();
      if (name.isNotEmpty) {
        groups.update(name, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final names = groups.keys.toList();
    return Card(
      color: AsoudColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - 6) / 2;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ساختار سازمانی',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _departmentChip(
                      tileWidth,
                      'همه پرسنل',
                      people.length,
                      AsoudColors.primary,
                      selectedDepartment == 'همه',
                      () => setState(() => selectedDepartment = 'همه')),
                  for (var i = 0; i < names.length; i++)
                    _departmentChip(
                        tileWidth,
                        names[i],
                        groups[names[i]]!,
                        profileAccent(i + 1),
                        selectedDepartment == names[i],
                        () => setState(() => selectedDepartment = names[i])),
                ]),
                const SizedBox(height: 12),
              ]);
        }),
      ),
    );
  }

  Widget _departmentChip(double width, String title, int count, Color color,
          bool selected, VoidCallback onTap) =>
      SizedBox(
          width: width,
          child: Material(
            color: color.withValues(alpha: selected ? .13 : .07),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: selected ? color : Colors.transparent),
            ),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  child: Row(children: [
                    Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 12))),
                    Text('$count',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold))
                  ]),
                )),
          ));

  Widget _personCard(AccessMap person) {
    final hasAccount = '${person['user_id'] ?? ''}'.isNotEmpty;
    final color = _statusColor(person);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: .32))),
      child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(Icons.person_outline, size: 18, color: color)),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${person['employee_name'] ?? 'پرسنل'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '${person['designation'] ?? 'بدون عنوان شغلی'} · ${person['department'] ?? 'بدون واحد'}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                    Text('کد پرسنلی: ${person['name']}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(_statusTitle(person),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 7),
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => hasAccount
                      ? open(OfficeAccountDetails(
                          company: widget.company,
                          employee: '${person['name']}',
                          repository: repo))
                      : open(OfficeAccountCreate(
                          company: widget.company,
                          people: people,
                          repository: repo,
                          initialEmployee: '${person['name']}')),
                  icon: Icon(
                      hasAccount
                          ? Icons.manage_accounts_outlined
                          : Icons.person_add_alt_1,
                      size: 16),
                  label: Text(hasAccount ? 'مدیریت حساب' : 'ایجاد حساب'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10)),
                )),
          ])),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: AsoudColors.background,
          appBar: const AsoudHeader(title: 'مدیریت کاربران'),
          body: busy
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    FilledButton.icon(
                      onPressed: error != null ||
                              people
                                  .where((p) => _status(p) == 'no_account')
                                  .isEmpty
                          ? null
                          : () => open(OfficeAccountCreate(
                              company: widget.company,
                              people: people,
                              repository: repo)),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('ایجاد حساب کاربری'),
                    ),
                    const SizedBox(height: 12),
                    if (error != null) ...[
                      Text(error!,
                          style: const TextStyle(color: AsoudColors.danger)),
                      TextButton(
                          onPressed: load, child: const Text('تلاش دوباره')),
                    ] else ...[
                      _departmentSummary(),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: search,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText:
                                        'جست‌وجو در نام، کد پرسنلی یا سمت',
                                    isDense: true))),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                            value: selectedStatus,
                            underline: const SizedBox.shrink(),
                            items: [
                              'همه',
                              'بدون حساب',
                              'فعال',
                              'در انتظار فعال‌سازی',
                              'غیرفعال'
                            ]
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selectedStatus = v ?? 'همه')),
                      ]),
                      const SizedBox(height: 8),
                      Text('فهرست پرسنل · ${filteredPeople.length} نفر',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      if (people.isEmpty)
                        const Card(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                    'در این دفتر هنوز پروندهٔ پرسنلی فعال ثبت نشده است. برای ایجاد حساب، ابتدا پروندهٔ پرسنلی را در منابع انسانی ثبت کنید.')))
                      else if (filteredPeople.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                                child: Text(
                                    'پرسنلی با این جست‌وجو یا فیلتر پیدا نشد.')))
                      else
                        for (final person in filteredPeople)
                          _personCard(person),
                    ],
                  ]))));
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
                                  : method == 'mobile'
                                      ? 'نام کاربری و رمز موقت به موبایل ثبت‌شده پیامک می‌شود.'
                                      : 'نام کاربری و کد فعال‌سازی به ایمیل ثبت‌شده ارسال می‌شود.')),
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

  Future<void> invite() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.call('invite_account', {
        ...args,
        'registered': account?['registered_delivery'] == true ? 1 : 0,
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
              appBar: const AsoudHeader(title: 'جزئیات حساب کاربری'),
              body: account == null
                  ? (busy
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: Text(error ?? 'اطلاعات حساب دریافت نشد.')))
                  : Column(children: [
                      ListTile(
                          title: Text('${account!['title']}'),
                          subtitle: Text(
                              '${account!['designation']} · ${widget.company}')),
                      const TabBar(tabs: [
                        Tab(text: 'اطلاعات حساب'),
                        Tab(text: 'دسترسی‌ها')
                      ]),
                      Expanded(
                          child: TabBarView(children: [
                        ListView(padding: const EdgeInsets.all(16), children: [
                          SelectableText(
                              '${account!['login'] ?? account!['user']}',
                              textDirection: TextDirection.ltr),
                          if (account!['token'] != null)
                            OutlinedButton(
                                onPressed: busy ? null : invite,
                                child:
                                    const Text('تحویل دعوت‌نامه و فعال‌سازی')),
                          if (error != null) Text(error!),
                        ]),
                        ListView(padding: const EdgeInsets.all(16), children: [
                          if (account!['legacy'] == true)
                            const Text(
                                'مجوزهای قبلی بدون دفتر هستند؛ تا بررسی و تأیید اتصال دفتر فقط قابل مشاهده‌اند.'),
                          DropdownButtonFormField<String>(
                              initialValue: selected,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'پروفایل دسترسی (اختیاری)'),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('تنظیم دستی')),
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
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                  'انتخاب پروفایل، مجوزها را برای بازبینی اضافه می‌کند؛ تغییرات دستی حذف نمی‌شوند. اعمال فقط با ذخیره انجام می‌شود.')),
                          AccessPermissionMatrix(
                              catalog: catalog,
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
