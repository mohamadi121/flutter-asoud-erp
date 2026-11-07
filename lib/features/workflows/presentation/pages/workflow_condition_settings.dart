part of 'workflow_stage_settings_page.dart';

const _conditionOperators = <String, String>{
  'Equals': 'برابر با', 'Not Equals': 'مخالف با', 'Greater Than': 'بزرگ‌تر از',
  'Greater Or Equal': 'بزرگ‌تر یا مساوی', 'Less Than': 'کوچک‌تر از',
  'Less Or Equal': 'کوچک‌تر یا مساوی', 'Between': 'بین دو مقدار',
  'Contains': 'شامل عبارت', 'Not Contains': 'شامل نمی‌شود',
  'Is Empty': 'خالی است', 'Is Set': 'خالی نیست',
};

List<String> _operatorsFor(String? type) => [
  'Equals', if (type != 'Date') 'Not Equals',
  if (type == 'Number' || type == 'Date') ...[
    'Greater Than', 'Less Than', if (type == 'Number') ...['Greater Or Equal', 'Less Or Equal'], 'Between'],
  if (type == 'Text') ...['Contains', 'Not Contains'], 'Is Empty', 'Is Set',
];

class _ConditionDraft {
  _ConditionDraft(Map<String, dynamic> row) : id = '${row['id']}',
    source = '${row['source_kind'] ?? 'Original'}', previous = '${row['source_stage'] ?? ''}',
    field = '${row['source_field'] ?? ''}', operator = '${row['operator'] ?? 'Equals'}',
    first = TextEditingController(text: '${row['value'] ?? ''}'),
    last = TextEditingController(text: '${row['value_to'] ?? ''}');
  final String id;
  String source, previous, field, operator;
  final TextEditingController first, last;
  void dispose() { first.dispose(); last.dispose(); }
}

class _ConditionSettings extends StatefulWidget {
  const _ConditionSettings({required this.stage, required this.fields});
  final WorkflowStage stage;
  final List<WorkflowFieldOption> fields;
  @override
  State<_ConditionSettings> createState() => _ConditionSettingsState();
}

class _ConditionSettingsState extends State<_ConditionSettings> {
  late final title = TextEditingController(text: widget.stage.title);
  final rows = <_ConditionDraft>[];
  late String combine = '${widget.stage.config['combine'] ?? 'All'}';
  bool saving = false, checked = false;
  String? error;
  int serial = 0;
  String newId() => 'c${DateTime.now().microsecondsSinceEpoch}-${serial++}';
  @override
  void initState() {
    super.initState();
    final config = widget.stage.config;
    if (config['condition_version'] == 2 && config['conditions'] is List) {
      rows.addAll((config['conditions'] as List).map((row) => _ConditionDraft(Map<String, dynamic>.from(row))));
    } else {
      final name = config['source_field'];
      final matches = widget.fields.where((field) => field.name == name &&
        (config['source_kind'] == 'Document' ? field.source == 'Original' : true)).toList();
      // Legacy Form resolution could read the most recent action with the same
      // key. An ambiguous match requires explicit selection, never a guess.
      final field = matches.length == 1 ? matches.single : null;
      rows.add(_ConditionDraft({'id': newId(), 'source_kind': field?.source ?? 'Original',
        'source_stage': field?.sourceStage ?? '', 'source_field': field?.name ?? '',
        'operator': config['operator'] ?? 'Equals', 'value': config['compare_value'] ?? ''}));
    }
    if (rows.isEmpty) rows.add(_ConditionDraft({'id': newId()}));
  }
  @override
  void dispose() { title.dispose(); for (final row in rows) { row.dispose(); } super.dispose(); }
  WorkflowFieldOption? selected(_ConditionDraft row) => widget.fields.where((field) =>
    field.source == row.source && field.sourceStage == row.previous && field.name == row.field).firstOrNull;
  void update(VoidCallback action) => setState(() { action(); checked = false; error = null; });
  String numeric(String value) => toLatinDigits(value).replaceAll('٫', '.').trim();
  DateTime? isoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().substring(0, 10) == value ? date : null;
  }
  String displayValue(WorkflowFieldOption? field, String value) {
    if (field?.type == 'Date' && isoDate(value) != null) return formatJalaliIso(value);
    if (field?.type == 'Select') return field!.choiceLabels[value] ?? value;
    return toPersianDigits(value);
  }

  // Exact decimal comparison for bounds, without rounding monetary values.
  (BigInt, int)? decimal(String text) {
    final value = numeric(text);
    final match = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$').firstMatch(value);
    if (match == null || '${match[2]}${match[3] ?? ''}'.isEmpty || value.length > 2000) return null;
    final exponent = int.tryParse(match[4] ?? '0');
    if (exponent == null || exponent.abs() > 1000) return null;
    final digits = '${match[2]}${match[3] ?? ''}';
    final n = BigInt.parse('${match[1] == '-' ? '-' : ''}$digits');
    final scale = (match[3]?.length ?? 0) - exponent;
    return scale.abs() > 1000 ? null : (n, scale);
  }
  bool after((BigInt, int) first, (BigInt, int) last) {
    final scale = first.$2 > last.$2 ? first.$2 : last.$2;
    return first.$1 * BigInt.from(10).pow(scale - first.$2) >
        last.$1 * BigInt.from(10).pow(scale - last.$2);
  }
  String? validate() {
    if (title.text.trim().isEmpty) return 'عنوان مرحله الزامی است.';
    for (final (index, row) in rows.indexed) {
      final prefix = 'شرط ${toPersianDigits(index + 1)}: ';
      final field = selected(row);
      if (field == null) return '$prefixمنبع و فیلد معتبر را انتخاب کنید.';
      if (!_operatorsFor(field.type).contains(row.operator)) return '$prefixمعیار مقایسه با نوع فیلد سازگار نیست.';
      if (['Is Empty', 'Is Set'].contains(row.operator)) continue;
      if (row.first.text.isEmpty) return '$prefixمقدار مقایسه وارد نشده است.';
      if (field.type == 'Select' && !field.choices.contains(row.first.text)) return '$prefixمقدار انتخابی معتبر نیست.';
      if (field.type == 'Number' && decimal(row.first.text) == null) return '$prefixمقدار باید عدد معتبر باشد.';
      if (field.type == 'Date' && isoDate(row.first.text) == null) return '$prefixتاریخ معتبر نیست.';
      if (row.first.text.length > 2000) return '$prefixمقدار بیش از حد طولانی است.';
      if (row.operator == 'Between') {
        if (field.type == 'Number') {
          final end = decimal(row.last.text);
          if (end == null) return '$prefixانتهای بازه معتبر نیست.';
          if (after(decimal(row.first.text)!, end)) return '$prefixابتدای بازه از انتهای آن بزرگ‌تر است.';
        } else {
          final end = isoDate(row.last.text);
          if (end == null) return '$prefixانتهای بازه معتبر نیست.';
          if (DateTime.parse(row.first.text).isAfter(end)) return '$prefixابتدای بازه از انتهای آن بزرگ‌تر است.';
        }
      }
    }
    return null;
  }
  Future<void> save() async {
    if (saving) return;
    final problem = validate();
    if (problem != null) { setState(() => error = problem); return; }
    if (widget.stage.configurationComplete && widget.stage.config['condition_version'] != 2) {
      final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('ثبت نسخهٔ جدید تنظیمات شرط'),
        content: const Text('این مرحله با قواعد قدیمی ذخیره شده است. نسخهٔ جدید، مقادیر را بر اساس نوع واقعی فیلد و منبع انتخاب‌شده بررسی می‌کند. تنظیمات جدید برای همین مرحله ثبت شوند؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('تأیید ثبت تنظیمات جدید'))]));
      if (confirmed != true || !mounted) return;
    }
    setState(() { saving = true; error = null; });
    final cubit = context.read<WorkflowDesignerCubit>();
    final saved = await cubit.saveStage(widget.stage, {
      'title': title.text.trim(), 'description': widget.stage.config['description'] ?? '',
      'condition_version': 2, 'combine': combine,
      'conditions': [for (final row in rows) {
        'id': row.id, 'source_kind': row.source, 'source_stage': row.previous,
        'source_field': row.field, 'field_type': selected(row)!.type, 'operator': row.operator,
        if (!['Is Empty', 'Is Set'].contains(row.operator))
          'value': selected(row)!.type == 'Number' ? numeric(row.first.text) : row.first.text,
        if (row.operator == 'Between')
          'value_to': selected(row)!.type == 'Number' ? numeric(row.last.text) : row.last.text,
      }],
    });
    if (!mounted) return;
    setState(() { saving = false; error = saved ? null : cubit.state.message; });
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تنظیمات شرط و مسیر ذخیره شد.')));
      Navigator.pop(context);
    }
  }
  Widget panel(List<Widget> children) => Card(margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));
  Widget pick(String label, String value, List<AppOption> options, ValueChanged<String> changed, {Key? key}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: AppSelectField(
      key: key, label: label, value: value, enabled: !saving,
      displayValue: options.where((option) => option.value == value).firstOrNull?.label ?? 'انتخاب کنید',
      onPick: () => showAppOptionSheet(context, title: label, options: options, current: value),
      onChanged: (value) => update(() => changed(value))));

  Widget input(_ConditionDraft row, WorkflowFieldOption field, {bool end = false}) {
    final controller = end ? row.last : row.first;
    final label = row.operator == 'Between' ? (end ? 'مقدار دوم' : 'مقدار اول') : 'مقدار مقایسه';
    if (field.type == 'Select') { return pick(label, controller.text,
      field.choices.map((value) => AppOption(value, field.choiceLabels[value] ?? value)).toList(),
      (value) => controller.text = value, key: ValueKey('condition-value-${row.id}')); }
    if (field.type == 'Date') { return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppSelectField(
      label: end ? 'تاریخ پایان' : 'تاریخ شروع', value: controller.text, enabled: !saving,
      displayValue: controller.text.isEmpty ? 'انتخاب تاریخ' : formatJalaliIso(controller.text),
      onPick: () async {
        final date = await showAsoudJalaliPicker(context, initialDate: DateTime.tryParse(controller.text));
        return date?.toIso8601String().substring(0, 10);
      }, onChanged: (value) => update(() => controller.text = value))); }
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppTextField(
      key: ValueKey('condition-${end ? 'end' : 'value'}-${row.id}'), label: label,
      controller: controller, enabled: !saving, rounded: true,
      keyboardType: field.type == 'Number' ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
      hintLocales: field.type == 'Number' ? const [Locale('en')] : const [Locale('fa')],
      onChanged: (_) => update(() {})));
  }
  Widget condition(_ConditionDraft row, int index) {
    final field = selected(row);
    final available = widget.fields.where((field) => field.source == row.source && field.sourceStage == row.previous).toList();
    return panel([
      Row(children: [Expanded(child: Text('شرط ${toPersianDigits(index + 1)}', style: const TextStyle(fontWeight: FontWeight.bold))),
        if (rows.length > 1) IconButton(key: ValueKey('condition-remove-${row.id}'),
          tooltip: 'حذف همین شرط', onPressed: saving ? null : () => update(() {
            rows.remove(row); WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose()); }),
          icon: const Icon(Icons.delete_outline, color: AsoudColors.danger, size: 18))]),
      pick('منبع اطلاعات', row.source, const [AppOption('Original', 'فرم اصلی درخواست'),
        AppOption('Stage', 'اقدام قبلی'), AppOption('System', 'اطلاعات سیستم')], (source) {
          row.source = source; row.previous = ''; row.field = ''; row.operator = 'Equals'; row.first.clear(); row.last.clear();
        }, key: ValueKey('condition-source-${row.id}')),
      if (row.source == 'Stage') pick('اقدام قبلی', row.previous,
        {for (final field in widget.fields.where((field) => field.source == 'Stage')) field.sourceStage: field.stageTitle}
          .entries.map((entry) => AppOption(entry.key, entry.value)).toList(), (id) {
            row.previous = id; row.field = ''; row.first.clear(); row.last.clear(); row.operator = 'Equals';
          }, key: ValueKey('condition-previous-${row.id}')),
      if (available.isEmpty) const Text('فیلد قابل بررسی در این منبع و مسیر وجود ندارد.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
      pick('فیلد مورد بررسی', row.field, available.map((field) => AppOption(field.name, field.label)).toList(), (name) {
        row.field = name; row.operator = 'Equals'; row.first.clear(); row.last.clear();
      }, key: ValueKey('condition-field-${row.id}')),
      if (field != null) ...[
        pick('معیار مقایسه', row.operator, _operatorsFor(field.type).map((op) => AppOption(op, _conditionOperators[op]!)).toList(),
          (operator) { row.operator = operator; row.first.clear(); row.last.clear(); }, key: ValueKey('condition-operator-${row.id}')),
        if (!['Is Empty', 'Is Set'].contains(row.operator)) ...[
          input(row, field), if (row.operator == 'Between') input(row, field, end: true)],
      ],
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xfff5f7fb), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('خلاصه شرط', style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
          Text('${field?.label ?? 'فیلد انتخاب نشده'} · ${_conditionOperators[row.operator] ?? 'معیار انتخاب نشده'}'
            '${['Is Empty', 'Is Set'].contains(row.operator) ? '' : ' · ${displayValue(field, row.first.text)}'}'
            '${row.operator == 'Between' ? ' تا ${displayValue(field, row.last.text)}' : ''}', style: const TextStyle(fontSize: 11))])),
    ]);
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !saving, child: Scaffold(
    appBar: const AsoudHeader(title: 'شرط و مسیر', subtitle: 'بررسی اطلاعات و مشخص‌کردن مسیر فرایند',
      action: AsoudIconBox(icon: Icons.alt_route, color: Color(0xffBA8427))),
    body: ListView(padding: const EdgeInsets.all(14), children: [
      panel([const Text('۱. تعریف شروط', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('اطلاعات و مقادیر مورد بررسی را مشخص کنید.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        const SizedBox(height: 12), AppTextField(controller: title, label: 'عنوان مرحله', enabled: !saving,
          onChanged: (_) => update(() {}))]),
      for (final (index, row) in rows.indexed) KeyedSubtree(key: ValueKey('condition-row-${row.id}'), child: condition(row, index)),
      OutlinedButton.icon(key: const ValueKey('condition-add'), onPressed: saving || rows.length >= 50 ? null :
        () => update(() => rows.add(_ConditionDraft({'id': newId()}))), icon: const Icon(Icons.add, size: 16), label: const Text('افزودن شرط دیگر')),
      if (rows.length > 1) panel([const Text('۲. ترکیب شروط'),
        for (final item in [('All', 'همه شروط برقرار باشند', 'تمام شروط باید درست باشند.'),
            ('Any', 'حداقل یک شرط برقرار باشد', 'درست بودن یک شرط کافی است.')])
          Padding(padding: const EdgeInsets.only(top: 8), child: Material(
            color: combine == item.$1 ? const Color(0xffedf3ff) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: combine == item.$1 ? AsoudColors.primary : AsoudColors.border)),
            child: ListTile(key: ValueKey('condition-combine-${item.$1}'),
              leading: Icon(combine == item.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                color: combine == item.$1 ? AsoudColors.primary : AsoudColors.muted),
              onTap: saving ? null : () => update(() => combine = item.$1),
              title: Text(item.$2, style: const TextStyle(fontSize: 12)), subtitle: Text(item.$3, style: const TextStyle(fontSize: 10))))),
      ]),
      panel([const Text('خروجی‌های شرط', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('سیستم نتیجهٔ ارزیابی را از طریق یکی از دو خروجی ادامه می‌دهد.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        for (final item in [('شرط برقرار است', AsoudColors.success, Icons.check_circle_outline),
          ('شرط برقرار نیست', AsoudColors.danger, Icons.cancel_outlined)]) Container(
            margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: item.$2.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [Icon(item.$3, color: item.$2, size: 18), const SizedBox(width: 8), Text(item.$1, style: TextStyle(color: item.$2, fontSize: 12))])),
        const SizedBox(height: 10), const Text('مقصد هر دو خروجی را در صفحه طراحی گردش کار مشخص کنید.', style: TextStyle(fontSize: 11, color: AsoudColors.primary)),
      ]),
      Card(child: ExpansionTile(title: const Text('آزمایش تنظیمات شرط', style: TextStyle(fontSize: 13)), childrenPadding: const EdgeInsets.all(12), children: [
        const Text('این بخش فقط ساختار تنظیمات را بررسی می‌کند؛ اجرای آزمایشی فرایند نیست.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        OutlinedButton(onPressed: saving ? null : () => setState(() { error = validate(); checked = error == null; }), child: const Text('بررسی تنظیمات')),
        if (checked) const Text('ساختار تنظیمات کامل است؛ اعتبارسنجی نهایی هنگام ثبت انجام می‌شود.', style: TextStyle(color: AsoudColors.success, fontSize: 11)),
      ])),
      if (error != null) Text(error!, style: const TextStyle(color: AsoudColors.danger)),
    ]),
    bottomNavigationBar: FilledButtonTheme(
      data: FilledButtonThemeData(style: Theme.of(context).filledButtonTheme.style?.copyWith(
        backgroundColor: const WidgetStatePropertyAll(Color(0xff151515)),
        shape: const WidgetStatePropertyAll(StadiumBorder()))),
      child: AsoudBottomActions(primaryLabel: saving ? 'در حال ذخیره…' : 'تأیید تنظیمات شرط و مسیر',
        onPrimary: saving ? null : save, secondaryLabel: 'انصراف', onSecondary: saving ? null : () => Navigator.pop(context))),
  ));
}
