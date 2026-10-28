part of 'organization_page.dart';

/// Compact creation views share the existing native unit API and chart save.
class _OrganizationCreateForm extends StatefulWidget {
  const _OrganizationCreateForm({super.key, required this.position, this.parent,
    this.embedded = false, this.onSaved, this.onCancel, this.onBusy});
  final bool position;
  final OrgPosition? parent;
  final bool embedded;
  final Future<void> Function(String?)? onSaved;
  final VoidCallback? onCancel;
  final ValueChanged<bool>? onBusy;
  @override
  State<_OrganizationCreateForm> createState() =>
      _OrganizationCreateFormState();
}

class _OrganizationCreateFormState extends State<_OrganizationCreateForm> {
  final title = TextEditingController();
  final capacity = TextEditingController(text: '1');
  final duties = TextEditingController();
  late String parentPosition = widget.parent?.code ?? '';
  final formKey = GlobalKey<FormState>();
  late final String code;
  List<Map<String, dynamic>> units = [];
  String selected = '';
  String? error;
  bool loading = true, saving = false, allowClose = false;
  bool ready = false;
  bool get dirty => title.text.isNotEmpty || selected.isNotEmpty ||
      capacity.text != '1' || duties.text.isNotEmpty || parentPosition.isNotEmpty;
  @override
  void initState() {
    super.initState();
    selected = widget.position ? widget.parent?.departmentId ?? '' : '';
    // Stable technical chart identifier, not a personnel/business code.
    final random = math.Random.secure();
    code =
        'POS-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    title.addListener(() {
      if (mounted) setState(() {});
    });
    load();
  }

  @override
  void dispose() {
    title.dispose();
    capacity.dispose();
    duties.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      ready = false;
      error = null;
    });
    try {
      final c = context.read<OrganizationCubit>();
      final result = await c.repository.units(c.company);
      if (!mounted) return;
      if (result['can_manage'] != true) {
        throw StateError('اجازه ایجاد ساختار سازمانی ندارید.');
      }
      setState(() => units = (result['units'] as List)
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList());
      ready = true;
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? failureMessage(e)
            : 'دریافت واحدها یا مجوز ایجاد ناموفق بود.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> close() async {
    if (saving) return;
    if (dirty && !await _confirmOrgDiscard(context)) return;
    if (!mounted) return;
    setState(() => allowClose = true);
    if (widget.embedded) { widget.onCancel?.call(); } else { Navigator.pop(context); }
  }

  Future<void> save() async {
    if (!ready ||
        saving ||
        loading ||
        !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    final c = context.read<OrganizationCubit>();
    if (c.state.busy) return;
    setState(() {
      saving = true;
      error = null;
    });
    widget.onBusy?.call(true);
    String? createdId;
    try {
      if (widget.position) {
        final unit = units.firstWhere((u) => u['name'] == selected);
        final row = OrgPosition(
            code: code,
            title: title.text.trim(),
            parent: parentPosition,
            departmentId: selected,
            department: '${unit['department_name']}',
            occupants: const [],
            capacity: int.tryParse(toLatinDigits(capacity.text.trim())) ?? 1,
            duties: duties.text.trim());
        // Replace only this form's technical identifier when retrying a retained draft.
        final rows = [
          ...c.state.snapshot.rows.where((r) => r.code != code),
          row
        ];
        validateOrganization(rows);
        if (!await c.save(rows)) {
          throw StateError(c.state.error ?? 'ذخیره تأیید نشد.');
        }
        if (!mounted) return;
        if (c.state.snapshot.pending) {
          _orgMessage(
              context, 'جایگاه روی دستگاه ذخیره شد و منتظر همگام‌سازی است.');
        }
      } else {
        final result = await c.repository.saveUnit(c.company,
            {'title': title.text.trim(), 'parent': selected, 'is_group': true,
              'description': duties.text.trim()});
        createdId = result['name']?.toString();
        await c.load();
      }
      if (mounted) {
        if (widget.embedded) { await widget.onSaved?.call(createdId); }
        else { Navigator.pop(context, true); }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? failureMessage(e)
            : e is StateError
                ? e.message
                : 'ذخیره تأیید نشد؛ دوباره بررسی کنید.');
      }
    } finally {
      widget.onBusy?.call(false);
      if (mounted) setState(() => saving = false);
    }
  }

  InputDecoration decoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: Color(0xffdcdce1))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: Color(0xffdcdce1))));

  @override
  Widget build(BuildContext context) => widget.embedded ? _content() : PopScope(
      canPop: !saving && (allowClose || !dirty),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) close();
      },
      child: Scaffold(
          backgroundColor: _orgCanvas,
          appBar: _OrganizationReferenceHeader(
              form: true,
              title:
                  widget.position ? 'ایجاد جایگاه شغلی' : 'ایجاد واحد سازمانی'),
          body: _content()));

  Widget _content() => SafeArea(
              child: ListView(shrinkWrap: widget.embedded,
                  physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
                  padding: const EdgeInsets.all(20), children: [
            Container(
                decoration: _orgWhiteCard(),
                padding: const EdgeInsets.all(18),
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
                        const Text('مدیریت واحدها و جایگاه‌های سازمانی',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xff777d87))),
                      ])),
                  const Icon(Icons.check_circle_outline,
                      size: 20, color: Color(0xff348b76)),
                ])),
            const SizedBox(height: 20),
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24)),
                child: Form(
                    key: formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            AsoudIconBox(
                                icon: widget.position
                                    ? Icons.work_outline
                                    : Icons.business_outlined,
                                color: widget.position
                                    ? _orgAccents[1]
                                    : _orgAccents[0],
                                size: 50),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      widget.position
                                          ? 'افزودن جایگاه شغلی'
                                          : 'تعریف واحد سازمانی جدید',
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  Text(
                                      widget.position
                                          ? 'تعریف جایگاه در ساختار سازمان'
                                          : 'مشخصات ساختار سازمانی',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xff777d87))),
                                ])),
                          ]),
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xffefeff3)),
                          const SizedBox(height: 24),
                          if (loading) const LinearProgressIndicator(),
                          if (error != null) ...[
                            Text(error!,
                                style:
                                    const TextStyle(color: AsoudColors.danger)),
                            TextButton(
                                onPressed: saving || loading ? null : load,
                                child: const Text('بازخوانی واحدها')),
                          ],
                          Text(widget.position
                              ? 'عنوان جایگاه *'
                              : 'عنوان واحد سازمانی *'),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: title,
                              enabled: !saving,
                              decoration: decoration(widget.position
                                  ? 'مثلاً کارشناس فروش'
                                  : 'مثلاً مدیریت فروش'),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'عنوان را وارد کنید.'
                                      : null),
                          const SizedBox(height: 24),
                          Text(widget.position
                              ? 'واحد سازمانی مربوطه *'
                              : 'واحد بالادستی *'),
                          const SizedBox(height: 14),
                          FormField<String>(
                              initialValue: selected,
                              validator: (_) =>
                                  widget.position && selected.isEmpty
                                      ? 'واحد سازمانی را انتخاب کنید.'
                                      : null,
                              builder: (field) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        OutlinedButton(
                                            onPressed: saving || loading
                                                ? null
                                                : () async {
                                                    final value =
                                                        await showAppOptionSheet(
                                                            context,
                                                            title: widget
                                                                    .position
                                                                ? 'واحد سازمانی مربوطه'
                                                                : 'واحد بالادستی',
                                                            current: selected,
                                                            options: [
                                                          if (!widget.position)
                                                            const AppOption('',
                                                                'ریشه ساختار / بدون واحد بالادستی'),
                                                          ...units
                                                              .where((u) =>
                                                                  u['disabled'] !=
                                                                      1 &&
                                                                  (widget.position ||
                                                                      u['is_group'] ==
                                                                          1))
                                                              .map((u) => AppOption(
                                                                  '${u['name']}',
                                                                  organizationUnitLabel(u))),
                                                        ]);
                                                    if (value == null ||
                                                        !mounted) {
                                                      return;
                                                    }
                                                    setState(
                                                        () => selected = value);
                                                    field.didChange(value);
                                                  },
                                            style: OutlinedButton.styleFrom(
                                                shape: const StadiumBorder(),
                                                side: const BorderSide(
                                                    color: Color(0xffdcdce1)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14)),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      units
                                                              .where((u) =>
                                                                  u['name'] ==
                                                                  selected)
                                                              .map((u) =>
                                                                  organizationUnitLabel(u))
                                                              .firstOrNull ??
                                                          (widget.position
                                                              ? 'انتخاب واحد سازمانی'
                                                              : 'ریشه ساختار / بدون واحد بالادستی'),
                                                      style: const TextStyle(
                                                          color: _orgInk))),
                                              const Icon(Icons.expand_more,
                                                  color: Color(0xff777d87))
                                            ])),
                                        if (field.hasError)
                                          Text(field.errorText!,
                                              style: const TextStyle(
                                                  color: AsoudColors.danger)),
                                      ])),
                          const SizedBox(height: 16),
                          Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: widget.position
                                      ? _orgTints[1]
                                      : _orgTints[0],
                                  borderRadius: BorderRadius.circular(18)),
                              child: Text(
                                  widget.position
                                      ? 'ایجاد جایگاه به‌معنی انتساب کارمند یا اعطای دسترسی به او نیست.'
                                      : 'هر واحد زیرمجموعه یک واحد بالادستی یا مستقیماً زیر ریشه ساختار است. مدیر مستقیم پرسنل تغییر نمی‌کند.',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.9,
                                      color: Color(0xff677080)))),
                          if (widget.embedded && !widget.position) ...[
                            const SizedBox(height: 14),
                            AppTextField(controller: duties, label: 'توضیحات واحد',
                              hint: 'توضیحات را وارد کنید', minLines: 3, maxLines: 5, enabled: !saving,
                              validator: (v) => (v ?? '').runes.length > 2000 ? 'توضیحات واحد حداکثر ۲۰۰۰ نویسه است.' : null),
                          ],
                          if (widget.embedded && widget.position) ...[
                            const SizedBox(height: 14),
                            AppSelectField(label: 'جایگاه بالادستی', value: parentPosition,
                              displayValue: context.read<OrganizationCubit>().state.snapshot.rows
                                  .where((r) => r.code == parentPosition).firstOrNull?.displayTitle ?? 'بدون جایگاه بالادستی',
                              enabled: !saving,
                              onPick: () => showAppOptionSheet(context, title: 'جایگاه بالادستی',
                                current: parentPosition, options: [const AppOption('', 'بدون جایگاه بالادستی'),
                                  ...context.read<OrganizationCubit>().state.snapshot.rows.map((r) => AppOption(r.code, r.displayTitle))]),
                              onChanged: (v) => setState(() => parentPosition = v)),
                            const SizedBox(height: 14),
                            AppTextField(controller: capacity, label: 'ظرفیت جایگاه', required: true,
                              keyboardType: TextInputType.number, enabled: !saving,
                              validator: (v) => (int.tryParse(toLatinDigits(v ?? '')) ?? 0) < 1 ? 'ظرفیت باید عدد صحیح مثبت باشد.' : null),
                            const SizedBox(height: 14),
                            AppTextField(controller: duties, label: 'شرح وظایف', maxLines: 3, enabled: !saving),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                              key: const ValueKey(
                                  'organization-compact-create-submit'),
                              onPressed:
                                  !ready || loading || saving ? null : save,
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff191919),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  minimumSize: const Size(0, 48)),
                              icon: const Icon(Icons.check),
                              label: Text(saving
                                  ? 'در حال ثبت…'
                                  : widget.position
                                      ? 'افزودن جایگاه'
                                      : 'افزودن واحد')),
                          const SizedBox(height: 12),
                          OutlinedButton(
                              onPressed: saving ? null : close,
                              style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  foregroundColor: const Color(0xff777d87),
                                  side: const BorderSide(
                                      color: Color(0xffdcdce1)),
                                  minimumSize: const Size(0, 48)),
                              child: const Text('انصراف')),
                        ]))),
          ]));
}
