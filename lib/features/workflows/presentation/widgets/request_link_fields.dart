import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';

/// Loads choices (`{value, label, ...}`) for a search text, from
/// `workflow_request.request_field_options`.
typedef RequestOptionsLoader = Future<List<Map<String, dynamic>>> Function(
    String txt);

const _requiredMessage = 'این فیلد الزامی است.';

String _label(Map row) => '${row['label'] ?? row['value']}';

/// Chips for a "Multi Choice" field; the value keeps the options' order.
class RequestMultiChoiceField extends FormField<List<String>> {
  RequestMultiChoiceField({
    required String label,
    required List<String> options,
    required ValueChanged<List<String>> onChanged,
    List<String>? initialValue,
    bool required = false,
    bool enabled = true,
    super.key,
  }) : super(
          initialValue: initialValue ?? const [],
          validator: (value) => required && (value == null || value.isEmpty)
              ? _requiredMessage
              : null,
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
                labelText: label,
                errorText: state.errorText,
                border: InputBorder.none),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: state.value!.contains(option),
                  onSelected: !enabled
                      ? null
                      : (selected) {
                          final chosen = {...state.value!};
                          selected ? chosen.add(option) : chosen.remove(option);
                          final next = options.where(chosen.contains).toList();
                          state.didChange(next);
                          onChanged(next);
                        },
                ),
            ]),
          ),
        );
}

/// A searchable single choice of an ERPNext record ("User", "Department").
class RequestLinkField extends FormField<String> {
  RequestLinkField({
    required String label,
    required RequestOptionsLoader loader,
    required ValueChanged<String?> onChanged,
    bool required = false,
    bool enabled = true,
    super.key,
  }) : super(
          validator: (value) => required && (value == null || value.isEmpty)
              ? _requiredMessage
              : null,
          builder: (state) => _LinkFieldView(
              state: state,
              label: label,
              loader: loader,
              enabled: enabled,
              onChanged: onChanged),
        );
}

class _LinkFieldView extends StatefulWidget {
  const _LinkFieldView({
    required this.state,
    required this.label,
    required this.loader,
    required this.enabled,
    required this.onChanged,
  });
  final FormFieldState<String> state;
  final String label;
  final RequestOptionsLoader loader;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  State<_LinkFieldView> createState() => _LinkFieldViewState();
}

class _LinkFieldViewState extends State<_LinkFieldView> {
  String? display;

  Future<void> _pick() async {
    final row = await showRequestOptionPicker(context,
        title: widget.label, loader: widget.loader);
    if (row == null) return;
    setState(() => display = _label(row));
    widget.state.didChange('${row['value']}');
    widget.onChanged('${row['value']}');
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: InkWell(
          onTap: widget.enabled ? _pick : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: widget.state.errorText,
              suffixIcon: const Icon(Icons.search_rounded),
            ),
            child: Text(display ?? widget.state.value ?? 'انتخاب کنید',
                style: TextStyle(
                    color: widget.state.value == null
                        ? AsoudColors.muted
                        : AsoudColors.text)),
          ),
        ),
      );
}

/// Bottom sheet that searches [loader] and pops the chosen row.
Future<Map<String, dynamic>?> showRequestOptionPicker(BuildContext context,
        {required String title, required RequestOptionsLoader loader}) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: _OptionPicker(title: title, loader: loader)),
    );

class _OptionPicker extends StatefulWidget {
  const _OptionPicker({required this.title, required this.loader});
  final String title;
  final RequestOptionsLoader loader;

  @override
  State<_OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<_OptionPicker> {
  late Future<List<Map<String, dynamic>>> rows = widget.loader('');
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        rows = widget.loader(text.trim());
      });
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
            left: 16,
            right: 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: Column(children: [
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                  hintText: 'جستجو...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: rows,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: TextButton(
                            onPressed: () => setState(() {
                                  rows = widget.loader('');
                                }),
                            child: const Text(
                                'دریافت فهرست ممکن نشد؛ تلاش دوباره')));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('موردی پیدا نشد.',
                            style: TextStyle(color: AsoudColors.muted)));
                  }
                  return ListView(children: [
                    for (final row in snapshot.data!)
                      ListTile(
                        title: Text(_label(row)),
                        subtitle: _label(row) == '${row['value']}'
                            ? null
                            : Text('${row['value']}',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.of(context).pop(row),
                      ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      );
}

/// Rows of `{item_code, qty, uom}` for an "Item Table" field. Items and their
/// units come from ERPNext; the server adds item name and stock quantities.
class RequestItemTableField extends FormField<List<Map<String, dynamic>>> {
  RequestItemTableField({
    required String label,
    required RequestOptionsLoader items,
    required Future<List<Map<String, dynamic>>> Function(String itemCode) uoms,
    required ValueChanged<List<Map<String, dynamic>>> onChanged,
    bool required = false,
    bool enabled = true,
    super.key,
  }) : super(
          initialValue: const [],
          validator: (rows) {
            if (required && (rows == null || rows.isEmpty)) {
              return 'حداقل یک ردیف کالا لازم است.';
            }
            if (rows != null && rows.any((row) => (row['qty'] as num) <= 0)) {
              return 'مقدار هر ردیف باید بیشتر از صفر باشد.';
            }
            return null;
          },
          builder: (state) => _ItemTableView(
              state: state,
              label: label,
              items: items,
              uoms: uoms,
              enabled: enabled,
              onChanged: onChanged),
        );
}

class _ItemTableView extends StatefulWidget {
  const _ItemTableView({
    required this.state,
    required this.label,
    required this.items,
    required this.uoms,
    required this.enabled,
    required this.onChanged,
  });
  final FormFieldState<List<Map<String, dynamic>>> state;
  final String label;
  final RequestOptionsLoader items;
  final Future<List<Map<String, dynamic>>> Function(String itemCode) uoms;
  final bool enabled;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  State<_ItemTableView> createState() => _ItemTableViewState();
}

class _ItemTableViewState extends State<_ItemTableView> {
  final rows = <Map<String, dynamic>>[];
  final names = <String>[];
  final ids = <int>[];
  var nextId = 0;
  final unitLists = <String, Future<List<Map<String, dynamic>>>>{};

  void _publish() {
    final value = [for (final row in rows) Map<String, dynamic>.from(row)];
    widget.state.didChange(value);
    widget.onChanged(value);
  }

  Future<void> _add() async {
    final row = await showRequestOptionPicker(context,
        title: 'انتخاب کالا', loader: widget.items);
    if (row == null) return;
    setState(() {
      rows.add(
          {'item_code': '${row['value']}', 'qty': 1, 'uom': row['stock_uom']});
      names.add(_label(row));
      ids.add(nextId++);
    });
    _publish();
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.state.errorText,
            border: InputBorder.none),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) _row(index),
            OutlinedButton.icon(
              onPressed: widget.enabled ? _add : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('افزودن کالا'),
            ),
          ],
        ),
      );

  Widget _row(int index) {
    final row = rows[index];
    final code = row['item_code'] as String;
    final units = unitLists.putIfAbsent(code, () => widget.uoms(code));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Text(names[index],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: TextFormField(
              key: ValueKey('qty:${ids[index]}'),
              initialValue: '${row['qty']}',
              enabled: widget.enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              decoration:
                  const InputDecoration(isDense: true, labelText: 'مقدار'),
              onChanged: (text) {
                row['qty'] = num.tryParse(text.trim()) ?? 0;
                _publish();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: units,
              builder: (context, snapshot) {
                final choices = [
                  for (final unit
                      in snapshot.data ?? const <Map<String, dynamic>>[])
                    '${unit['value']}'
                ];
                if (row['uom'] != null && !choices.contains(row['uom'])) {
                  choices.insert(0, '${row['uom']}');
                }
                return DropdownButtonFormField<String>(
                  key: ValueKey('uom:${ids[index]}:${choices.length}'),
                  initialValue: row['uom'] as String?,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(isDense: true, labelText: 'واحد'),
                  items: [
                    for (final unit in choices)
                      DropdownMenuItem(value: unit, child: Text(unit)),
                  ],
                  onChanged: !widget.enabled
                      ? null
                      : (value) {
                          row['uom'] = value;
                          _publish();
                        },
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'حذف ردیف',
            onPressed: !widget.enabled
                ? null
                : () {
                    setState(() {
                      rows.removeAt(index);
                      names.removeAt(index);
                      ids.removeAt(index);
                    });
                    _publish();
                  },
            icon: const Icon(Icons.delete_outline_rounded,
                color: AsoudColors.danger),
          ),
        ]),
      ),
    );
  }
}

/// Text for a stored request value (lists, item rows, flags) on the detail page.
String formatRequestValue(Object? value) {
  String number(Object? qty) => qty is num && qty == qty.roundToDouble()
      ? '${qty.toInt()}'
      : '${qty ?? ''}';
  if (value == null || value == '' || (value is List && value.isEmpty)) {
    return '—';
  }
  if (value is bool) return value ? 'بله' : 'خیر';
  if (value is List) {
    return value
        .map((row) => row is Map
            ? '${row['item_name'] ?? row['item_code']} × ${number(row['qty'])} ${row['uom'] ?? ''}'
                .trim()
            : '$row')
        .join('\n');
  }
  return '$value';
}
