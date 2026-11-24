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
  bool busy = true;
  String? error;
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

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: AsoudColors.background,
          appBar: const AsoudHeader(title: 'مدیریت کاربران'),
          body: busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (error != null) ...[
                    Text(error!),
                    TextButton(
                        onPressed: load, child: const Text('تلاش دوباره'))
                  ] else ...[
                    FilledButton.icon(
                        onPressed: () => open(OfficeAccountCreate(
                            company: widget.company,
                            people: people,
                            repository: repo)),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('ایجاد حساب کاربری')),
                    for (final person in people
                        .where((p) => '${p['user_id'] ?? ''}'.isNotEmpty))
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text('${person['employee_name']}'),
                              subtitle: Text(
                                  '${person['designation'] ?? ''} · ${widget.company}'),
                              onTap: () => open(OfficeAccountDetails(
                                  company: widget.company,
                                  employee: '${person['name']}',
                                  repository: repo)))),
                    if (people.every((p) => '${p['user_id'] ?? ''}'.isEmpty))
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                              'هنوز حسابی به پرسنل این دفتر متصل نشده است.')),
                  ],
                ])));
}

class OfficeAccountCreate extends StatefulWidget {
  const OfficeAccountCreate(
      {required this.company,
      required this.people,
      required this.repository,
      super.key});
  final String company;
  final List<AccessMap> people;
  final AccessManagementRepository repository;
  @override
  State<OfficeAccountCreate> createState() => _OfficeAccountCreateState();
}

class _OfficeAccountCreateState extends State<OfficeAccountCreate> {
  final contact = TextEditingController();
  String? employee, error;
  String method = 'mobile';
  bool invite = false, busy = false;
  @override
  void dispose() {
    contact.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    if (employee == null || contact.text.trim().isEmpty) {
      setState(() => error = 'پرسنل و اطلاعات ورود را تکمیل کنید.');
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
        'contact': contact.text.trim(),
        'method': method,
        'invite': invite ? 1 : 0
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
                            : (v) => setState(() => employee = v)))),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'mobile', label: Text('موبایل')),
                            ButtonSegment(value: 'email', label: Text('ایمیل'))
                          ],
                          selected: {
                            method
                          },
                          onSelectionChanged: busy
                              ? null
                              : (v) => setState(() {
                                    method = v.first;
                                    contact.clear();
                                  })),
                      TextField(
                          controller: contact,
                          enabled: !busy,
                          textDirection: TextDirection.ltr,
                          keyboardType: method == 'mobile'
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                          decoration: InputDecoration(
                              labelText: method == 'mobile'
                                  ? 'شماره موبایل'
                                  : 'ایمیل')),
                    ]))),
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'دسترسی اولیه حساب فقط شخصی است. دفتر از پرونده پرسنلی تعیین می‌شود؛ دسترسی تخصصی بعداً در تب دسترسی‌ها تنظیم می‌شود.'))),
            SwitchListTile(
                title: const Text('ارسال دعوت‌نامه پس از ایجاد حساب'),
                value: invite,
                onChanged: busy ? null : (v) => setState(() => invite = v)),
            if (error != null)
              Text(error!, style: const TextStyle(color: AsoudColors.danger)),
          ]),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                        child: FilledButton(
                            onPressed: busy ? null : save,
                            child: Text(
                                busy ? 'در حال ایجاد…' : 'ایجاد حساب کاربری'))),
                    const SizedBox(width: 8),
                    OutlinedButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('انصراف')),
                  ])))));
}

Future<void> showActivation(BuildContext context, dynamic activation) async {
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
      final result = await widget.repository.call('invite_account', args);
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
                          SelectableText('${account!['login'] ?? account!['user']}',
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
