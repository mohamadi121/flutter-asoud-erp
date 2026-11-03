part of 'roles_page.dart';

class _RoleSetupView extends StatelessWidget {
  const _RoleSetupView({this.canManage = true});

  /// Read-only roles (HR Manager) keep the catalog but no write entry point.
  final bool canManage;

  Widget _choice(BuildContext context, String title, String subtitle,
          IconData icon, Widget page, bool enabled,
          {required double titleHeight, required TextStyle titleStyle,
          required EdgeInsetsGeometry margin}) =>
      Card(
          margin: margin,
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
                    SizedBox(height: titleHeight, width: double.infinity,
                        child: Center(child: Text(title,
                        textAlign: TextAlign.center,
                        style: titleStyle))),
                    const SizedBox(height: 20),
                    Text(subtitle, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, height: 1.6, color: AsoudColors.muted)),
                  ])))));

  Widget _choices(BuildContext context, bool enabled, bool hasCategories) =>
      LayoutBuilder(builder: (context, constraints) {
        const titles = ['ایجاد نقش جدید', 'ورود از اکسل'];
        final margin = CardTheme.of(context).margin ?? const EdgeInsets.all(4);
        final direction = Directionality.of(context);
        final titleStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 15, height: 1.4, fontWeight: FontWeight.w800);
        final textWidth = ((constraints.maxWidth - 12) / 2 -
            margin.resolve(direction).horizontal - 24).clamp(1.0, double.infinity).toDouble();
        // Reserve the actual tallest title, not an assumed number of lines.
        // The default test font can wrap into three lines at 320 px.
        final titleHeight = titles.fold<double>(0, (height, title) {
          final painter = TextPainter(text: TextSpan(text: title, style: titleStyle),
              textDirection: direction, textAlign: TextAlign.center,
              textScaler: MediaQuery.textScalerOf(context),
              locale: Localizations.maybeLocaleOf(context))..layout(maxWidth: textWidth);
          final measured = painter.height.ceilToDouble();
          painter.dispose();
          return measured > height ? measured : height;
        });
        return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _choice(context, titles[0], 'تعریف دستی نقش', Icons.add,
              const _RoleForm(), enabled && hasCategories,
              titleHeight: titleHeight, titleStyle: titleStyle, margin: margin)),
          const SizedBox(width: 12),
          Expanded(child: _choice(context, titles[1], 'انتقال نقش‌های موجود', Icons.table_chart_outlined,
              const _RoleExcelPage(), enabled,
              titleHeight: titleHeight, titleStyle: titleStyle, margin: margin)),
        ]));
      });

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
              _choices(context, enabled, state.catalog.categories.isNotEmpty),
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
