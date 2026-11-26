part of 'office_users_page.dart';

class _RepresentationReason extends StatefulWidget {
  const _RepresentationReason({required this.name});
  final String name;
  @override
  State<_RepresentationReason> createState() => _RepresentationReasonState();
}

class _RepresentationReasonState extends State<_RepresentationReason> {
  final form = GlobalKey<FormState>();
  String reason = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ورود به نمایندگی از پرسنل'),
    content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('عملیات به نمایندگی از «${widget.name}» واقعی است و نام مدیر در گزارش حسابرسی ثبت می‌شود.'),
      const SizedBox(height: 12),
      TextFormField(
        maxLength: 300, decoration: const InputDecoration(labelText: 'دلیل نمایندگی'),
        onChanged: (value) => reason = value.trim(),
        validator: (_) => reason.length < 5 ? 'دلیل نمایندگی را وارد کنید.' : null,
      ),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        if (form.currentState!.validate()) Navigator.pop(context, reason);
      }, child: const Text('ورود و اقدام به نمایندگی')),
    ],
  );
}

Color _officeStatusColor(String status) => switch (status) {
      'no_account' => AsoudColors.warning,
      'pending' => AsoudColors.primary,
      'disabled' => AsoudColors.muted,
      _ => AsoudColors.success,
    };

class _OfficeAccessHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const _OfficeAccessHeader({required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AsoudColors.border)),
              ),
              child: Row(children: [
                const AsoudIconBox(
                    icon: Icons.manage_accounts_outlined,
                    color: AsoudColors.primary),
                const SizedBox(width: 9),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AsoudColors.muted)),
                    ])),
                if (Navigator.of(context).canPop())
                  IconButton.outlined(
                      onPressed: () => Navigator.maybePop(context),
                      tooltip: 'بازگشت',
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18)),
              ]),
            )),
      );
}

class _OfficePanel extends StatelessWidget {
  const _OfficePanel(
      {required this.child, this.borderColor = AsoudColors.border});
  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor)),
        child: Padding(padding: const EdgeInsets.all(10), child: child),
      );
}

class _OfficePersonHeading extends StatelessWidget {
  const _OfficePersonHeading(
      {required this.name,
      required this.designation,
      required this.department,
      required this.code,
      required this.status,
      required this.color});
  final String name, designation, department, code, status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final metadata = [designation, department]
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join();
    return Row(children: [
      Container(
        width: 37,
        height: 37,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10)),
        child: letters.isEmpty
            ? Icon(Icons.person_outline, color: color, size: 19)
            : Text(letters,
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 8),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        if (metadata.isNotEmpty)
          Text(metadata,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AsoudColors.muted, fontSize: 11)),
        if (code.isNotEmpty)
          Text('کد پرسنلی: $code',
              style: const TextStyle(color: AsoudColors.muted, fontSize: 10)),
      ])),
      if (status.isNotEmpty) ...[
        const SizedBox(width: 5),
        Container(
          constraints: const BoxConstraints(maxWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(5)),
          child: Text(status,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    ]);
  }
}

class _OfficePeopleFilters extends StatefulWidget {
  const _OfficePeopleFilters(
      {required this.initial,
      required this.units,
      required this.statuses,
      required this.loadProfiles,
      required this.profileAvailable});
  final (String, String, String) initial;
  final Map<String, String> units, statuses;
  final Future<List<AccessMap>> Function() loadProfiles;
  final bool profileAvailable;

  @override
  State<_OfficePeopleFilters> createState() => _OfficePeopleFiltersState();
}

class _OfficePeopleFiltersState extends State<_OfficePeopleFilters> {
  late String unit = widget.initial.$1,
      status = widget.initial.$2,
      profile = widget.initial.$3;
  late final Future<List<AccessMap>> profiles = widget.loadProfiles();
  int resetCount = 0;

  Widget field(String title, String value, Map<String, String> options,
          ValueChanged<String> change,
          {bool enabled = true}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                key: ValueKey('$title:$resetCount'),
                initialValue: options.containsKey(value) ? value : '',
                isExpanded: true,
                decoration: const InputDecoration(
                    isDense: true, filled: true, fillColor: Colors.white),
                items: [
                  for (final item in options.entries)
                    DropdownMenuItem(
                        value: item.key,
                        child:
                            Text(item.value, overflow: TextOverflow.ellipsis))
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) change(value);
                      }
                    : null,
              ),
            ],
          ));

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('فیلتر پرسنل',
                              style: TextStyle(fontWeight: FontWeight.w800))),
                      OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('بستن')),
                    ]),
                    const SizedBox(height: 10),
                    field('واحد سازمانی', unit, widget.units, (v) => unit = v),
                    field('وضعیت حساب', status, widget.statuses,
                        (v) => status = v),
                    FutureBuilder<List<AccessMap>>(
                      future: widget.profileAvailable ? profiles : null,
                      builder: (context, snapshot) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            field(
                                'پروفایل دسترسی',
                                profile,
                                {
                                  '': 'همه پروفایل‌ها',
                                  for (final row
                                      in snapshot.data ?? const <AccessMap>[])
                                    '${row['name']}': '${row['title']}',
                                },
                                (v) => profile = v,
                                enabled: snapshot.hasData),
                            if (snapshot.hasError || !widget.profileAvailable)
                              const Text(
                                  'فهرست پروفایل‌ها برای فیلتر در دسترس نیست.',
                                  style: TextStyle(
                                      color: AsoudColors.muted, fontSize: 11)),
                          ]),
                    ),
                    Row(children: [
                      OutlinedButton(
                          onPressed: () => setState(() {
                                unit = status = profile = '';
                                resetCount++;
                              }),
                          child: const Text('پاک‌کردن فیلتر')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, (unit, status, profile)),
                        child: const Text('اعمال فیلتر'),
                      )),
                    ]),
                  ]),
            )),
      );
}
