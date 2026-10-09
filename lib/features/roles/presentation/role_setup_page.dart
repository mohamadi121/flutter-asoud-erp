part of 'roles_page.dart';

class _RoleSetupView extends StatelessWidget {
  const _RoleSetupView();

  Widget _choice(BuildContext context, String title, IconData icon, Color color,
          Widget page, bool enabled) =>
      Card(
          child: InkWell(
              onTap: enabled ? () => _roleRoute<bool>(context, page) : null,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    AsoudIconBox(icon: icon, color: color),
                    const SizedBox(height: 12),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]))));

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RoleCubit, RoleState>(builder: (context, state) {
        final enabled = state.loaded && !state.saving && !state.loading;
        return Scaffold(
          appBar: const AsoudHeader(title: 'مدیریت نقش‌ها'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const _RoleStatus(),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const AsoudIconBox(
                          icon: Icons.account_tree_outlined,
                          color: AsoudColors.warning),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              '${toPersianDigits(state.catalog.categories.length)} دسته · ${toPersianDigits(state.catalog.roles.length)} نقش',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                    ]))),
            const SizedBox(height: 12),
            Card(
                child: ListTile(
                    enabled: enabled,
                    leading: const AsoudIconBox(
                        icon: Icons.auto_awesome_outlined,
                        color: AsoudColors.primary),
                    title: const Text('استفاده از قالب آماده'),
                    trailing: const Chip(label: Text('پیشنهادی')),
                    onTap: () =>
                        _roleRoute<bool>(context, const _RoleTemplates()))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _choice(
                      context,
                      'ایجاد دسته',
                      Icons.create_new_folder_outlined,
                      AsoudColors.success,
                      const _CategoryForm(),
                      enabled)),
              Expanded(
                  child: _choice(
                      context,
                      'ورود از اکسل',
                      Icons.upload_file_outlined,
                      AsoudColors.warning,
                      const _RoleExcelPage(),
                      enabled)),
            ]),
            _choice(
                context,
                'ایجاد نقش دستی',
                Icons.add,
                AsoudColors.primary,
                const _RoleForm(),
                enabled && state.catalog.categories.isNotEmpty),
          ]),
          bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: enabled
                      ? () => _roleRoute<void>(context, const _RolesView())
                      : null,
                  child: const Text('مشاهده و تکمیل نقش‌ها'))),
        );
      });
}
