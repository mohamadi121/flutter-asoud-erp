part of 'roles_page.dart';

class _RoleForm extends StatefulWidget {
  const _RoleForm({this.role, this.category, this.parent});
  final ManagedRole? role;
  final String? category;
  final String? parent;
  @override
  State<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends State<_RoleForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _code, _description;
  late String _category, _parent;
  late bool _enabled;
  ManagedRole? _baseline;
  @override
  void initState() {
    super.initState();
    _baseline = widget.role;
    _title = TextEditingController(text: widget.role?.title ?? '');
    _code = TextEditingController(text: widget.role?.code ?? '');
    _description = TextEditingController(text: widget.role?.description ?? '');
    _category = widget.role?.category ?? widget.category ?? '';
    _parent = widget.role?.parent ?? widget.parent ?? '';
    _enabled = widget.role?.enabled ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Set<String> _descendants(List<ManagedRole> roles) {
    final blocked = <String>{if (widget.role != null) widget.role!.code};
    var changed = true;
    while (changed) {
      changed = false;
      for (final role in roles) {
        if (blocked.contains(role.parent) && blocked.add(role.code)) {
          changed = true;
        }
      }
    }
    return blocked;
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RoleCubit, RoleState>(builder: (context, state) {
        final busy = state.saving || state.loading;
        final stale = _stale(state);
        return Scaffold(
          appBar: AsoudHeader(
              title: widget.role == null ? 'ایجاد نقش' : 'ویرایش نقش'),
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            const _RoleStatus(),
            if (_baseline != null) ...[
              if (stale)
                const _RoleHint(
                    'نسخه نقش تغییر کرده است. ابتدا اطلاعات جدید را بررسی کنید؛ تغییرات واردشده فعلاً در فرم حفظ می‌شود.'),
              TextButton.icon(
                  onPressed: busy ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('بازخوانی و بررسی نسخه نقش')),
            ],
            _basic(state, busy),
            const SizedBox(height: 12),
            _RoleHint(widget.role == null
                ? 'نقش دستی فقط با اطلاعات پایه ثبت می‌شود و دسترسی جدیدی به کاربر نمی‌دهد. برای نقش دارای دسترسی استاندارد از الگوهای موجود استفاده کنید.'
                : 'ویرایش اطلاعات پایه، دسترسی‌های قبلی این نقش را تغییر نمی‌دهد.'),
          ])),
          bottomNavigationBar: AsoudBottomActions(
            primaryLabel: state.saving
                ? 'در حال ذخیره…'
                : widget.role == null
                    ? 'ایجاد نقش'
                    : 'ذخیره تغییرات',
            onPrimary: busy || !state.loaded || stale ? null : _save,
            secondaryLabel: 'انصراف',
            onSecondary: busy ? null : () => Navigator.pop(context),
          ),
        );
      });

  Widget _basic(RoleState state, bool busy) {
    final blocked = _descendants(state.catalog.roles);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اطلاعات پایه',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _title,
                        maxLength: 140,
                        enabled: !busy,
                        decoration: const InputDecoration(
                            labelText: 'نام نقش *', hintText: 'مثال: حسابدار'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'نام نقش الزامی است.'
                                : null),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        key: ValueKey('category-$_category'),
                        initialValue: state.catalog.categories
                                .any((e) => e.code == _category)
                            ? _category
                            : null,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'دسته نقش *'),
                        items: state.catalog.categories
                            .map((category) => DropdownMenuItem(
                                value: category.code,
                                child: Row(children: [
                                  Icon(_roleStyle(category.style).$1,
                                      size: 20,
                                      color: _roleStyle(category.style).$2),
                                  const SizedBox(width: 8),
                                  Flexible(
                                      child: Text(category.title,
                                          overflow: TextOverflow.ellipsis))
                                ])))
                            .toList(),
                        onChanged: busy
                            ? null
                            : (value) =>
                                setState(() => _category = value ?? ''),
                        validator: (value) => value == null || value.isEmpty
                            ? 'دسته را انتخاب کنید.'
                            : null),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        key: ValueKey('parent-$_parent'),
                        initialValue: _parent,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'نقش والد',
                            helperText: 'فقط دسته‌بندی؛ بدون ارث‌بری دسترسی'),
                        validator: (value) => value != null &&
                                value.isNotEmpty &&
                                (!state.catalog.roles
                                        .any((role) => role.code == value) ||
                                    blocked.contains(value))
                            ? 'والد معتبر را دوباره انتخاب کنید.'
                            : null,
                        items: [
                          if (_parent.isNotEmpty &&
                              !state.catalog.roles.any((role) =>
                                  role.code == _parent &&
                                  !blocked.contains(role.code)))
                            DropdownMenuItem(
                                value: _parent,
                                child: Text('والد نامعتبر: $_parent')),
                          const DropdownMenuItem(
                              value: '', child: Text('بدون والد')),
                          ...state.catalog.roles
                              .where((role) => !blocked.contains(role.code))
                              .map((role) => DropdownMenuItem(
                                  value: role.code,
                                  child: Text(role.title,
                                      overflow: TextOverflow.ellipsis)))
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() => _parent = value ?? '')),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _code,
                        enabled: !busy && widget.role == null,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                            labelText: 'کد نقش *', hintText: 'ACCOUNTANT'),
                        validator: (value) {
                          final code = value?.trim().toUpperCase() ?? '';
                          if (!RegExp(r'^[A-Z][A-Z0-9_-]{1,39}$')
                              .hasMatch(code)) {
                            return 'کد انگلیسی ۲ تا ۴۰ نویسه، با حرف شروع شود.';
                          }
                          if (state.catalog.roles.any((role) =>
                              role.code == code &&
                              role.code != widget.role?.code)) {
                            return 'کد نقش تکراری است.';
                          }
                          return null;
                        }),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _description,
                        enabled: !busy,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                            labelText: 'توضیحات',
                            hintText: 'توضیحی درباره این نقش…')),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('فعال برای تخصیص'),
                        value: _enabled,
                        subtitle: _baseline?.assignedUsers != null &&
                                _baseline!.assignedUsers > 0
                            ? Text(
                                '${formatCount(_baseline!.assignedUsers, 'کاربر')} متصل؛ غیرفعال‌سازی نیازمند تغییر تخصیص است.')
                            : null,
                        onChanged: busy || (_baseline?.assignedUsers ?? 0) > 0
                            ? null
                            : (value) => setState(() => _enabled = value)),
                  ]),
            )));
  }

  bool _stale(RoleState state) {
    if (_baseline == null || !state.loaded) return false;
    final matches =
        state.catalog.roles.where((role) => role.code == _baseline!.code);
    return matches.isEmpty ||
        matches.first.modified != _baseline!.modified ||
        matches.first.profileModified != _baseline!.profileModified;
  }

  Future<void> _reload() async {
    final cubit = context.read<RoleCubit>();
    await cubit.load();
    if (!mounted || !cubit.state.loaded) return;
    final matches =
        cubit.state.catalog.roles.where((role) => role.code == _baseline!.code);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('این نقش دیگر در فهرست سرور وجود ندارد.')));
      return;
    }
    final latest = matches.first;
    final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('بازخوانی اطلاعات نقش'),
              content: SingleChildScrollView(
                  child: Text(
                      'فرم شما:\n${_title.text}\nدسته: $_category — والد: $_parent\n${_description.text}\nفعال: $_enabled\n\n'
                      'نسخه سرور:\n${latest.title}\nدسته: ${latest.category} — والد: ${latest.parent}\n${latest.description}\nفعال: ${latest.enabled}\n\n'
                      'با تأیید، مقادیر سرور جایگزین ورودی فعلی فرم می‌شوند. با انصراف، ورودی شما دست‌نخورده می‌ماند.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('حفظ ورودی فعلی')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('بارگذاری نسخه سرور')),
              ],
            ));
    if (replace != true || !mounted) return;
    setState(() {
      _baseline = latest;
      _title.text = latest.title;
      _code.text = latest.code;
      _description.text = latest.description;
      _category = latest.category;
      _parent = latest.parent;
      _enabled = latest.enabled;
    });
  }

  Future<void> _save() async {
    if (_stale(context.read<RoleCubit>().state)) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    final saved = await context.read<RoleCubit>().save(ManagedRole(
          code: _code.text.trim().toUpperCase(),
          title: _title.text.trim(),
          category: _category,
          parent: _parent,
          description: _description.text.trim(),
          enabled: _enabled,
          baseRoles: _baseline?.baseRoles ?? const [],
          modified: _baseline?.modified,
          profileModified: _baseline?.profileModified,
          assignedUsers: _baseline?.assignedUsers ?? 0,
        ));
    if (saved && mounted) Navigator.pop(context, true);
  }
}
