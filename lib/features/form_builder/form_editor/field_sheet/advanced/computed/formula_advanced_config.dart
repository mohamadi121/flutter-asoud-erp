import 'package:flutter/material.dart';

import '../../../../../../core/utils/jalali_date.dart';
import '../../../../../../core/utils/persian_format.dart';
import '../../../../form_repository.dart';
import '../../../../form_runtime.dart';

/// Advanced configuration for a Formula field. Formula references always use
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
  late String _currentTargetKey;
  bool _advanced = true;
  bool _calculatorOpen = false;
  late bool _hasConfirmedFormula;
  bool _availableFieldsExpanded = true;
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
    _currentTargetKey = '${widget.field['key']}';
    _saved = _normalise(formMap(widget.field['formula']));
    _draft = copyForm(_saved);
    _hasConfirmedFormula = formMap(widget.field['formula'])['op'] != null;

    // Initialize sample values with realistic defaults
    for (final field in _allNumericFields) {
      final key = '${field['key']}';
      final label = '${field['label'] ?? ''}';
      if (key == 'quantity' || label.contains('تعداد')) {
        _samples[key] = '3';
      } else if (key == 'unit_price' || label.contains('قیمت')) {
        _samples[key] = '500,000';
      } else if (key == 'discount' || label.contains('تخفیف')) {
        _samples[key] = '0';
      } else {
        _samples[key] = '1';
      }
    }
  }

  @override
  void didUpdateWidget(covariant FormulaAdvancedConfig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field != widget.field || oldWidget.schema != widget.schema) {
      _currentTargetKey = '${widget.field['key']}';
      _saved = _normalise(formMap(widget.field['formula']));
      _draft = copyForm(_saved);
      _hasConfirmedFormula = formMap(widget.field['formula'])['op'] != null;
    }
  }

  FormMap _normalise(FormMap formula) => {
        ...formula,
        'op': formula['op'] ?? 'add',
        'inputs': [...(formula['inputs'] as List? ?? [])]
            .map((item) => '$item')
            .toList(),
        if (formula['ops'] is List)
          'ops': [...(formula['ops'] as List)].map((item) => '$item').toList(),
        'columns': [...(formula['columns'] as List? ?? [])]
            .map((item) => '$item')
            .toList(),
        'precision': formula['precision'] ?? 2,
      };

  List<FormMap> get _allNumericFields => schemaFields(widget.schema)
      .where((field) =>
          const ['Integer', 'Decimal', 'Money', 'Formula'].contains(field['type']))
      .toList();

  List<FormMap> get _baseNumericFields => schemaFields(widget.schema)
      .where((field) =>
          const ['Integer', 'Decimal', 'Money'].contains(field['type']))
      .toList();

  List<FormMap> get _numericFields => _allNumericFields
      .where((field) => field['key'] != _currentTargetKey)
      .toList();

  List<FormMap> get _formulaFields => schemaFields(widget.schema)
      .where((field) => field['type'] == 'Formula')
      .toList();

  List<FormMap> get _tables => schemaFields(widget.schema)
      .where((field) => field['type'] == 'Table')
      .toList();

  List<String> get _inputs =>
      [...(_draft['inputs'] as List? ?? [])].map((item) => '$item').toList();

  List<String> get _ops =>
      [...(_draft['ops'] as List? ?? [])].map((item) => '$item').toList();

  FormMap get _cleanSamples {
    final result = <String, dynamic>{};
    for (final entry in _samples.entries) {
      final latin = toLatinDigits(entry.value)
          .replaceAll(',', '')
          .replaceAll('٬', '')
          .trim();
      result[entry.key] = latin.isEmpty ? '0' : latin;
    }
    return result;
  }

  FormMap get _previewValues => {
        ..._cleanSamples,
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
    // 1. Self reference check
    if (_inputs.contains(_currentTargetKey)) {
      return 'ارجاع فیلد به خودش در فرمول مجاز نیست.';
    }

    // 2. Reference to missing/deleted field
    final existingKeys = schemaFields(widget.schema).map((f) => '${f['key']}').toSet();
    for (final inputKey in _inputs) {
      if (!existingKeys.contains(inputKey)) {
        return 'فیلد مرجع «$inputKey» در فرم وجود ندارد.';
      }
    }

    // 3. Operator & input count validation
    final op = '${_draft['op']}';
    if (_tableOperations.containsKey(op)) {
      if (_draft['table'] == null) return 'جدول مورد استفاده را انتخاب کنید.';
      if (op != 'count' && (_draft['columns'] as List? ?? []).isEmpty) {
        return 'حداقل یک ستون عددی را انتخاب کنید.';
      }
    } else if (op == 'chain' || _ops.isNotEmpty) {
      if (_inputs.isEmpty) return 'فرمول خالی است.';
      if (_inputs.length != _ops.length + 1) {
        return 'تعداد عملوندها با عملگرها همخوانی ندارد.';
      }
    } else {
      if (_inputs.isEmpty) return 'فرمول خالی است.';
      if (_inputs.length != 2 && op != 'add') {
        return 'برای این محاسبه دو فیلد انتخاب کنید.';
      }
    }

    // 4. Evaluation and division by zero check
    final result = calculateForm(_draft, _previewValues);
    if (result.contains('تقسیم بر صفر')) {
      return 'تقسیم بر صفر در فرمول مجاز نیست.';
    }
    if (result.contains('مجاز نیست') ||
        result.contains('معتبر نیست') ||
        result.contains('پشتیبانی')) {
      return result;
    }

    // 5. Dependency graph & Cycle detection
    final candidate = copyForm(widget.field)
      ..['key'] = _currentTargetKey
      ..['formula'] = _draft;
    final others = schemaFields(widget.schema)
        .where((field) => field['key'] != _currentTargetKey)
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
      if (problem.contains('چرخه')) {
        return 'چرخه وابستگی در فرمول فیلدهای محاسباتی وجود دارد.';
      }
      if (problem.contains('ورودی قانون یا فرمول')) {
        return 'فیلد مرجع در فرم وجود ندارد.';
      }
    }

    return null;
  }

  String get _formulaText {
    final labels = {
      for (final field in _allNumericFields) '${field['key']}': '${field['label']}'
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
              .map((column) => '«${column['label']}»')
              .toList());
      return '${_tableOperations[op]} ${table?['label'] ?? ''}${columns.isEmpty ? '' : ' · ${columns.join('، ')}'}';
    }

    const symbols = {
      'add': '+',
      'subtract': '−',
      'multiply': '×',
      'divide': '÷',
      'percent': '٪',
    };

    if (_ops.isNotEmpty && _inputs.length == _ops.length + 1) {
      final buffer = StringBuffer();
      for (var i = 0; i < _inputs.length; i++) {
        if (i > 0) {
          final sym = symbols[_ops[i - 1]] ?? _ops[i - 1];
          buffer.write(' $sym ');
        }
        final key = _inputs[i];
        final label = labels[key] ?? key;
        buffer.write('«$label»');
      }
      return buffer.toString();
    }

    final sym = symbols[op] ?? op;
    return _inputs.map((key) => '«${labels[key] ?? key}»').join(' $sym ');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
    if (_allNumericFields.isEmpty && _tables.isEmpty) return _emptyState();
    final error = _error;
    final preview = error ?? calculateForm(_draft, _previewValues);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 14),
          _availableFieldsCard(),
          const SizedBox(height: 14),
          _targetFieldSelector(),
          const SizedBox(height: 12),
          _methodSwitch(),
          const SizedBox(height: 12),
          if (!_advanced)
            _normalControls()
          else ...[
            _formulaSummary(preview, error),
            if (_calculatorOpen) ...[
              const SizedBox(height: 10),
              _calculator(preview, error),
            ],
          ],
          const SizedBox(height: 14),
          _sampleValuesSection(),
          const SizedBox(height: 12),
          _resultsPanel(),
        ],
      ),
    );
  }

  Widget _header() => Row(
        children: const [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF2EAFE),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.calculate_outlined, color: Color(0xFF8654B5), size: 22),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'تنظیمات محاسباتی',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF122044),
            ),
          ),
        ],
      );

  Widget _availableFieldsCard() {
    final available = _baseNumericFields;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FD),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _availableFieldsExpanded = !_availableFieldsExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'فیلدهای ساخته‌شده در فرم نمونه',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF122044),
                    ),
                  ),
                ),
                Text(
                  '${toPersianDigits(available.length)} فیلد',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1876D2),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _availableFieldsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF1876D2),
                  size: 20,
                ),
              ],
            ),
          ),
          if (_availableFieldsExpanded) ...[
            const SizedBox(height: 10),
            for (final field in available) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${field['label']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF122044),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'فیلد موجود · ${_fieldKindLabel('${field['type']}')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5B6478),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _fieldIconBadge('${field['type']}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _fieldIconBadge(String type) {
    final Color bg;
    final Color iconColor;
    final IconData icon;

    if (type == 'Money') {
      bg = const Color(0xFFFFF0DD);
      iconColor = const Color(0xFFC05621);
      icon = Icons.account_balance_wallet_outlined;
    } else if (type == 'Formula') {
      bg = const Color(0xFFF2EAFE);
      iconColor = const Color(0xFF8654B5);
      icon = Icons.calculate_outlined;
    } else {
      bg = const Color(0xFFE5F7EF);
      iconColor = const Color(0xFF0B6B3A);
      icon = Icons.tag;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }

  String _fieldKindLabel(String type) {
    if (type == 'Money') return 'مبلغ';
    if (type == 'Formula') return 'محاسباتی';
    if (type == 'Decimal') return 'اعشاری';
    return 'عدد';
  }

  Widget _targetFieldSelector() {
    final items = _formulaFields.isEmpty
        ? [
            DropdownMenuItem(
              value: _currentTargetKey,
              child: Text('${widget.field['label'] ?? 'فیلد محاسباتی'}'),
            )
          ]
        : _formulaFields.map((f) {
            return DropdownMenuItem(
              value: '${f['key']}',
              child: Text('${f['label']}'),
            );
          }).toList();

    return DropdownButtonFormField<String>(
      initialValue: _currentTargetKey,
      decoration: const InputDecoration(
        labelText: 'فیلد محاسباتی ساخته‌شده در تب پایه',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items,
      onChanged: (newKey) {
        if (newKey == null || newKey == _currentTargetKey) return;
        setState(() {
          _currentTargetKey = newKey;
          for (final f in _formulaFields) {
            if (f['key'] == newKey) {
              _saved = _normalise(formMap(f['formula']));
              _draft = copyForm(_saved);
              _hasConfirmedFormula = formMap(f['formula'])['op'] != null;
              break;
            }
          }
        });
      },
    );
  }

  Widget _methodSwitch() => Row(
        children: [
          const Text(
            'روش محاسبه',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF122044),
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F9),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _modeButton(
                  label: 'پیشرفته',
                  selected: _advanced,
                  onTap: () => setState(() => _advanced = true),
                ),
                _modeButton(
                  label: 'عادی',
                  selected: !_advanced,
                  onTap: () => setState(() => _advanced = false),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0x0F000000),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: Color(0xFF1876D2)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? const Color(0xFF1876D2) : const Color(0xFF5B6478),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _normalControls() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _inputSelect('فیلد اول', 0),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _binaryOperations.containsKey(_draft['op'])
                ? '${_draft['op']}'
                : 'add',
            decoration: const InputDecoration(
              labelText: 'عملگر',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _binaryOperations.entries
                .map((entry) =>
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: (value) => _updateDraft(
                {..._draft, 'op': value, 'ops': null, 'table': null, 'columns': []}),
          ),
          const SizedBox(height: 8),
          _inputSelect('فیلد دوم', 1),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _applyDraft,
            icon: const Icon(Icons.check),
            label: const Text('تأیید فرمول عادی'),
          ),
        ],
      );

  Widget _inputSelect(String label, int index) =>
      DropdownButtonFormField<String>(
        initialValue: _inputs.length > index ? _inputs[index] : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: _numericFields
            .map((field) => DropdownMenuItem(
                value: '${field['key']}',
                child: Text('${field['label']} · ${_fieldKindLabel('${field['type']}')}')))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          final inputs = _inputs;
          while (inputs.length <= index) {
            inputs.add(value);
          }
          inputs[index] = value;
          _updateDraft(
              {..._draft, 'inputs': inputs, 'ops': null, 'table': null, 'columns': []});
        },
      );

  Widget _formulaSummary(String preview, String? error) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF5FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'فرمول ساخته‌شده',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF122044),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _draft = copyForm(_saved);
                    _calculatorOpen = true;
                  }),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F2FF),
                    foregroundColor: const Color(0xFF1876D2),
                    side: const BorderSide(color: Color(0xFFBCD8FF)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    _hasConfirmedFormula ? 'اصلاح فرمول' : 'ساخت فرمول',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              alignment: Alignment.center,
              child: Text(
                _inputs.isEmpty ? 'بدون فرمول' : _formulaText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF122044),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            _resultBanner(preview, error),
          ],
        ),
      );

  Widget _calculator(String preview, String? error) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, size: 18, color: Color(0xFF8654B5)),
                const SizedBox(width: 6),
                const Text(
                  'ماشین‌حساب فرمول',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF122044),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _cancelDraft,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Tokens Display Box
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              constraints: const BoxConstraints(minHeight: 40),
              child: _inputs.isEmpty
                  ? const Center(
                      child: Text(
                        'برای افزودن فیلد یا عملگر، دکمه‌های زیر را لمس کنید.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF758698)),
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _inputs.length; i++)
                          InputChip(
                            label: Text('«${_fieldLabel(_inputs[i])}»'),
                            selected: _selectedInput == i,
                            onSelected: (_) => setState(() => _selectedInput = i),
                            onDeleted: () {
                              final inputs = _inputs..removeAt(i);
                              _updateDraft({..._draft, 'inputs': inputs});
                            },
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            // Available field chips
            const Text(
              'فیلدهای قابل استفاده:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B6478)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _numericFields.map((field) {
                return ActionChip(
                  label: Text('${field['label']}'),
                  avatar: _fieldChipIcon('${field['type']}'),
                  onPressed: () => _insertInput('${field['key']}'),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // Operators & Actions
            const Text(
              'عملگرهای ریاضی:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B6478)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _opChip('جمع +', 'add'),
                _opChip('تفریق −', 'subtract'),
                _opChip('ضرب ×', 'multiply'),
                _opChip('تقسیم ÷', 'divide'),
                ActionChip(
                  label: const Text('پاک‌کردن'),
                  avatar: const Icon(Icons.delete_outline, size: 16),
                  onPressed: () => _updateDraft({..._draft, 'inputs': [], 'ops': null}),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _resultBanner(preview, error),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelDraft,
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _applyDraft,
                    child: const Text('تأیید فرمول'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _opChip(String label, String op) => ActionChip(
        label: Text(label),
        onPressed: () {
          _updateDraft({..._draft, 'op': op});
        },
      );

  Widget _fieldChipIcon(String type) {
    if (type == 'Money') return const Icon(Icons.attach_money, size: 14);
    if (type == 'Formula') return const Icon(Icons.calculate_outlined, size: 14);
    return const Icon(Icons.tag, size: 14);
  }

  String _fieldLabel(String key) {
    for (final field in _allNumericFields) {
      if (field['key'] == key) return '${field['label']}';
    }
    return key;
  }

  Widget _sampleValuesSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'مقادیر آزمایشی فیلدهای فرم',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF122044),
            ),
          ),
          const SizedBox(height: 8),
          for (final field in _baseNumericFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                initialValue: _samples['${field['key']}'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: '${field['label']}',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (value) => setState(() => _samples['${field['key']}'] = value),
              ),
            ),
        ],
      );

  Widget _resultsPanel() {
    // Evaluate all computed fields in schema given current sample values
    final rawValues = _cleanSamples;
    // Inject candidate draft into schema to compute preview of current target too
    final candidateField = copyForm(widget.field)
      ..['key'] = _currentTargetKey
      ..['formula'] = _draft;
    final otherFields = schemaFields(widget.schema)
        .where((f) => f['key'] != _currentTargetKey)
        .map(copyForm)
        .toList()
      ..add(candidateField);

    final testSchema = {
      ...widget.schema,
      'sections': [
        {'fields': otherFields},
      ],
      'rules': widget.schema['rules'] ?? [],
    };

    final evaluated = evaluatedValues(testSchema, rawValues);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in _formulaFields) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${field['label']}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF122044),
                      ),
                    ),
                  ),
                  Text(
                    _formatEvaluatedResult(evaluated['${field['key']}']),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007A78),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEvaluatedResult(dynamic val) {
    if (val == null) return '—';
    final str = '$val';
    if (str.contains('مجاز نیست') || str.contains('خطا') || str.contains('نیاز دارد')) {
      return str;
    }
    final numVal = num.tryParse(str.replaceAll(',', ''));
    if (numVal != null) {
      // If it's an integer, format as integer
      if (numVal == numVal.toInt()) {
        return _formatWithCommas(numVal.toInt().toString());
      }
      return _formatWithCommas(numVal.toString());
    }
    return str;
  }

  String _formatWithCommas(String numberStr) {
    final parts = numberStr.split('.');
    final integerPart = parts[0];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = integerPart.replaceAllMapped(reg, (Match m) => '${m[1]},');
    if (parts.length > 1) {
      return '$formattedInt.${parts[1]}';
    }
    return formattedInt;
  }

  Widget _resultBanner(String preview, String? error) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: error == null ? const Color(0xFFE5F7EF) : const Color(0xFFFFEAEA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          error ?? 'نتیجه نمونه: ${_formatEvaluatedResult(preview)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: error == null ? const Color(0xFF0B6B3A) : const Color(0xFFB42318),
          ),
        ),
      );

  Widget _emptyState() => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'برای ساخت فرمول، ابتدا در تب پایه یک فیلد عدد یا مبلغ اضافه کنید.',
          style: TextStyle(fontSize: 13, color: Color(0xFF5B6478)),
        ),
      );
}
