part of 'roles_page.dart';

/// Read-only list of the effective permissions of one role, computed by the
/// server (`permission_preview`). For «مدیر کل سیستم» this shows the complete
/// organisation-wide list.
class _RolePermissions extends StatefulWidget {
  const _RolePermissions({required this.role});
  final ManagedRole role;
  @override
  State<_RolePermissions> createState() => _RolePermissionsState();
}

class _RolePermissionsState extends State<_RolePermissions> {
  List<RolePermissionRow>? rows;
  List<RoleCapability> capabilities = const [];
  String? error;
  bool loading = true;

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
      final repository = context.read<RoleCubit>().repository;
      if (widget.role.isSystemAdmin) {
        // `role_management.system_admin_permissions`: the full list of the
        // global administrator, derived from the real permissions.
        final all = await repository.systemAdminPermissions();
        if (mounted) {
          setState(() {
            rows = all.documents;
            capabilities = all.capabilities;
          });
        }
      } else {
        final result = await repository.preview(widget.role.baseRoles);
        if (mounted) setState(() => rows = result);
      }
    } catch (e) {
      if (mounted) setState(() => error = failureMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final grouped = <String, Set<String>>{};
    for (final row in rows ?? const <RolePermissionRow>[]) {
      grouped.putIfAbsent(row.doctype, () => {}).addAll(row.actions);
    }
    final names = grouped.keys.toList()..sort();
    return Scaffold(
      appBar: AsoudHeader(
          title: persianRoleLabel(role.title.isEmpty ? role.code : role.title),
          subtitle: role.scope.isNotEmpty
              ? 'سطح دسترسی: ${role.scopeLabel}'
              : 'مجوزهای نقش'),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('تلاش دوباره')),
                ]))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (role.isGlobal)
                    const _RoleHint(
                        'این نقش در کل این استقرار اعمال می‌شود و همه مجوزهای زیر را دارد.'),
                  if (capabilities.isNotEmpty) ...[
                    const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 4),
                        child: Text('قابلیت‌های آسود',
                            style: TextStyle(fontWeight: FontWeight.w900))),
                    for (final cap in capabilities)
                      ListTile(
                        key: Key('capability_${cap.key}'),
                        dense: true,
                        leading: Icon(
                            cap.granted
                                ? Icons.check_circle_outline
                                : Icons.remove_circle_outline,
                            color: cap.granted
                                ? AsoudColors.success
                                : AsoudColors.muted),
                        title: Text(cap.title),
                        subtitle: Text(cap.module),
                      ),
                    const Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 4),
                        child: Text('مجوزهای اسناد',
                            style: TextStyle(fontWeight: FontWeight.w900))),
                  ],
                  if (names.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('مجوزی برای این نقش ثبت نشده است.',
                            textAlign: TextAlign.center)),
                  for (final name in names)
                    ListTile(
                      dense: true,
                      title: Text(persianDoctypeLabel(name)),
                      subtitle: Text(grouped[name]!
                          .map(_accessActionLabel)
                          .join('، ')),
                    ),
                ]),
    );
  }
}

/// Assigns or removes one role definition for one account, site-wide (global
/// roles) or per office (office-scoped roles), through
/// `role_access.assign_role` / `unassign_role`. Nobody changes their own
/// roles and a delegate cannot grant what they do not hold: the server's
/// Persian refusal is shown as sent.
class _RoleAssignment extends StatefulWidget {
  const _RoleAssignment(
      {required this.role, required this.user, required this.repository});
  final ManagedRole role;
  final Map<String, dynamic> user;
  final UserAccessRepository repository;
  @override
  State<_RoleAssignment> createState() => _RoleAssignmentState();
}

class _RoleAssignmentState extends State<_RoleAssignment> {
  List<OfficeRoleAssignment> assignments = const [];
  List<OfficeRef> offices = const [];
  String? office;
  bool busy = true;
  String? error, notice;

  String get userId => '${widget.user['name']}';
  bool get officeScoped => widget.role.scope == 'office';

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
    AccountRepository? accounts;
    try {
      accounts = context.read<AccountRepository>();
    } catch (_) {}
    try {
      final rows = await widget.repository.officeRoles(userId);
      var list = const <OfficeRef>[];
      try {
        if (accounts != null) list = (await accounts.loginState()).offices;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        assignments = rows;
        offices = list;
        office ??= list.isEmpty ? null : list.first.name;
      });
    } catch (e) {
      if (mounted) setState(() => error = failureDetail(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change({required bool assign, String? company}) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.repository.setAssignment(
          assign: assign,
          user: userId,
          role: widget.role.code,
          company: company);
      if (!mounted) return;
      setState(() => notice = assign
          ? (result.alreadyAssigned
              ? 'این نقش از قبل تخصیص داده شده بود.'
              : 'نقش تخصیص داده شد.')
          : 'تخصیص نقش حذف شد.');
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = failureDetail(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine =
        assignments.where((a) => a.role == widget.role.code).toList();
    return Scaffold(
      appBar: AsoudHeader(
          title: 'تخصیص نقش',
          subtitle:
              '${widget.user['full_name'] ?? userId} · ${persianRoleLabel(widget.role.title.isEmpty ? widget.role.code : widget.role.title)}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _RoleHint(officeScoped
            ? 'این نقش مخصوص دفتر است؛ یک کاربر می‌تواند در دفترهای مختلف نقش‌های متفاوت داشته باشد و نقش یک دفتر به دفتر دیگر نمی‌رسد.'
            : 'این نقش سراسری است و برای کل استقرار اعمال می‌شود.'),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(error!,
                  key: const Key('assignment_error'),
                  style: const TextStyle(color: AsoudColors.danger))),
        if (notice != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(notice!, key: const Key('assignment_notice'))),
        if (!officeScoped)
          Row(children: [
            Expanded(
                child: FilledButton(
                    key: const Key('assign_global'),
                    onPressed: busy ? null : () => change(assign: true),
                    child: const Text('تخصیص نقش'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    key: const Key('unassign_global'),
                    onPressed: busy ? null : () => change(assign: false),
                    child: const Text('حذف تخصیص'))),
          ])
        else ...[
          if (offices.isEmpty)
            const Text('دفتری برای تخصیص یافت نشد.')
          else
            DropdownButtonFormField<String>(
              key: const Key('assignment_office'),
              initialValue: office,
              decoration: const InputDecoration(labelText: 'دفتر کار'),
              items: [
                for (final o in offices)
                  DropdownMenuItem(value: o.name, child: Text(o.title))
              ],
              onChanged:
                  busy ? null : (value) => setState(() => office = value),
            ),
          const SizedBox(height: 8),
          FilledButton(
              key: const Key('assign_office'),
              onPressed: busy || office == null
                  ? null
                  : () => change(assign: true, company: office),
              child: const Text('تخصیص نقش در این دفتر')),
          const SizedBox(height: 16),
          const Text('تخصیص‌های فعلی این نقش',
              style: TextStyle(fontWeight: FontWeight.w900)),
          if (mine.isEmpty && !busy) const Text('تخصیصی ثبت نشده است.'),
          for (final a in mine)
            ListTile(
              key: Key('assignment_${a.company}'),
              dense: true,
              title: Text(a.company),
              subtitle: a.grantedBy.isEmpty ? null : Text('توسط ${a.grantedBy}'),
              trailing: IconButton(
                  tooltip: 'حذف تخصیص',
                  onPressed:
                      busy ? null : () => change(assign: false, company: a.company),
                  icon: const Icon(Icons.delete_outline)),
            ),
        ],
      ]),
    );
  }
}
