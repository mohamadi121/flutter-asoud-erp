part of 'roles_page.dart';

const _accessActions = {
  'read': 'مشاهده',
  'create': 'ایجاد',
  'write': 'ویرایش',
  'delete': 'حذف'
};

/// Thin, injectable wrapper over the bounded user-access API
/// (`asoud_erp.api.v1.user_access`). The page never calls the raw client so a
/// fake repository can replay the exact backend shapes in tests.
class UserAccessRepository {
  UserAccessRepository(this.client);
  final FrappeApiClient client;

  Future<dynamic> _unwrap(Future<Map<String, dynamic>> response) async {
    final body = await response;
    final envelope = body['message'];
    if (envelope is! Map) throw const ApiException.protocol();
    return AsoudApiResponse<dynamic>.parse(
        Map<String, dynamic>.from(envelope), (value) => value).data;
  }

  Future<dynamic> call(String method, Map<String, dynamic> data) async {
    if (!client.isAuthenticated) {
      throw const ApiException(
          kind: ApiFailureKind.unauthenticated,
          message: 'برای مدیریت دسترسی وارد حساب مدیر شوید.');
    }
    return _unwrap(
        client.callMethod('asoud_erp.api.v1.user_access.$method', data: data));
  }

  Future<List<Map<String, dynamic>>> directory(String code,
      {String search = '', bool candidates = false}) async {
    final data = await call('directory', {
      'code': code,
      'search': search,
      if (candidates) 'candidates': 1,
    });
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  /// Managed roles offered by the shared role catalog, used only to pick the
  /// role whose users this page will manage.
  Future<List<ManagedRole>> roles() async {
    if (!client.isAuthenticated) {
      throw const ApiException(
          kind: ApiFailureKind.unauthenticated,
          message: 'برای مدیریت دسترسی وارد حساب مدیر شوید.');
    }
    final data = await _unwrap(
        client.callMethod('asoud_erp.api.v1.role_management.catalog'));
    final map = Map<String, dynamic>.from(data as Map);
    return ((map['roles'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => ManagedRole.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<String> draftKey(String code, String user) async {
    final owner = (await client.getCurrentUser()).userId;
    final server = client is FrappeClient
        ? (client as FrappeClient).serverIdentity
        : 'test';
    return 'access-draft:${Uri.encodeComponent(jsonEncode([
          server,
          owner,
          code,
          user
        ]))}';
  }
}

Future<T?> _userAccessRoute<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(
        builder: (_) => Directionality(
            textDirection: TextDirection.rtl, child: page)));

/// Settings entry point for user access. With a role it manages that role's
/// users directly; without one it lets the manager pick the role first, because
/// the backend API is role-scoped.
class UserAccessPage extends StatelessWidget {
  const UserAccessPage({this.role, required this.repository, super.key});
  final ManagedRole? role;
  final UserAccessRepository repository;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: role == null
            ? _UserAccessRoles(repository: repository)
            : _RoleUsersView(role: role!, repository: repository),
      );
}

class _UserAccessRoles extends StatefulWidget {
  const _UserAccessRoles({required this.repository});
  final UserAccessRepository repository;
  @override
  State<_UserAccessRoles> createState() => _UserAccessRolesState();
}

class _UserAccessRolesState extends State<_UserAccessRoles> {
  List<ManagedRole> roles = [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository.roles();
      if (!mounted) return;
      setState(() => roles = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
            title: 'مدیریت کاربران',
            subtitle: 'انتخاب نقش برای مدیریت دسترسی کاربران'),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ErrorState(failure: error!, onRetry: load)
                : roles.isEmpty
                    ? const EmptyState(
                        icon: Icons.shield_outlined,
                        title: 'نقشی برای مدیریت یافت نشد',
                        description:
                            'ابتدا از «مدیریت نقش‌ها» یک نقش بسازید، سپس کاربران آن را اینجا مدیریت کنید.')
                    : ListView(padding: const EdgeInsets.all(16), children: [
                        const Text(
                            'برای هر نقش، دسترسی مشترک و دسترسی تک‌تک کاربران را مدیریت کنید.'),
                        const SizedBox(height: 12),
                        for (final role in roles)
                          Card(
                              child: ListTile(
                            leading: const Icon(Icons.shield_outlined,
                                color: AsoudColors.primary),
                            title: Text(persianRoleLabel(
                                role.title.isNotEmpty ? role.title : role.code)),
                            subtitle:
                                Text(formatCount(role.assignedUsers, 'کاربر')),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => _userAccessRoute<void>(
                                context,
                                _RoleUsersView(
                                    role: role,
                                    repository: widget.repository)),
                          )),
                      ]),
      );
}

class _RoleUsersView extends StatefulWidget {
  const _RoleUsersView({required this.role, required this.repository});
  final ManagedRole role;
  final UserAccessRepository repository;
  @override
  State<_RoleUsersView> createState() => _RoleUsersViewState();
}

class _RoleUsersViewState extends State<_RoleUsersView> {
  final search = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  Object? error;
  int version = 0;
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
    final request = ++version;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository
          .directory(widget.role.code, search: search.text.trim());
      if (!mounted || request != version) return;
      setState(() => users = result);
    } catch (e) {
      if (mounted && request == version) setState(() => error = e);
    } finally {
      if (mounted && request == version) setState(() => loading = false);
    }
  }

  Future<void> open({Map<String, dynamic>? user, bool shared = false}) async {
    await _userAccessRoute<void>(
        context,
        _AccessWizard(
            role: widget.role,
            repository: widget.repository,
            user: user,
            shared: shared));
    if (mounted) await load();
  }

  Future<void> editUser(Map<String, dynamic> user) async {
    await _userAccessRoute<void>(
        context,
        _AccessUserEdit(user: user, repository: widget.repository));
    if (mounted) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(
            title: 'کاربران و دسترسی‌ها',
            subtitle: persianRoleLabel(widget.role.title.isNotEmpty
                ? widget.role.title
                : widget.role.code)),
        body: error != null
            ? ErrorState(failure: error!, onRetry: load)
            : ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                    child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: const Text('دسترسی‌های این نقش'),
                        subtitle:
                            const Text('تغییرات مشترک برای کاربران این نقش'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => open(shared: true))),
                const SizedBox(height: 12),
                TextField(
                    controller: search,
                    decoration: InputDecoration(
                        hintText: 'جستجو با نام، ایمیل یا شماره تماس',
                        suffixIcon: IconButton(
                            onPressed: load, icon: const Icon(Icons.search))),
                    onSubmitted: (_) => load()),
                const SizedBox(height: 12),
                if (loading) const Center(child: CircularProgressIndicator()),
                if (!loading && users.isEmpty)
                  const Text('کاربری برای این نقش یافت نشد.'),
                for (final user in users)
                  Card(
                      child: ListTile(
                    leading:
                        const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text('${user['full_name'] ?? user['name']}'),
                    subtitle: Text('${user['mobile_no'] ?? user['name']}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(user['enabled'] == 1 ? 'فعال' : 'غیرفعال',
                          style: TextStyle(
                              color: user['enabled'] == 1
                                  ? AsoudColors.success
                                  : AsoudColors.muted)),
                      IconButton(
                          tooltip: 'ویرایش اطلاعات کاربر',
                          onPressed: () => editUser(user),
                          icon: const Icon(Icons.edit_outlined, size: 18)),
                    ]),
                    onTap: () => open(user: user),
                    onLongPress: () => editUser(user),
                  )),
                const Text(
                    'برای ویرایش اطلاعات کاربر، کارت او را نگه دارید. فهرست تا ۱۰۰ نتیجه دارد؛ برای محدودکردن نتایج جستجو کنید.',
                    style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
              ]),
        bottomNavigationBar: AsoudBottomActions(
            primaryLabel: 'افزودن کاربر به نقش', onPrimary: () => open()),
      );
}

class _AccessWizard extends StatefulWidget {
  const _AccessWizard(
      {required this.role,
      required this.repository,
      this.user,
      this.shared = false});
  final ManagedRole role;
  final UserAccessRepository repository;
  final Map<String, dynamic>? user;
  final bool shared;
  @override
  State<_AccessWizard> createState() => _AccessWizardState();
}

class _AccessWizardState extends State<_AccessWizard> {
  late Map<String, dynamic>? user = widget.user;
  final search = TextEditingController();
  List<Map<String, dynamic>> candidates = [];
  List<Map<String, dynamic>> catalog = [];
  Map<String, Set<String>> grants = {}, inherited = {};
  Map<String, Set<String>> saved = {};
  List<String> baseRoles = [];
  int step = 0, mode = 0, generation = 0;
  bool busy = true, success = false;
  String? error, token, draftKey;
  @override
  void initState() {
    super.initState();
    if (widget.shared || user != null) {
      step = 1;
      loadEditor();
    } else {
      loadCandidates();
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Map<String, Set<String>> decode(dynamic value) =>
      Map<String, dynamic>.from(value as Map)
          .map((key, value) => MapEntry(key, Set<String>.from(value as List)));

  Map<String, Set<String>> _copy(Map<String, Set<String>> source) =>
      source.map((key, value) => MapEntry(key, {...value}));

  bool get changed {
    if (grants.length != saved.length) return true;
    for (final entry in grants.entries) {
      final other = saved[entry.key];
      if (other == null ||
          entry.value.length != other.length ||
          !entry.value.containsAll(other)) {
        return true;
      }
    }
    return false;
  }

  Future<void> loadCandidates() async {
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.repository.directory(widget.role.code,
          search: search.text.trim(), candidates: true);
      if (!mounted || request != generation) return;
      setState(() => candidates = data);
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = failureMessage(e));
      }
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  Future<void> loadEditor() async {
    setState(() {
      busy = true;
      error = null;
      token = null;
    });
    try {
      final data = Map<String, dynamic>.from(await widget.repository.call(
              'editor',
              {'code': widget.role.code, 'user': user?['name'] ?? ''})
          as Map);
      final key =
          await widget.repository.draftKey(widget.role.code, '${user?['name'] ?? ''}');
      if (!mounted) return;
      setState(() {
        catalog = (data['catalog'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        grants = decode(data['grants']);
        inherited = decode(data['inherited']);
        saved = _copy(grants);
        baseRoles = List<String>.from(data['base_roles'] as List);
        token = data['token'] as String;
        draftKey = key;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = failureMessage(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void toggle(String dt, String action, bool value) {
    setState(() {
      final values = grants[dt]!;
      if (value) {
        values.add(action);
        values.add('read');
      } else if (action == 'read') {
        values.clear();
      } else {
        values.remove(action);
      }
    });
  }

  Future<void> saveDraft() async {
    if (draftKey == null) return;
    try {
      final ok = await (await SharedPreferences.getInstance()).setString(
          draftKey!,
          jsonEncode({
            'token': token,
            'mode': mode,
            'grants': grants.map((key, value) => MapEntry(key, value.toList())),
          }));
      if (!ok) throw StateError('write failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'پیش‌نویس روی دستگاه ذخیره شد؛ هیچ دسترسی فعال نشده است.')));
      }
    } catch (_) {
      if (mounted) setState(() => error = 'ذخیره پیش‌نویس انجام نشد.');
    }
  }

  Future<void> restoreDraft() async {
    if (draftKey == null) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(draftKey!);
      if (raw == null) {
        if (mounted) {
          setState(() => error = 'پیش‌نویسی برای این کاربر و نقش وجود ندارد.');
        }
        return;
      }
      final data = jsonDecode(raw) as Map;
      if (data['token'] != token) throw StateError('stale');
      final restored = decode(data['grants']);
      if (restored.length != catalog.length ||
          catalog.any((row) {
            final values = restored[row['doctype']];
            return values == null ||
                values.any((a) => !(row['actions'] as List).contains(a)) ||
                (values.isNotEmpty && !values.contains('read'));
          })) {
        throw StateError('invalid draft');
      }
      if (!mounted) return;
      setState(() {
        grants = restored;
        mode = (data['mode'] as int).clamp(0, 2).toInt();
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'پیش‌نویس قدیمی یا نامعتبر است؛ با مجوزهای فعلی دوباره تنظیم کنید.');
      }
    }
  }

  Future<void> apply() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.call('apply', {
        'payload': {
          'code': widget.role.code,
          'user': user?['name'] ?? '',
          'token': token,
          'grants': grants.map((key, value) => MapEntry(key, value.toList()))
        }
      });
      if (result is! Map || result['applied'] != true) {
        throw const ApiException(
            kind: ApiFailureKind.protocol,
            message: 'اعمال دسترسی تأیید نشد.');
      }
      if (!mounted) return;
      setState(() {
        success = true;
        saved = _copy(grants);
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = failureMessage(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget matrix(List<Map<String, dynamic>> rows) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 8,
          columnSpacing: 6,
          columns: [
            const DataColumn(label: Text('عملیات')),
            for (final a in _accessActions.values)
              DataColumn(label: Text(a, style: const TextStyle(fontSize: 11)))
          ],
          rows: rows.map((row) {
            final dt = row['doctype'] as String;
            return DataRow(cells: [
              DataCell(SizedBox(
                  width: 100,
                  child: Text('${row['title']}',
                      style: const TextStyle(fontSize: 11)))),
              for (final a in _accessActions.keys)
                DataCell(Tooltip(
                  message: inherited[dt]!.contains(a)
                      ? 'از نقش دیگر؛ ممکن است محدود به اسناد خود کاربر باشد'
                      : '',
                  child: Checkbox(
                      value:
                          grants[dt]!.contains(a) || inherited[dt]!.contains(a),
                      onChanged: busy ||
                              inherited[dt]!.contains(a) ||
                              !(row['actions'] as List).contains(a)
                          ? null
                          : (value) => toggle(dt, a, value!)),
                )),
            ]);
          }).toList(),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final modules = catalog.map((e) => e['module'] as String).toSet();
    return Scaffold(
      appBar: AsoudHeader(
          title: success
              ? 'نتیجه اعمال دسترسی'
              : step == 2
                  ? 'بررسی و ارسال'
                  : 'تعیین نقش و دسترسی',
          subtitle: persianRoleLabel(widget.role.title.isNotEmpty
              ? widget.role.title
              : widget.role.code)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (success) ...[
          const SizedBox(height: 60),
          const Icon(Icons.check_circle, size: 88, color: AsoudColors.success),
          const SizedBox(height: 20),
          const Center(child: Text('تغییرات دسترسی در سرور ثبت شد.')),
          const Text(
              'دسترسی به هر سند همچنان تابع محدودیت شرکت، مالکیت و قواعد بومی سرور است.'),
        ] else ...[
          Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                  child: Column(children: [
                CircleAvatar(
                    radius: 15,
                    backgroundColor:
                        step == i ? AsoudColors.primary : AsoudColors.border,
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white))),
                const SizedBox(height: 6),
                Text(['انتخاب شخص', 'نقش و دسترسی', 'بررسی و ارسال'][i],
                    style: const TextStyle(fontSize: 10)),
              ]))
          ]),
          const SizedBox(height: 18),
          if (user != null || widget.shared)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(widget.shared
                        ? 'دسترسی مشترک نقش'
                        : '${user!['full_name'] ?? user!['name']}'),
                    subtitle: Text(widget.shared
                        ? 'برای همه کاربران این نقش اعمال می‌شود.'
                        : '${user!['name']}'))),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!,
                    style: const TextStyle(color: AsoudColors.danger))),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (step == 0) ...[
            TextField(
                controller: search,
                decoration: InputDecoration(
                    hintText: 'نام، ایمیل یا شماره تماس',
                    suffixIcon: IconButton(
                        onPressed: busy ? null : loadCandidates,
                        icon: const Icon(Icons.search))),
                onSubmitted: (_) => loadCandidates()),
            const Text(
                'انتخاب از حساب‌های موجود؛ اطلاعات هویتی نمونه ساخته نمی‌شود.',
                style: TextStyle(fontSize: 11)),
            for (final candidate in candidates)
              Card(
                  child: ListTile(
                      title: Text(
                          '${candidate['full_name'] ?? candidate['name']}'),
                      subtitle: Text('${candidate['name']}'),
                      onTap: busy
                          ? null
                          : () {
                              setState(() {
                                user = candidate;
                                step = 1;
                              });
                              loadEditor();
                            })),
          ],
          if (step == 1 && token != null) ...[
            Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                    child: TextButton(
                        onPressed: busy ? null : () => setState(() => mode = i),
                        style: TextButton.styleFrom(
                            backgroundColor: mode == i
                                ? AsoudColors.primary.withValues(alpha: .1)
                                : null),
                        child: Text(['ساده', 'متوسط', 'پیشرفته'][i])))
            ]),
            const Text(
                'قفل‌ها از نقش‌های دیگر هستند. تغییر حالت، دسترسی بیشتری فعال نمی‌کند. حالت ساده فقط مشاهده را اضافه می‌کند؛ مجوز ثبت قطعی، لغو سند و اشتراک‌گذاری خارج از این ماتریس است.',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
            for (final module in modules)
              if (mode == 0)
                Card(
                    child: SwitchListTile(
                        title: Text(module),
                        subtitle: const Text('مشاهده اطلاعات ماژول'),
                        value: catalog
                            .where((r) => r['module'] == module)
                            .every((r) =>
                                grants[r['doctype']]!.contains('read') ||
                                inherited[r['doctype']]!.contains('read')),
                        onChanged: busy
                            ? null
                            : (value) {
                                for (final row in catalog
                                    .where((r) => r['module'] == module)) {
                                  if (!inherited[row['doctype']]!
                                      .contains('read')) {
                                    toggle(row['doctype'] as String, 'read',
                                        value);
                                  }
                                }
                              }))
              else
                Card(
                    child: ExpansionTile(
                        initiallyExpanded: mode == 2,
                        key: ValueKey('$module-$mode'),
                        title: Text(module),
                        children: [
                      matrix(
                          catalog.where((r) => r['module'] == module).toList())
                    ])),
            Wrap(children: [
              TextButton(
                  onPressed: busy ? null : saveDraft,
                  child: const Text('ذخیره پیش‌نویس روی دستگاه')),
              TextButton(
                  onPressed: busy ? null : restoreDraft,
                  child: const Text('بازیابی پیش‌نویس'))
            ]),
          ],
          if (step == 2) ...[
            if (baseRoles.isNotEmpty)
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                    'نقش‌های پایه همراه این تخصیص: ${baseRoles.map(persianRoleLabel).join('، ')}\n'
                    'این نقش‌ها می‌توانند مجوزهایی خارج از جدول داشته باشند، از جمله ثبت قطعی اسناد. '
                    'این جدول جایگزین مجوزهای بومی آن‌ها نیست.'),
              )),
            Text('خلاصه دسترسی‌ها · ${['ساده', 'متوسط', 'پیشرفته'][mode]}'),
            for (final row in catalog.where((r) =>
                grants[r['doctype']]!.isNotEmpty ||
                inherited[r['doctype']]!.isNotEmpty))
              ListTile(
                  title: Text('${row['title']}'),
                  subtitle: Text({
                    ...grants[row['doctype']]!,
                    ...inherited[row['doctype']]!
                  }.map((a) => _accessActions[a]).join('، '))),
            const Text(
                'ارسال، مجوزهای این بخش را تغییر می‌دهد؛ دسترسی نقش‌های دیگر حذف نمی‌شود.'),
            if (!changed)
              const Text(
                  'تا زمانی که موردی تغییر نکرده، ارسال غیرفعال است.',
                  style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
            TextButton(
                onPressed: busy ? null : saveDraft,
                child: const Text('ذخیره پیش‌نویس بدون اعمال')),
          ],
          if (!busy && step == 1 && token == null)
            OutlinedButton(
                onPressed: loadEditor, child: const Text('تلاش دوباره')),
        ],
      ]),
      bottomNavigationBar: AsoudBottomActions(
        primaryLabel: success
            ? 'بازگشت به لیست کاربران'
            : step == 2
                ? 'ارسال دسترسی‌ها'
                : 'مرحله بعد',
        onPrimary: busy
            ? null
            : success
                ? () => Navigator.pop(context)
                : step == 2
                    ? (changed ? apply : null)
                    : step == 1 && token != null
                        ? () => setState(() => step = 2)
                        : null,
        secondaryLabel: !success && step == 2 ? 'ویرایش' : null,
        onSecondary: busy ? null : () => setState(() => step = 1),
      ),
    );
  }
}

class _AccessUserEdit extends StatefulWidget {
  const _AccessUserEdit({required this.user, required this.repository});
  final Map<String, dynamic> user;
  final UserAccessRepository repository;
  @override
  State<_AccessUserEdit> createState() => _AccessUserEditState();
}

class _AccessUserEditState extends State<_AccessUserEdit> {
  late final first =
      TextEditingController(text: '${widget.user['first_name'] ?? ''}');
  late final last =
      TextEditingController(text: '${widget.user['last_name'] ?? ''}');
  late final mobile =
      TextEditingController(text: '${widget.user['mobile_no'] ?? ''}');
  late bool enabled = widget.user['enabled'] == 1;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    first.dispose();
    last.dispose();
    mobile.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (first.text.trim().isEmpty) {
      setState(() => error = 'نام الزامی است.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.call('update_user', {
        'payload': {
          'user': widget.user['name'],
          'modified': widget.user['modified'],
          'first_name': first.text.trim(),
          'last_name': last.text.trim(),
          'mobile_no': mobile.text.trim(),
          'enabled': enabled ? 1 : 0,
        }
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = failureMessage(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(title: 'ویرایش اطلاعات کاربر'),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (error != null)
            Text(error!, style: const TextStyle(color: AsoudColors.danger)),
          for (final field in [
            (first, 'نام'),
            (last, 'نام خانوادگی'),
            (mobile, 'شماره موبایل')
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                    controller: field.$1,
                    enabled: !busy,
                    decoration: InputDecoration(labelText: field.$2))),
          ListTile(
              title: const Text('ایمیل / شناسه حساب'),
              subtitle: Text('${widget.user['name']}')),
          SwitchListTile(
              title: const Text('فعال'),
              value: enabled,
              onChanged:
                  busy ? null : (value) => setState(() => enabled = value)),
        ]),
        bottomNavigationBar: AsoudBottomActions(
            primaryLabel: busy ? 'در حال ذخیره…' : 'ذخیره تغییرات',
            onPrimary: busy ? null : save),
      );
}
