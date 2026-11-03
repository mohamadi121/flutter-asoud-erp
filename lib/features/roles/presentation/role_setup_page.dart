part of 'roles_page.dart';

class _RoleSetupView extends StatelessWidget {
  const _RoleSetupView({this.canManage = true});

  /// Read-only roles (HR Manager) keep the catalog but no write entry point.
  final bool canManage;

  Widget _choice(BuildContext context, String title, String subtitle,
          IconData icon, Widget page, bool enabled) =>
      Card(
          child: InkWell(
              onTap: enabled ? () => _roleRoute<bool>(context, page) : null,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 180),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                    AsoudIconBox(icon: icon, color: AsoudColors.primary, size: 52),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                        constraints: BoxConstraints(minHeight: MediaQuery.textScalerOf(context).scale(15) * 2.8),
                        child: Center(child: Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w800)))),
                    const SizedBox(height: 20),
                    Text(subtitle, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, height: 1.6, color: AsoudColors.muted)),
                  ])))));

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RoleCubit, RoleState>(builder: (context, state) {
        final enabled = state.loaded && !state.saving && !state.loading;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: const AsoudHeader(title: 'مدیریت نقش‌ها'),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const _RoleStatus(),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const AsoudIconBox(
                          icon: Icons.account_tree_outlined,
                          color: AsoudColors.warning, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(
                              '${toPersianDigits(state.catalog.categories.length)} دسته · ${toPersianDigits(state.catalog.roles.length)} نقش',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            const Text('قالب‌های پیشنهادی آسود',
                                style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
                          ])),
                    ]))),
            const SizedBox(height: 12),
            if (canManage)
              Card(
                  child: ListTile(
                      enabled: enabled,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      leading: const AsoudIconBox(
                          icon: Icons.auto_awesome_outlined,
                          color: AsoudColors.primary, size: 52),
                      title: const Text('استفاده از قالب آماده',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      subtitle: const Padding(padding: EdgeInsets.only(top: 10),
                          child: Text('انتخاب نقش‌های پیشنهادی',
                              style: TextStyle(fontSize: 12, color: AsoudColors.muted))),
                      trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xffe4f3fc),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('پیشنهادی',
                              style: TextStyle(fontSize: 10, color: Color(0xff347bac)))),
                      onTap: !enabled ? null : () =>
                          _roleRoute<bool>(context, const _RoleTemplates()))),
            if (canManage) const SizedBox(height: 12),
            if (canManage)
              IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                    child: _choice(
                        context,
                        'ایجاد نقش جدید',
                        'تعریف دستی نقش',
                        Icons.add,
                        const _RoleForm(),
                        enabled && state.catalog.categories.isNotEmpty)),
                const SizedBox(width: 12),
                Expanded(
                    child: _choice(
                        context,
                        'ورود از اکسل',
                        'انتقال نقش‌های موجود',
                        Icons.table_chart_outlined,
                        const _RoleExcelPage(),
                        enabled)),
              ])),
          ]),
          bottomNavigationBar: Container(
              decoration: const BoxDecoration(color: Colors.white,
                  border: Border(top: BorderSide(color: AsoudColors.border))),
              child: SafeArea(top: false,
              minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff191919),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder()),
                  onPressed: enabled
                      ? () => _roleRoute<void>(
                          context, _RolesView(canManage: canManage))
                      : null,
                  child: const Text('مشاهده و تکمیل نقش‌ها')))),
        );
      });
}
