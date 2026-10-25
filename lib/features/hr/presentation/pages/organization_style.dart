part of 'organization_page.dart';

class _OrgSheetTheme extends StatelessWidget {
  const _OrgSheetTheme({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: _orgCanvas,
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff73777c),
                  side: const BorderSide(color: Color(0xffd9d9df)),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 48))),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff191919),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 48)))),
      child: child);
}

class _OrgPanel extends StatelessWidget {
  const _OrgPanel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: _orgWhiteCard(),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

class _OrgDetailPage extends StatelessWidget {
  const _OrgDetailPage(
      {required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _orgCanvas,
      appBar: _OrganizationReferenceHeader(title: title, form: true),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
              padding: const EdgeInsets.all(20),
              decoration: _orgWhiteCard(),
              child: Row(children: [
                AsoudIconBox(
                    icon: Icons.inventory_2_outlined,
                    color: _orgAccents[0],
                    size: 52),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(context.read<OrganizationCubit>().company,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _orgInk)),
                      const SizedBox(height: 8),
                      const Text('مدیریت ساختار سازمانی',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xff858b96))),
                    ])),
              ])),
        const SizedBox(height: 16),
        Container(
              padding: const EdgeInsets.all(16),
              decoration: _orgWhiteCard(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children)),
        const SizedBox(height: 16),
        OutlinedButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('بازگشت به ساختار سازمانی')),
        const _OrgTabFooter(),
      ]));
}

class _OrgDetailIdentity extends StatelessWidget {
  const _OrgDetailIdentity(
      {required this.title, required this.subtitle, this.position = false});
  final String title, subtitle;
  final bool position;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(children: [
        AsoudIconBox(
            icon: position ? Icons.work_outline : Icons.business_outlined,
            color: _orgAccents[position ? 1 : 0],
            size: 54),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold, color: _orgInk)),
          const SizedBox(height: 10),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, height: 1.8, color: Color(0xff777d87))),
        ])),
      ]));
}

class _OrgDetailSection extends StatelessWidget {
  const _OrgDetailSection({required this.title, this.onAdd, this.addKey, this.icon, this.color});
  final IconData? icon;
  final Color? color;
  final String title;
  final VoidCallback? onAdd;
  final Key? addKey;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [
        if (icon != null) ...[
          AsoudIconBox(icon: icon!, color: color ?? _orgAccents[0], size: 30),
          const SizedBox(width: 8),
        ],
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold))),
        if (onAdd != null)
          OutlinedButton.icon(
              key: addKey,
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('افزودن')),
      ]));
}

class _OrgDetailRow extends StatelessWidget {
  const _OrgDetailRow(
      {required this.title, required this.onTap, this.position = false});
  final String title;
  final VoidCallback onTap;
  final bool position;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
          color: _orgTints[position ? 2 : 1],
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              leading: Icon(
                  position ? Icons.work_outline : Icons.business_outlined,
                  color: _orgAccents[position ? 2 : 1]),
              title: Text(title),
              trailing: const Icon(Icons.chevron_left, size: 20),
              onTap: onTap)));
}

class _OrgTabHeading extends StatelessWidget {
  const _OrgTabHeading(
      {required this.title,
      required this.action,
      required this.canManage,
      required this.onCreate});
  final String title, action;
  final bool canManage;
  final VoidCallback? onCreate;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _orgInk))),
        if (canManage) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff191919),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.add, size: 19),
              label: Text(action, style: const TextStyle(fontSize: 12))),
        ],
      ]);
}

class _OrgTabFooter extends StatelessWidget {
  const _OrgTabFooter();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.only(top: 14, bottom: 18),
      child: Column(children: [
        Divider(color: Color(0xffe6e6ed)),
        SizedBox(height: 18),
        Row(children: [
          Icon(Icons.info_outline, size: 15, color: Color(0xff858b96)),
          SizedBox(width: 8),
          Expanded(
              child: Text(
                  'اطلاعات واقعی سازمان؛ تغییرات پس از ثبت ذخیره می‌شوند.',
                  style: TextStyle(
                      fontSize: 10, height: 1.8, color: Color(0xff777d87))))
        ]),
      ]));
}

class _OrganizationUnitList extends StatefulWidget {
  const _OrganizationUnitList(
      {required this.units, required this.canManage, required this.onOpen});
  final List<Map<String, dynamic>> units;
  final bool canManage;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  State<_OrganizationUnitList> createState() => _OrganizationUnitListState();
}

class _OrganizationUnitListState extends State<_OrganizationUnitList> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final matches = widget.units
        .where((u) => '${u['department_name']}'.contains(query))
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _OrgTabHeading(
          title: 'واحدهای سازمانی',
          action: 'واحد جدید',
          canManage: widget.canManage,
          onCreate: () => _openOrganizationPage<bool>(
              context, const _OrganizationCreateForm(position: false))),
      const SizedBox(height: 16),
      TextField(
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: InputDecoration(
              hintText: 'جست‌وجو در واحدها...',
              hintStyle:
                  const TextStyle(fontSize: 12, color: Color(0xff8b8d96)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              filled: false,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: Color(0xffd7d8df))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: Color(0xffd7d8df))))),
      const SizedBox(height: 14),
      if (matches.isEmpty)
        Padding(
            padding: const EdgeInsets.all(20),
            child: Text(query.isEmpty
                ? 'هنوز واحدی تعریف نشده است.'
                : 'واحدی مطابق جست‌وجو یافت نشد.')),
      for (final unit in matches)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
                decoration: _orgWhiteCard(),
                child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => widget.onOpen(unit),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 22),
                            child: Row(children: [
                              AsoudIconBox(
                                  icon: Icons.business_outlined,
                                  color: _orgAccents[
                                      widget.units.indexOf(unit) %
                                          _orgAccents.length],
                                  size: 48),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('${unit['department_name']}',
                                        style: const TextStyle(
                                            fontSize: 16, color: _orgInk)),
                                    const SizedBox(height: 10),
                                    Text(
                                        'بالادستی: ${widget.units.where((u) => u['name'] == unit['parent_department']).map((u) => u['department_name']).firstOrNull ?? 'ریشه ساختار'}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xff777d87))),
                                    if (unit['disabled'] == 1)
                                      const Text('غیرفعال',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xff777d87))),
                                  ])),
                              const Icon(Icons.chevron_left,
                                  color: Color(0xffa0a4ad), size: 22),
                            ])))))),
      const _OrgTabFooter(),
    ]);
  }
}

class _OrganizationReferenceHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const _OrganizationReferenceHeader(
      {this.title = 'ساختار سازمانی', this.form = false, this.compact = false});
  final String title;
  final bool form;
  final bool compact;
  @override
  Size get preferredSize => Size.fromHeight(compact ? 66 : 94);
  @override
  Widget build(BuildContext context) => SafeArea(
      bottom: false,
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: compact ? 8 : 12),
          child: Row(children: [
            AsoudIconBox(
                icon: Icons.account_tree_outlined,
                color: Color(0xff3778b7),
                size: compact ? 36 : 50),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Flexible(
                      flex: 2,
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: compact ? 16 : 20,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: _orgInk))),
                  SizedBox(height: 6),
                  Flexible(
                      child: Text('مدیریت ساختار | آسود ERP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: Color(0xff777d87)))),
                ])),
            IconButton(
                tooltip: 'بازگشت',
                icon: Icon(
                    form
                        ? Icons.arrow_forward_rounded
                        : Icons.business_outlined,
                    color: Color(0xff9099a4),
                    size: 20),
                onPressed: () => Navigator.of(context).maybePop()),
          ])));
}

const _orgCanvas = Color(0xfff8f8fc);
const _orgInk = Color(0xff293956);
const _orgTints = [
  Color(0xffeaf2ff),
  Color(0xfff1eafb),
  Color(0xffe5f5ef),
  Color(0xfffff1e1),
  Color(0xffffece8)
];
const _orgAccents = [
  Color(0xff3679b5),
  Color(0xff8965af),
  Color(0xff348b76),
  Color(0xffb18443),
  Color(0xffba7063)
];

BoxDecoration _orgWhiteCard() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xffe5e5eb)));

class _OrganizationSummary extends StatefulWidget {
  const _OrganizationSummary();
  @override
  State<_OrganizationSummary> createState() => _OrganizationSummaryState();
}

class _OrganizationSummaryState extends State<_OrganizationSummary> {
  late Future<Map<String, dynamic>> data;
  void _reload() {
    final c = context.read<OrganizationCubit>();
    data = c.repository.units(c.company);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<OrganizationCubit, OrganizationState>(
          listenWhen: (before, after) =>
              before.busy && !after.busy && after.error == null,
          listener: (context, state) => setState(_reload),
          builder: (context, state) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(children: [
                Container(
                    decoration: _orgWhiteCard(),
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const AsoudIconBox(
                          icon: Icons.inventory_2_outlined,
                          color: Color(0xff3778b7),
                          size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(context.read<OrganizationCubit>().company,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: _orgInk)),
                            const SizedBox(height: 8),
                            Text(
                                state.snapshot.pending
                                    ? 'تغییرات در انتظار همگام‌سازی'
                                    : 'مدیریت واحدها و جایگاه‌های سازمانی',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xff727580))),
                          ])),
                      const SizedBox(width: 8),
                      Icon(
                          state.snapshot.pending || state.error != null
                              ? Icons.info_outline
                              : Icons.check_circle_outline,
                          size: 20,
                          color: state.snapshot.pending || state.error != null
                              ? AsoudColors.warning
                              : _orgAccents[2]),
                    ])),
                const SizedBox(height: 14),
                FutureBuilder<Map<String, dynamic>>(
                    future: data,
                    builder: (context, snap) => Row(children: [
                          Expanded(
                              child: _OrgStat(
                                  number: snap.hasData
                                      ? formatCount(
                                          (snap.data!['units'] as List).length,
                                          '')
                                      : '—',
                                  label: 'واحد سازمانی',
                                  icon: Icons.business_outlined,
                                  index: 0)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _OrgStat(
                                  number: formatCount(
                                      state.snapshot.rows.length, ''),
                                  label: 'جایگاه شغلی',
                                  icon: Icons.people_outline,
                                  index: 1)),
                        ])),
              ])));
}

class _OrgStat extends StatelessWidget {
  const _OrgStat(
      {required this.number,
      required this.label,
      required this.icon,
      required this.index});
  final String number, label;
  final IconData icon;
  final int index;
  @override
  Widget build(BuildContext context) => Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _orgTints[index], borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: _orgAccents[index], size: 24),
          Text(number.trim(),
              style: TextStyle(
                  color: _orgAccents[index],
                  fontSize: 23,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 24),
        Text(label,
            style: const TextStyle(color: Color(0xff666b79), fontSize: 12)),
      ]));
}
