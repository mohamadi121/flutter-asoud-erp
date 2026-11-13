part of 'workflow_stage_settings_page.dart';

const _conditionOperators = <String, String>{
  'Equals': 'برابر با', 'Not Equals': 'مخالف با', 'Greater Than': 'بزرگ‌تر از',
  'Greater Or Equal': 'بزرگ‌تر یا مساوی', 'Less Than': 'کوچک‌تر از',
  'Less Or Equal': 'کوچک‌تر یا مساوی', 'Between': 'بین دو مقدار',
  'Contains': 'شامل عبارت', 'Not Contains': 'شامل نمی‌شود',
  'Is Empty': 'خالی است', 'Is Set': 'خالی نیست',
};

List<String> _operatorsFor(String? type) => [
  if (type == 'MultiSelect') ...['Contains', 'Not Contains'] else ...[
  'Equals', if (!['Date', 'DateTime', 'Time'].contains(type)) 'Not Equals'],
  if (type == 'Number' || ['Date', 'DateTime', 'Time'].contains(type)) ...[
    'Greater Than', 'Less Than', if (type == 'Number') ...['Greater Or Equal', 'Less Or Equal'], 'Between'],
  if (type == 'Text') ...['Contains', 'Not Contains'], 'Is Empty', 'Is Set',
];

class _ConditionDraft {
  _ConditionDraft(Map<String, dynamic> row) : id = '${row['id']}',
    source = '${row['source_kind'] ?? 'Original'}', previous = '${row['source_stage'] ?? ''}',
    field = '${row['source_field'] ?? ''}', operator = '${row['operator'] ?? 'Equals'}',
    first = TextEditingController(text: '${row['value'] ?? ''}'),
    last = TextEditingController(text: '${row['value_to'] ?? ''}'),
    storedType = '${row['field_type'] ?? ''}';
  final String id;
  final anchor = GlobalKey();
  final sample = TextEditingController();
  List<String> sampleChoices = [];
  final referenceLabels = <String, String>{};
  String storedType;
  String source, previous, field, operator;
  final TextEditingController first, last;
  void dispose() { first.dispose(); last.dispose(); sample.dispose(); }
}

class _ConditionSettings extends StatefulWidget {
  const _ConditionSettings({required this.stage, required this.fields, this.repository, this.onCommitted});
  final WorkflowStage stage;
  final List<WorkflowFieldOption> fields;
  final WorkflowConditionRepository? repository;
  final VoidCallback? onCommitted;
  @override
  State<_ConditionSettings> createState() => _ConditionSettingsState();
}

class _ConditionSettingsState extends State<_ConditionSettings> {
  late final title = TextEditingController(text: widget.stage.title);
  final rows = <_ConditionDraft>[];
  late String combine = '${widget.stage.config['combine'] ?? 'All'}';
  bool saving = false, checked = false;
  String? error;
  String? testError;
  final rowErrors = <String, String>{};
  final scroll = ScrollController();
  bool showErrors = false, testing = false;
  Map<String, dynamic>? testResult;
  WorkflowConditionRepository get repository => widget.repository ??
      WorkflowConditionRepository(context.read<FrappeApiClient>());
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
  void dispose() { title.dispose(); scroll.dispose(); for (final row in rows) { row.dispose(); } super.dispose(); }
  WorkflowFieldOption? selected(_ConditionDraft row) => widget.fields.where((field) =>
    field.source == row.source && field.sourceStage == row.previous && field.name == row.field).firstOrNull;
  void update(VoidCallback action) {
    if (testing) return;
    setState(() {
    action(); checked = false; error = null; testError = null; testResult = null;
    if (showErrors) collectErrors();
  });
  }
  String numeric(String value) => toLatinDigits(value).replaceAll('٫', '.').trim();
  DateTime? isoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    return date != null && date.year >= 1 && date.toIso8601String().substring(0, 10) == value ? date : null;
  }
  String displayValue(WorkflowFieldOption? field, String value) {
    if (field?.type == 'Date' && isoDate(value) != null) return formatJalaliIso(value);
    if (field?.type == 'Select') return field!.choiceLabels[value] ?? value;
    if (field?.linkDoctype != null && value.isNotEmpty) return field!.choiceLabels[value] ?? 'گزینهٔ انتخاب‌شده';
    if (field?.type == 'Boolean') return value == 'true' ? 'بله' : 'خیر';
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
  String? rowProblem(_ConditionDraft row) {
      final field = selected(row);
      if (field == null) return 'منبع یا فیلد حذف شده یا در این مسیر معتبر نیست؛ دوباره انتخاب کنید.';
      if (row.storedType.isNotEmpty && row.storedType != field.type) return 'نوع فیلد تغییر کرده است؛ فیلد و مقدار را دوباره انتخاب کنید.';
      if (!_operatorsFor(field.type).contains(row.operator)) return 'معیار مقایسه با نوع فیلد سازگار نیست.';
      if (['Is Empty', 'Is Set'].contains(row.operator)) return null;
      if (row.first.text.trim().isEmpty) return 'مقدار مقایسه وارد نشده است.';
      if (['Select', 'MultiSelect'].contains(field.type) && !field.choices.contains(row.first.text)) return 'مقدار انتخابی معتبر نیست.';
      if (field.type == 'Boolean' && !['true', 'false'].contains(row.first.text)) return 'بله یا خیر را انتخاب کنید.';
      if (field.type == 'Number' && decimal(row.first.text) == null) return 'مقدار باید عدد معتبر باشد.';
      final number = field.type == 'Number' ? decimal(row.first.text) : null;
      if (['Integer', 'Int'].contains(field.dataType) && number != null && number.$2 > 0 &&
          number.$1 % BigInt.from(10).pow(number.$2) != BigInt.zero) {
        return 'مقدار باید عدد صحیح باشد.';
      }
      if (field.type == 'Date' && isoDate(row.first.text) == null) return 'تاریخ معتبر نیست.';
      if (['DateTime', 'Time'].contains(field.type) && temporal(field.type, row.first.text) == null) return 'تاریخ یا ساعت معتبر نیست.';
      if (row.first.text.length > 2000) return 'مقدار بیش از حد طولانی است.';
      if (row.operator == 'Between') {
        if (field.type == 'Number') {
          final end = decimal(row.last.text);
          if (end == null) return 'انتهای بازه معتبر نیست.';
          if (['Integer', 'Int'].contains(field.dataType) && end.$2 > 0 &&
              end.$1 % BigInt.from(10).pow(end.$2) != BigInt.zero) {
            return 'انتهای بازه باید عدد صحیح باشد.';
          }
          if (after(decimal(row.first.text)!, end)) return 'ابتدای بازه از انتهای آن بزرگ‌تر است.';
        } else {
          final end = temporal(field.type, row.last.text);
          if (end == null) return 'انتهای بازه معتبر نیست.';
          if (temporal(field.type, row.first.text)!.isAfter(end)) return 'تاریخ شروع نباید بعد از تاریخ پایان باشد.';
        }
      }
    return null;
  }
  DateTime? temporal(String kind, String value) {
    if (kind == 'Date') return isoDate(value);
    if (kind == 'Time') {
      if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d+)?)?$').hasMatch(value)) return null;
      return DateTime.tryParse('2000-01-01T$value');
    }
    if (value.length < 16 || isoDate(value.substring(0, 10)) == null) return null;
    return DateTime.tryParse(value);
  }
  void collectErrors() {
    rowErrors.clear();
    for (final row in rows) {
      final problem = rowProblem(row);
      if (problem != null) rowErrors[row.id] = problem;
    }
  }
  String? validate() {
    collectErrors();
    if (title.text.trim().isEmpty) return 'عنوان مرحله الزامی است.';
    return rowErrors.isEmpty ? null : rowErrors.values.first;
  }
  Future<void> focusError() async {
    final row = rows.where((row) => rowErrors.containsKey(row.id)).firstOrNull;
    if (row == null || !scroll.hasClients) return;
    scroll.jumpTo(0);
    await WidgetsBinding.instance.endOfFrame;
    while (mounted && row.anchor.currentContext == null && scroll.offset < scroll.position.maxScrollExtent) {
      await scroll.animateTo((scroll.offset + 350).clamp(0, scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 80), curve: Curves.easeOut);
    }
    if (mounted && row.anchor.currentContext != null) {
      await Scrollable.ensureVisible(row.anchor.currentContext!, duration: const Duration(milliseconds: 160));
    }
  }
  Map<String, dynamic> payload() => {
    'title': title.text.trim(), 'description': widget.stage.config['description'] ?? '',
    'condition_version': 2, 'combine': combine,
    'conditions': [for (final row in rows) {
      'id': row.id, 'source_kind': row.source, 'source_stage': row.previous,
      'source_field': row.field, 'field_type': selected(row)!.type, 'operator': row.operator,
      if (!['Is Empty', 'Is Set'].contains(row.operator))
        'value': selected(row)!.type == 'Number' ? numeric(row.first.text) : row.first.text,
      if (row.operator == 'Between') 'value_to': selected(row)!.type == 'Number' ? numeric(row.last.text) : row.last.text,
    }],
  };
  Future<void> runTest() async {
    if (saving || testing) return;
    final problem = validate();
    setState(() { showErrors = true; checked = problem == null; testResult = null; error = rowErrors.isEmpty ? problem : null; });
    if (problem != null) { await focusError(); return; }
    FocusScope.of(context).unfocus();
    setState(() { testing = true; testError = null; });
    try {
      final samples = <String, dynamic>{
          for (final row in rows) row.id: selected(row)?.type == 'MultiSelect' ? row.sampleChoices :
            selected(row)?.type == 'Number' ? numeric(row.sample.text) : row.sample.text,
        };
      final cubit = context.read<WorkflowDesignerCubit>();
      final source = cubit.repository;
      final Map<String, dynamic> result;
      if (widget.repository == null && source is WorkflowConditionTestRepository) {
        final response = await (source as WorkflowConditionTestRepository).testWorkflowCondition(
          definition: cubit.definition, stage: widget.stage.id, config: payload(), samples: samples);
        result = {'result': response.result, 'rows': [for (final row in response.rows)
          {'id': row.id, 'result': row.result, if (row.error != null) 'error': row.error}]};
      } else {
        result = await repository.test(definition: cubit.definition,
          stage: widget.stage.id, config: payload(), samples: samples);
      }
      if (mounted) setState(() => testResult = result);
    } on ConditionTestUnsupportedException {
      if (mounted) setState(() => testError = 'سرور فعلی از آزمایش شرط پشتیبانی نمی‌کند؛ این بخش فقط ساختار تنظیمات را بررسی می‌کند؛ اجرای آزمایشی فرایند نیست.');
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() => testError = failure.kind == ApiFailureKind.forbidden
        ? 'دسترسی لازم برای آزمایش شرط را ندارید.' :
          failure.kind == ApiFailureKind.validation ? failureDetail(failure) :
          failure.kind == ApiFailureKind.network && RegExp(r'[\u0600-\u06ff]').hasMatch(failure.message)
            ? failure.message : failureMessage(failure));
      }
    } catch (failure) {
      if (mounted) setState(() => testError = failureMessage(failure));
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }
  Future<void> save() async {
    if (saving) return;
    final problem = validate();
    if (problem != null) {
      setState(() { showErrors = true; error = rowErrors.isEmpty ? problem : null; });
      await focusError(); return;
    }
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
    final saved = await cubit.saveStage(widget.stage, payload());
    if (!mounted) return;
    setState(() { saving = false; error = saved ? null : cubit.state.message; });
    if (!saved && error != null) {
      final match = RegExp(r'^شرط\s+([0-9۰-۹]+):\s*(.*)', dotAll: true).firstMatch(error!);
      final index = match == null ? null : int.tryParse(toLatinDigits(match[1]!));
      if (index != null && index > 0 && index <= rows.length) {
        setState(() { rowErrors[rows[index - 1].id] = match![2]!; showErrors = true; error = null; });
        await focusError();
      }
    }
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تنظیمات شرط و مسیر ذخیره شد.')));
      widget.onCommitted?.call();
      Navigator.pop(context);
    }
  }
  Widget panel(List<Widget> children) => Card(margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));
  Widget pick(String label, String value, List<AppOption> options, ValueChanged<String> changed, {Key? key, String? errorText}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: AppSelectField(
      key: key, label: label, value: value, enabled: !saving && !testing, errorText: errorText,
      displayValue: options.where((option) => option.value == value).firstOrNull?.label ?? 'انتخاب کنید',
      onPick: () => showAppOptionSheet(context, title: label, options: options, current: value),
      onChanged: (value) => update(() => changed(value))));

  Widget input(_ConditionDraft row, WorkflowFieldOption field, {bool end = false, bool sample = false}) {
    final controller = sample ? row.sample : end ? row.last : row.first;
    final label = sample ? 'مقدار نمونه' : row.operator == 'Between' ? (end ? 'مقدار دوم' : 'مقدار اول') : 'مقدار مقایسه';
    final problem = !sample && (end || row.operator != 'Between') ? rowErrors[row.id] : null;
    final key = ValueKey('condition-${sample ? 'sample' : end ? 'end' : 'value'}-${row.id}');
    if (['user', 'employee'].contains(field.valueSource) && field.linkDoctype == null) {
      final people = context.read<WorkflowDesignerCubit>().state.options?.employees ?? <WorkflowTargetOption>[];
      final user = field.valueSource == 'user';
      final chosen = people.where((person) => (user ? person.userId : person.id) == controller.text).firstOrNull;
      return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppSelectField(
        key: key, label: label, value: controller.text, enabled: !saving && !testing, errorText: problem,
        displayValue: chosen?.label ?? 'انتخاب کنید',
        onPick: () async {
          if (user) {
            final person = await pickUser(context, employees: people, selectedUserId: controller.text);
            return person?.userId;
          }
          return showAppOptionSheet(context, title: 'انتخاب پرسنل', current: controller.text,
            options: people.map((person) => AppOption(person.id, person.label)).toList());
        }, onChanged: (value) => update(() => controller.text = value)));
    }
    if (sample && field.type == 'MultiSelect') {
      return buildChoiceInput(context: context, f: {'key': row.id, 'type': 'MultiSelect',
        'options': [for (final choice in field.choices) {'id': choice, 'label': field.choiceLabels[choice] ?? choice}]},
        value: row.sampleChoices, label: label, required: false,
        onChanged: (value) => update(() => row.sampleChoices = List<String>.from(value as List)))!;
    }
    if (field.type == 'Boolean') {
      return pick(label, controller.text, const [AppOption('true', 'بله'), AppOption('false', 'خیر')],
        (value) => controller.text = value, key: key, errorText: problem);
    }
    if (['Select', 'MultiSelect'].contains(field.type)) { return pick(label, controller.text,
      field.choices.map((value) => AppOption(value, field.choiceLabels[value] ?? value)).toList(),
      (value) => controller.text = value, key: key, errorText: problem); }
    if (field.linkDoctype != null) {
      return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppSelectField(
        key: key, label: label, value: controller.text, enabled: !saving && !testing, errorText: problem,
        displayValue: row.referenceLabels[controller.text] ?? field.choiceLabels[controller.text] ?? 'گزینهٔ ثبت‌شده؛ برای بازبینی لمس کنید',
        onPick: () async {
          try {
            final definition = context.read<WorkflowDesignerCubit>().definition;
            final result = await showModalBottomSheet<Map<String, dynamic>>(context: context,
              isScrollControlled: true, useSafeArea: true, showDragHandle: true,
              builder: (_) => _ConditionReferenceChoices(repository: repository, definition: definition,
                stage: widget.stage.id, field: field));
            if (result == null || !mounted) return null;
            row.referenceLabels['${result['value']}'] = '${result['label']}';
            return '${result['value']}';
          } catch (failure) {
            if (mounted) setState(() => error = failureMessage(failure));
            return null;
          }
        }, onChanged: (value) => update(() => controller.text = value)));
    }
    if (['DateTime', 'Time'].contains(field.type)) {
      return Padding(key: key, padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(decoration: problem == null ? null : BoxDecoration(
            borderRadius: BorderRadius.circular(12), border: Border.all(color: AsoudColors.danger.withValues(alpha: .5))),
            child: buildDateTimeInput(context: context, f: {'type': field.type}, value: controller.text,
              label: label, required: false, onChanged: (value) => update(() => controller.text = '$value'))!),
          if (problem != null) Text(problem, style: const TextStyle(color: AsoudColors.danger)),
        ]));
    }
    if (field.type == 'Date') { return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppSelectField(
      key: key, errorText: problem,
      label: sample ? label : end ? 'تاریخ پایان' : 'تاریخ شروع', value: controller.text, enabled: !saving && !testing,
      displayValue: controller.text.isEmpty ? 'انتخاب تاریخ' : formatJalaliIso(controller.text),
      onPick: () async {
        final date = await showAsoudJalaliPicker(context, initialDate: DateTime.tryParse(controller.text));
        return date?.toIso8601String().substring(0, 10);
      }, onChanged: (value) => update(() => controller.text = value))); }
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppTextField(
      key: key, label: label,
      suffixIcon: sample || field.currency == null ? null : Padding(padding: const EdgeInsets.only(left: 10), child: Text(field.currency!)),
      errorText: problem, controller: controller, enabled: !saving && !testing, rounded: true,
      keyboardType: field.type == 'Number' ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
      hintLocales: field.type == 'Number' ? const [Locale('en')] : const [Locale('fa')],
      onChanged: (_) => update(() {})));
  }
  Widget condition(_ConditionDraft row, int index) {
    final field = selected(row);
    final available = widget.fields.where((field) => field.source == row.source && field.sourceStage == row.previous).toList();
    return KeyedSubtree(key: row.anchor, child: panel([
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
        row.storedType = ''; row.sample.clear(); row.sampleChoices = [];
      }, key: ValueKey('condition-field-${row.id}'), errorText: field == null ? rowErrors[row.id] : null),
      if (field != null) ...[
        pick('معیار مقایسه', row.operator, (field.linkDoctype != null
            ? ['Equals', 'Not Equals', 'Is Empty', 'Is Set'] : _operatorsFor(field.type)).map((op) => AppOption(op, _conditionOperators[op]!)).toList(),
          (operator) { row.operator = operator; row.first.clear(); row.last.clear(); }, key: ValueKey('condition-operator-${row.id}')),
        if (!['Is Empty', 'Is Set'].contains(row.operator)) ...[
          input(row, field), if (row.operator == 'Between') input(row, field, end: true)],
      ],
      if (field != null && ['Is Empty', 'Is Set'].contains(row.operator) && rowErrors[row.id] != null)
        Text(rowErrors[row.id]!, style: const TextStyle(color: AsoudColors.danger)),
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xfff5f7fb), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('خلاصه شرط', style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
          Text('${field?.label ?? 'فیلد انتخاب نشده'} · ${_conditionOperators[row.operator] ?? 'معیار انتخاب نشده'}'
            '${['Is Empty', 'Is Set'].contains(row.operator) ? '' : ' · ${displayValue(field, row.first.text)}'}'
            '${row.operator == 'Between' ? ' تا ${displayValue(field, row.last.text)}' : ''}', style: const TextStyle(fontSize: 11))])),
    ]));
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !saving, child: Scaffold(
    appBar: const AsoudHeader(title: 'شرط و مسیر', subtitle: 'بررسی اطلاعات و مشخص‌کردن مسیر فرایند',
      action: AsoudIconBox(icon: Icons.alt_route, color: Color(0xffBA8427))),
    body: ListView(controller: scroll, padding: const EdgeInsets.all(14), children: [
      panel([const Text('۱. تعریف شروط', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('اطلاعات و مقادیر مورد بررسی را مشخص کنید.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        const SizedBox(height: 12), AppTextField(controller: title, label: 'عنوان مرحله', enabled: !saving && !testing,
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
      panel([Text('${toPersianDigits(rows.length > 1 ? 3 : 2)}. خروجی‌های شرط', style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text('سیستم نتیجهٔ ارزیابی را از طریق یکی از دو خروجی ادامه می‌دهد.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        for (final item in [('شرط برقرار است', AsoudColors.success, Icons.check_circle_outline),
          ('شرط برقرار نیست', AsoudColors.danger, Icons.cancel_outlined)]) Container(
            margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: item.$2.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [Icon(item.$3, color: item.$2, size: 18), const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.$1, style: TextStyle(color: item.$2, fontSize: 12)),
                Text(item.$2 == AsoudColors.success ? 'خروجی اول' : 'خروجی دوم', style: TextStyle(color: item.$2, fontSize: 10))])])),
        const SizedBox(height: 10), const Text('اتصال خروجی‌ها به مراحل بعدی فقط در صفحه طراحی گردش کار انجام می‌شود.', style: TextStyle(fontSize: 11, color: AsoudColors.primary)),
      ]),
      panel([Text('${toPersianDigits(rows.length > 1 ? 4 : 3)}. آزمایش شرط', style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text('آزمایش تنظیمات شرط', style: TextStyle(fontSize: 13)),
        const Text('مقدارهای نمونه فقط برای آزمایش همین شرط‌اند؛ درخواست یا وظیفه‌ای ساخته نمی‌شود.', style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
        OutlinedButton(onPressed: saving || testing ? null : () async {
          setState(() { showErrors = true; final problem = validate(); error = rowErrors.isEmpty ? problem : null; checked = problem == null; });
          await focusError();
        }, child: const Text('بررسی تنظیمات')),
        if (checked) const Text('ساختار تنظیمات کامل است؛ اعتبارسنجی نهایی هنگام ثبت انجام می‌شود.', style: TextStyle(color: AsoudColors.success, fontSize: 11)),
        for (final (index, row) in rows.indexed) if (selected(row) != null) ...[
          Text('نمونهٔ شرط ${toPersianDigits(index + 1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          input(row, selected(row)!, sample: true),
        ],
        OutlinedButton(key: const ValueKey('condition-run-test'), onPressed: saving || testing ? null : runTest,
          child: Text(testing ? 'در حال آزمایش…' : 'اجرای آزمایشی')),
        if (testResult != null) Text(testResult!['result'] == true ? 'شرط برقرار است — خروجی اول' :
          testResult!['result'] == false ? 'شرط برقرار نیست — خروجی دوم' : 'آزمایش خطا دارد؛ مقدارهای نمونه را بررسی کنید.',
          key: const ValueKey('condition-test-result'),
          style: TextStyle(color: testResult!['result'] == true ? AsoudColors.success : AsoudColors.danger)),
        if (testResult?['rows'] is List) for (final row in testResult!['rows'] as List)
          if (row is Map && row['error'] != null) Text('${row['error']}', style: const TextStyle(color: AsoudColors.danger)),
        if (testError != null) Text(testError!, style: const TextStyle(color: AsoudColors.danger)),
      ]),
      if (error != null) Text(error!, style: const TextStyle(color: AsoudColors.danger)),
    ]),
    bottomNavigationBar: FilledButtonTheme(
      data: FilledButtonThemeData(style: Theme.of(context).filledButtonTheme.style?.copyWith(
        backgroundColor: const WidgetStatePropertyAll(Color(0xff151515)),
        shape: const WidgetStatePropertyAll(StadiumBorder()))),
      child: AsoudBottomActions(primaryLabel: saving ? 'در حال ذخیره…' : 'تأیید تنظیمات شرط و مسیر',
        onPrimary: saving || testing || (showErrors && (rowErrors.isNotEmpty || title.text.trim().isEmpty))
          ? null : save, secondaryLabel: 'انصراف', onSecondary: saving || testing ? null : () => Navigator.pop(context))),
  ));
}

class _ConditionReferenceChoices extends StatefulWidget {
  const _ConditionReferenceChoices({required this.repository, required this.definition, required this.stage, required this.field});
  final WorkflowConditionRepository repository;
  final String definition, stage;
  final WorkflowFieldOption field;
  @override
  State<_ConditionReferenceChoices> createState() => _ConditionReferenceChoicesState();
}

class _ConditionReferenceChoicesState extends State<_ConditionReferenceChoices> {
  late Future<List<Map<String, dynamic>>> choices = widget.repository.choices(widget.definition, widget.stage, widget.field, '');
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
    child: SizedBox(height: MediaQuery.sizeOf(context).height * .65,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text(widget.field.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        TextField(decoration: const InputDecoration(labelText: 'جست‌وجو', prefixIcon: Icon(Icons.search)),
          onSubmitted: (query) => setState(() => choices = widget.repository.choices(widget.definition, widget.stage, widget.field, query))),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: choices, builder: (context, snapshot) {
          if (snapshot.hasError) return Text(failureMessage(snapshot.error!));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return const Center(child: Text('گزینهٔ مجاز و فعالی پیدا نشد.'));
          return ListView(children: [for (final choice in snapshot.data!) ListTile(title: Text('${choice['label']}'),
            onTap: () => Navigator.pop(context, choice))]);
        })),
      ]))));
}
