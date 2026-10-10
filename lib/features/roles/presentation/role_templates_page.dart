part of 'roles_page.dart';

typedef RoleCategoryFormView = _CategoryForm;

class _CategoryForm extends StatefulWidget {
  const _CategoryForm();
  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _code = TextEditingController();
  String _style = 'system';
  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<RoleCubit, RoleState>(
      builder: (context, state) => Scaffold(
            appBar: const AsoudHeader(
                title: 'ایجاد دسته نقش',
                subtitle: 'گروه‌بندی نقش‌ها با آیکن رنگی'),
            body: Form(
                key: _key,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  const _RoleStatus(),
                  AppTextField(
                      controller: _title,
                      label: 'نام دسته',
                      required: true,
                      hint: 'نام دسته را وارد کنید',
                      maxLength: 140,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'نام دسته الزامی است.'
                              : null),
                  const SizedBox(height: 16),
                  AppTextField(
                      controller: _code,
                      label: 'کد دسته',
                      required: true,
                      hint: 'FINANCE',
                      ltr: true,
                      validator: (value) =>
                          RegExp(r'^[A-Za-z][A-Za-z0-9_-]{1,39}$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'کد انگلیسی ۲ تا ۴۰ نویسه، با حرف شروع شود.'),
                  const SizedBox(height: 20),
                  const Text('سبک نمایش',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final category in state.catalog.templateCategories)
                      ChoiceChip(
                          label: Text(category.title),
                          selected: _style == category.style,
                          avatar: Icon(_roleStyle(category.style).$1,
                              size: 18, color: _roleStyle(category.style).$2),
                          onSelected: state.saving
                              ? null
                              : (_) => setState(() => _style = category.style)),
                  ]),
                ])),
            bottomNavigationBar: AsoudBottomActions(
                primaryLabel: state.saving ? 'در حال ذخیره…' : 'ایجاد دسته',
                onPrimary: !state.loaded || state.saving || state.loading
                    ? null
                    : () async {
                        if (!(_key.currentState?.validate() ?? false)) return;
                        final saved = await context
                            .read<RoleCubit>()
                            .createCategory(_code.text.trim().toUpperCase(),
                                _title.text.trim(), _style);
                        if (saved && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                secondaryLabel: 'انصراف',
                onSecondary:
                    state.saving ? null : () => Navigator.pop(context)),
          ));
}

class _RoleTemplates extends StatefulWidget {
  const _RoleTemplates();
  @override
  State<_RoleTemplates> createState() => _RoleTemplatesState();
}

class _RoleTemplatesState extends State<_RoleTemplates> {
  final Set<String> _selected = {};
  @override
  Widget build(BuildContext context) => BlocBuilder<RoleCubit, RoleState>(
      builder: (context, state) => Scaffold(
            appBar: const AsoudHeader(
                title: 'الگوهای استاندارد نقش',
                subtitle: 'انتخاب، بررسی و ایجاد؛ بدون تخصیص به کاربران'),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              const _RoleStatus(),
              const _RoleHint(
                  'این الگوها از نقش‌های واقعی نصب‌شده ERPNext/HRMS استفاده می‌کنند. نقش‌های موجود بازنویسی نمی‌شوند. نقش مدیر سیستم دسترسی بسیار گسترده دارد.'),
              const SizedBox(height: 14),
              if (state.catalog.templates.isEmpty)
                const _RoleHint('الگوی نقش هنوز از سرور دریافت نشده است. در حالت آفلاین می‌توانید دسته و نقش دستی بسازید؛ فهرست الگوها بعد از اتصال قابل دریافت است.'),
              for (final category in state.catalog.templateCategories)
                if (state.catalog.templates
                    .any((template) => template.category == category.code)) ...[
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(category.title,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  for (final template in state.catalog.templates
                      .where((template) => template.category == category.code))
                    Card(
                        child: CheckboxListTile(
                      secondary: AsoudIconBox(
                          icon: _roleStyle(category.style).$1,
                          color: _roleStyle(category.style).$2),
                      title: Text(template.title),
                      subtitle: Text(
                          template.exists
                              ? 'قبلاً ایجاد شده'
                              : !template.available
                                  ? 'نقش پایه در سرور موجود یا فعال نیست'
                                  : template.baseRoles.map(persianRoleLabel).join(' + '),
                          style: const TextStyle(fontSize: 11)),
                      value: _selected.contains(template.code),
                      onChanged:
                          !template.available || template.exists || state.saving
                              ? null
                              : (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(template.code);
                                    } else {
                                      _selected.remove(template.code);
                                    }
                                  }),
                    )),
                ],
            ]),
            bottomNavigationBar: AsoudBottomActions(
                primaryLabel:
                    state.saving ? 'در حال ایجاد…' : 'ایجاد نقش‌های انتخاب‌شده',
                onPrimary: _selected.isEmpty ||
                        state.saving ||
                        state.loading ||
                        !state.loaded
                    ? null
                    : () async {
                        final chosen = state.catalog.templates
                            .where(
                                (template) => _selected.contains(template.code))
                            .toList();
                        final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                                  title: const Text('تأیید ایجاد نقش‌ها'),
                                  content: SingleChildScrollView(
                                      child: Text(
                                          '${chosen.map((role) => role.title).join('، ')}\n\nهیچ کاربری به این نقش‌ها متصل نمی‌شود. تخصیص و محدودیت دفتر باید جداگانه تنظیم شوند.')),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('انصراف')),
                                    FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('تأیید و ایجاد'))
                                  ],
                                ));
                        if (yes != true || !context.mounted) return;
                        final saved = await context
                            .read<RoleCubit>()
                            .applyTemplates(_selected.toList());
                        if (saved && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                secondaryLabel: 'انصراف',
                onSecondary:
                    state.saving ? null : () => Navigator.pop(context)),
          ));
}
