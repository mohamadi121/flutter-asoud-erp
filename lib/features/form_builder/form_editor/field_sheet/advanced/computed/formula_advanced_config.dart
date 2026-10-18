import 'package:flutter/material.dart';

import '../../../../form_repository.dart';
import '../../../../form_runtime.dart';

/// Advanced configuration for a Formula field.  Formula references always use
/// field keys; labels are only presented to the designer.
class FormulaAdvancedConfig extends StatefulWidget {
  const FormulaAdvancedConfig({
    required this.field,
    required this.schema,
    required this.fieldOptions,
    required this.onChanged,
    super.key,
  });

  final FormMap field;
  final FormMap schema;
  final Map<String, String> fieldOptions;
  final ValueChanged<FormMap> onChanged;

  @override
  State<FormulaAdvancedConfig> createState() => _FormulaAdvancedConfigState();
}

class _FormulaAdvancedConfigState extends State<FormulaAdvancedConfig> {
  late FormMap _saved;
  late FormMap _draft;
  bool _advanced = true;
  bool _calculatorOpen = false;
  late bool _hasConfirmedFormula;
  int? _selectedInput;
  final Map<String, String> _samples = {};

  static const _binaryOperations = <String, String>{
    'add': 'جمع +',
    'subtract': 'تفریق −',
    'multiply': 'ضرب ×',
    'divide': 'تقسیم ÷',
  };
  static const _tableOperations = <String, String>{
    'sum': 'جمع ستون',
    'average': 'میانگین ستون',
    'count': 'تعداد ردیف‌ها',
    'sum_product': 'جمع حاصل‌ضرب ستون‌ها',
  };

  @override
  void initState() {
    super.initState();
    _saved = _normalise(formMap(widget.field['formula']));
    _draft = copyForm(_saved);
    _hasConfirmedFormula = formMap(widget.field['formula'])['op'] != null;
    for (final field in _numericFields) {
      _samples['${field['key']}'] = '1';
    }
  }

  FormMap _normalise(FormMap formula) => {
        ...formula,
        'op': formula['op'] ?? 'add',
        'inputs': [...(formula['inputs'] as List? ?? [])]
            .map((item) => '$item')
            .toList(),
        'columns': [...(formula['columns'] as List? ?? [])]
            .map((item) => '$item')
            .toList(),
        'precision': formula['precision'] ?? 2,
      };

  List<FormMap> get _numericFields => schemaFields(widget.schema)
      .where((field) =>
          field['key'] != widget.field['key'] &&
          const ['Integer', 'Decimal', 'Money', 'Formula']
              .contains(field['type']))
      .toList();

  List<FormMap> get _tables => schemaFields(widget.schema)
      .where((field) => field['type'] == 'Table')
      .toList();

  List<String> get _inputs =>
      [...(_draft['inputs'] as List? ?? [])].map((item) => '$item').toList();

  FormMap get _previewValues => {
        for (final entry in _samples.entries) entry.key: entry.value,
        if (_draft['table'] != null) '${_draft['table']}': _tableSamples,
      };

  List<FormMap> get _tableSamples {
    final table = _tables.where((item) => item['key'] == _draft['table']);
    if (table.isEmpty) return const [];
    final columns = formMaps(table.first['columns']);
    return [
      {for (final column in columns) '${column['key']}': '1'},
      {for (final column in columns) '${column['key']}': '1'},
    ];
  }

  String? get _error {
    final op = '${_draft['op']}';
    if (_tableOperations.containsKey(op)) {
      if (_draft['table'] == null) return 'جدول مورد استفاده را انتخاب کنید.';
      if (op != 'count' && (_draft['columns'] as List? ?? []).isEmpty) {
        return 'حداقل یک ستون عددی را انتخاب کنید.';
      }
    } else {
      if (_inputs.length != 2) return 'برای این محاسبه دو فیلد انتخاب کنید.';
    }
    final result = calculateForm(_draft, _previewValues);
    if (result.contains('مجاز نیست') ||
        result.contains('معتبر نیست') ||
        result.contains('پشتیبانی')) {
      return result;
    }
    final candidate = copyForm(widget.field)..['formula'] = _draft;
    final others = schemaFields(widget.schema)
        .where((field) => field['key'] != widget.field['key'])
        .map(copyForm)
        .toList()
      ..add(candidate);
    final problems = schemaProblems({
      ...widget.schema,
      'title': widget.schema['title'] ?? 'فرم',
      'sections': [
        {'fields': others},
      ],
    });
    for (final problem in problems) {
      if (problem.contains('چرخه') ||
          problem.contains('ورودی قانون یا فرمول')) {
        return problem;
      }
    }
    return null;
  }

  String get _formulaText {
    final labels = {
      for (final field in _numericFields) '${field['key']}': '${field['label']}'
    };
    final op = '${_draft['op']}';
    if (_tableOperations.containsKey(op)) {
      FormMap? table;
      for (final item in _tables) {
        if (item['key'] == _draft['table']) {
          table = item;
          break;
        }
      }
      final columns = (table == null
          ? <String>[]
          : formMaps(table['columns'])
              .where((column) =>
                  (_draft['columns'] as List? ?? []).contains(column['key']))
              .map((column) => '${column['label']}')
              .toList());
      return '${_tableOperations[op]} ${table?['label'] ?? ''}${columns.isEmpty ? '' : ' · ${columns.join('، ')}'}';
    }
    const symbols = {
      'add': '+',
      'subtract': '−',
      'multiply': '×',
      'divide': '÷'
    };
    return _inputs
        .map((key) => labels[key] ?? key)
        .join(' ${symbols[op] ?? '?'} ');
  }

  void _updateDraft(FormMap formula) =>
      setState(() => _draft = _normalise(formula));

  void _insertInput(String key) {
    final values = _inputs;
    final index = _selectedInput == null ? values.length : _selectedInput! + 1;
    values.insert(index.clamp(0, values.length), key);
    _updateDraft({..._draft, 'inputs': values});
  }

  void _applyDraft() {
    final error = _error;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() {
      _saved = copyForm(_draft);
      _hasConfirmedFormula = true;
      _calculatorOpen = false;
      _selectedInput = null;
    });
    widget.onChanged(copyForm(_saved));
  }

  void _cancelDraft() => setState(() {
        _draft = copyForm(_saved);
        _calculatorOpen = false;
        _selectedInput = null;
      });

  @override
  Widget build(BuildContext context) {
    if (_numericFields.isEmpty && _tables.isEmpty) return _emptyState();
    final error = _error;
    final preview = error ?? calculateForm(_draft, _previewValues);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: const [
            DecoratedBox(
              decoration: BoxDecoration(
                  color: Color(0xFFF2EAFE),
                  borderRadius: BorderRadius.all(Radius.circular(8))),
              child: Padding(
                  padding: EdgeInsets.all(8),
                  child:
                      Icon(Icons.calculate_outlined, color: Color(0xFF8654B5))),
            ),
            SizedBox(width: 8),
            Text('تنظیمات محاسباتی',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF122044))),
          ]),
          const SizedBox(height: 14),
          _targetField(),
          const SizedBox(height: 12),
          _methodSwitch(),
          const SizedBox(height: 12),
          if (!_advanced)
            _normalControls()
          else
            _formulaSummary(preview, error),
          if (_calculatorOpen) ...[
            const SizedBox(height: 10),
            _calculator(preview, error),
          ],
          const SizedBox(height: 14),
          _sampleValues(preview, error),
        ],
      ),
    );
  }

  Widget _targetField() => DropdownButtonFormField<String>(
        initialValue: '${widget.field['key']}',
        decoration: const InputDecoration(
            labelText: 'فیلد محاسباتی ساخته‌شده در تب پایه',
            border: OutlineInputBorder()),
        items: [
          DropdownMenuItem(
              value: '${widget.field['key']}',
              child: Text('${widget.field['label'] ?? 'فیلد محاسباتی'}'))
        ],
        onChanged: null,
      );

  Widget _methodSwitch() => Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
              label: const Text('عادی'),
              selected: !_advanced,
              onSelected: (_) => setState(() => _advanced = false)),
          ChoiceChip(
              label: const Text('پیشرفته'),
              selected: _advanced,
              onSelected: (_) => setState(() => _advanced = true)),
        ],
      );

  Widget _normalControls() => Column(children: [
        _inputSelect('فیلد اول', 0),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _binaryOperations.containsKey(_draft['op'])
              ? '${_draft['op']}'
              : 'add',
          decoration: const InputDecoration(
              labelText: 'عملگر', border: OutlineInputBorder()),
          items: _binaryOperations.entries
              .map((entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)))
              .toList(),
          onChanged: (value) => _updateDraft(
              {..._draft, 'op': value, 'table': null, 'columns': []}),
        ),
        const SizedBox(height: 8),
        _inputSelect('فیلد دوم', 1),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
            onPressed: _applyDraft,
            icon: const Icon(Icons.check),
            label: const Text('تأیید فرمول عادی')),
      ]);

  Widget _inputSelect(String label, int index) =>
      DropdownButtonFormField<String>(
        initialValue: _inputs.length > index ? _inputs[index] : null,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: _numericFields
            .map((field) => DropdownMenuItem(
                value: '${field['key']}',
                child: Text('${field['label']} · ${field['type']}')))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          final inputs = _inputs;
          while (inputs.length <= index) {
            inputs.add(value);
          }
          inputs[index] = value;
          _updateDraft(
              {..._draft, 'inputs': inputs, 'table': null, 'columns': []});
        },
      );

  Widget _formulaSummary(String preview, String? error) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF5FC),
            borderRadius: BorderRadius.circular(10)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('فرمول ساخته‌شده',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _draft = copyForm(_saved);
                _calculatorOpen = true;
              }),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(_hasConfirmedFormula ? 'اصلاح فرمول' : 'ساخت فرمول'),
            ),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Text(
                _formulaText.isEmpty ? 'فرمولی انتخاب نشده است' : _formulaText),
          ),
          const SizedBox(height: 8),
          _resultBanner(preview, error),
        ]),
      );

  Widget _calculator(String preview, String? error) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF2EAFE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD7B9F2))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ماشین‌حساب فرمول',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF5B347C))),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _numericFields
                  .map((field) => ActionChip(
                        label: Text('${field['label']}'),
                        onPressed: () => _insertInput('${field['key']}'),
                      ))
                  .toList()),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _binaryOperations.entries
                  .map((entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: _draft['op'] == entry.key,
                        onSelected: (_) => _updateDraft({
                          ..._draft,
                          'op': entry.key,
                          'table': null,
                          'columns': []
                        }),
                      ))
                  .toList()),
          if (_tables.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tableOperations.containsKey(_draft['op'])
                  ? '${_draft['op']}'
                  : null,
              decoration: const InputDecoration(
                  labelText: 'محاسبه جدول', border: OutlineInputBorder()),
              items: _tableOperations.entries
                  .map((entry) => DropdownMenuItem(
                      value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) =>
                  _updateDraft({..._draft, 'op': value, 'inputs': []}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _draft['table'] as String?,
              decoration: const InputDecoration(
                  labelText: 'جدول', border: OutlineInputBorder()),
              items: _tables
                  .map((table) => DropdownMenuItem(
                      value: '${table['key']}',
                      child: Text('${table['label']}')))
                  .toList(),
              onChanged: (value) =>
                  _updateDraft({..._draft, 'table': value, 'columns': []}),
            ),
            if (_draft['table'] != null) ...[
              const SizedBox(height: 8),
              const Text('ستون‌های عددی جدول'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tableColumns
                    .map(
                      (column) => FilterChip(
                        label: Text('${column['label']}'),
                        selected: (_draft['columns'] as List? ?? [])
                            .contains(column['key']),
                        onSelected: (selected) {
                          final columns = [
                            ...(_draft['columns'] as List? ?? [])
                          ];
                          selected
                              ? columns.add(column['key'])
                              : columns.remove(column['key']);
                          _updateDraft({..._draft, 'columns': columns});
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
          if (_inputs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (var i = 0; i < _inputs.length; i++)
                InputChip(
                  label: Text(_inputs[i]),
                  selected: _selectedInput == i,
                  onSelected: (_) => setState(() => _selectedInput = i),
                  onDeleted: () {
                    final inputs = _inputs..removeAt(i);
                    _updateDraft({..._draft, 'inputs': inputs});
                  },
                )
            ]),
          ],
          const SizedBox(height: 10),
          _resultBanner(preview, error),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _cancelDraft, child: const Text('انصراف'))),
            const SizedBox(width: 8),
            Expanded(
                child: FilledButton(
                    onPressed: _applyDraft, child: const Text('تأیید فرمول'))),
          ]),
        ]),
      );

  Widget _sampleValues(String preview, String? error) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('مقادیر آزمایشی فیلدهای فرم',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF122044))),
        const SizedBox(height: 8),
        for (final field in _numericFields)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              initialValue: _samples['${field['key']}'],
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                  labelText: '${field['label']}',
                  border: const OutlineInputBorder()),
              onChanged: (value) =>
                  setState(() => _samples['${field['key']}'] = value),
            ),
          ),
        _resultBanner(preview, error),
      ]);

  Widget _resultBanner(String preview, String? error) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: error == null
                ? const Color(0xFFE5F7EF)
                : const Color(0xFFFFEAEA),
            borderRadius: BorderRadius.circular(8)),
        child: Text(error ?? 'نتیجه نمونه: $preview',
            style: TextStyle(
                color: error == null
                    ? const Color(0xFF0B6B3A)
                    : const Color(0xFFB42318))),
      );

  Widget _emptyState() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(12)),
        child: const Text(
            'برای ساخت فرمول، ابتدا در تب پایه یک فیلد عدد یا مبلغ اضافه کنید.'),
      );

  List<FormMap> get _tableColumns {
    for (final table in _tables) {
      if (table['key'] == _draft['table']) {
        return formMaps(table['columns'])
            .where(
              (column) => const ['Integer', 'Decimal', 'Money', 'Formula']
                  .contains(column['type']),
            )
            .toList();
      }
    }
    return const [];
  }
}
