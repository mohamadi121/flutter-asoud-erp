import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../domain/entities/workflow_definition.dart';

/// Loads choices (`{value, label, ...}`) for a search text, from
/// `workflow_request.request_field_options`.
typedef RequestOptionsLoader = Future<List<Map<String, dynamic>>> Function(
    String txt);

const _requiredMessage = 'این فیلد الزامی است.';

class RequestBooleanField extends FormField<bool> {
  RequestBooleanField(
      {required String label,
      required ValueChanged<bool?> onChanged,
      super.initialValue,
      bool required = false,
      bool enabled = true,
      super.key})
      : super(
            validator: (value) =>
                required && value == null ? _requiredMessage : null,
            builder: (state) => DropdownButtonFormField<bool>(
                  initialValue: state.value,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: label, errorText: state.errorText),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('بله')),
                    DropdownMenuItem(value: false, child: Text('خیر')),
                  ],
                  onChanged: enabled
                      ? (value) {
                          state.didChange(value);
                          onChanged(value);
                        }
                      : null,
                ));
}

String _label(Map row) => '${row['label'] ?? row['value']}';

/// Group heading of a delivery location kind.
String requestLocationKindLabel(String kind) => switch (kind) {
      'warehouse' => 'انبار',
      'branch' => 'شعبه',
      'department' => 'واحد سازمانی',
      _ => kind,
    };

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
          validator: (value) {
            if (required && (value == null || value.isEmpty)) {
              return _requiredMessage;
            }
            if (value != null && value.any((item) => !options.contains(item))) {
              return 'گزینه‌ها تغییر کرده‌اند؛ انتخاب را اصلاح کنید.';
            }
            return null;
          },
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
    super.initialValue,
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
    if (row == null || !mounted) return;
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
                  final data = snapshot.data!;
                  // Rows with a `kind` (delivery locations) are grouped.
                  final kinds = <String>[
                    for (final kind in const [
                      'warehouse',
                      'branch',
                      'department'
                    ])
                      if (data.any((row) => row['kind'] == kind)) kind
                  ];
                  Widget tile(Map<String, dynamic> row) => ListTile(
                        title: Text(_label(row)),
                        subtitle: _label(row) == '${row['value']}' ||
                                row['kind'] != null
                            ? null
                            : Text('${row['value']}',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.of(context).pop(row),
                      );
                  return ListView(children: [
                    if (kinds.isEmpty)
                      for (final row in data) tile(row)
                    else
                      for (final kind in kinds) ...[
                        Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
                            child: Text(requestLocationKindLabel(kind),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AsoudColors.muted))),
                        for (final row in data.where((r) => r['kind'] == kind))
                          tile(row),
                      ],
                  ]);
                },
              ),
            ),
          ]),
        ),
      );
}

/// Files of item rows: the item table asks it to pick a file and shows the
/// result. [pick] returns the stored reference (`attachment:<ref>`), or null
/// when nothing was chosen.
abstract class RequestRowFiles {
  Future<String?> pick();

  /// The filename to show for a stored reference.
  String? label(String reference);

  /// Image bytes for a thumbnail, when the file is a picture held locally.
  Uint8List? bytes(String reference);

  /// Called when the row's file is removed or its row is deleted.
  void remove(String reference);
}

/// Rows of `{item_code, qty, uom}` for an "Item Table" field. Items and their
/// units come from ERPNext; the server adds item name and stock quantities.
///
/// With [rowOptions] (the template item tables) every row also has a
/// description, optionally a note (`rowOptions.note`) and a file
/// ([rowFiles], `rowOptions.attachment`). The unit is filled from the item's
/// stock unit when it is added.
class RequestItemTableField extends FormField<List<Map<String, dynamic>>> {
  RequestItemTableField({
    required String label,
    required RequestOptionsLoader items,
    required Future<List<Map<String, dynamic>>> Function(String itemCode) uoms,
    required ValueChanged<List<Map<String, dynamic>>> onChanged,
    bool required = false,
    bool enabled = true,
    List<Map<String, dynamic>> initialValue = const [],
    RowOptions? rowOptions,
    RequestRowFiles? rowFiles,
    bool driven = false,
    String? errorText,
    super.key,
  }) : super(
          initialValue: initialValue,
          // A form controller validates and shows the error itself.
          validator: driven
              ? null
              : (rows) {
                  if (required && (rows == null || rows.isEmpty)) {
                    return 'حداقل یک ردیف کالا لازم است.';
                  }
                  if (rows != null &&
                      rows.any((row) {
                        final qty = num.tryParse('${row['qty']}');
                        return qty == null || !qty.isFinite || qty <= 0;
                      })) {
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
              rowOptions: rowOptions,
              rowFiles: rowFiles,
              error: driven ? errorText : state.errorText,
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
    required this.error,
    this.rowOptions,
    this.rowFiles,
  });
  final FormFieldState<List<Map<String, dynamic>>> state;
  final String label;
  final RequestOptionsLoader items;
  final Future<List<Map<String, dynamic>>> Function(String itemCode) uoms;
  final bool enabled;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final String? error;
  final RowOptions? rowOptions;
  final RequestRowFiles? rowFiles;

  @override
  State<_ItemTableView> createState() => _ItemTableViewState();
}

class _ItemTableViewState extends State<_ItemTableView> {
  // Built together at start: they must not be created lazily after a row was
  // added, or the lists would disagree about the new row.
  late final List<Map<String, dynamic>> rows;
  late final List<String> names;
  late final List<int> ids;
  late int nextId;
  final unitLists = <String, Future<List<Map<String, dynamic>>>>{};

  @override
  void initState() {
    super.initState();
    rows = [
      for (final row in widget.state.value ?? <Map<String, dynamic>>[])
        Map<String, dynamic>.from(row)
    ];
    names = [for (final row in rows) '${row['item_name'] ?? row['item_code']}'];
    ids = List.generate(rows.length, (index) => index);
    nextId = rows.length;
  }

  int get _maxRows => widget.rowOptions?.maxRows ?? 100;

  void _publish() {
    final value = [for (final row in rows) Map<String, dynamic>.from(row)];
    widget.state.didChange(value);
    widget.onChanged(value);
  }

  Future<void> _add() async {
    if (rows.length >= _maxRows) return;
    final row = await showRequestOptionPicker(context,
        title: 'انتخاب کالا', loader: widget.items);
    if (row == null || !mounted) return;
    setState(() {
      rows.add({
        'item_code': '${row['value']}',
        'qty': 1,
        'uom': row['stock_uom'],
        // Template tables keep it so a form can check stock rules early; the
        // form controller does not send it.
        if (widget.rowOptions != null && row.containsKey('is_stock_item'))
          'is_stock_item': row['is_stock_item'],
      });
      names.add(_label(row));
      ids.add(nextId++);
    });
    _publish();
  }

  Future<void> _pickFile(int index) async {
    final reference = await widget.rowFiles!.pick();
    if (reference == null || !mounted) return;
    final old = rows[index]['attachment'];
    if (old is String && old.isNotEmpty) widget.rowFiles!.remove(old);
    setState(() => rows[index]['attachment'] = reference);
    _publish();
  }

  void _removeFile(int index) {
    final old = rows[index]['attachment'];
    if (old is String && old.isNotEmpty) widget.rowFiles?.remove(old);
    setState(() => rows[index].remove('attachment'));
    _publish();
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.error,
            border: InputBorder.none),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) _row(index),
            OutlinedButton.icon(
              onPressed: widget.enabled && rows.length < _maxRows ? _add : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('افزودن کالا'),
            ),
          ],
        ),
      );

  Widget _textRow(int index, String key, String label,
          {int maxLength = 1000}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextFormField(
          key: ValueKey('$key:${ids[index]}'),
          initialValue: '${rows[index][key] ?? ''}',
          enabled: widget.enabled,
          maxLength: maxLength,
          buildCounter: (_,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
          decoration: InputDecoration(isDense: true, labelText: label),
          onChanged: (text) {
            text.trim().isEmpty
                ? rows[index].remove(key)
                : rows[index][key] = text;
            _publish();
          },
        ),
      );

  Widget _fileRow(int index) {
    final files = widget.rowFiles!;
    final reference = '${rows[index]['attachment'] ?? ''}';
    if (reference.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
            key: ValueKey('row-file:${ids[index]}'),
            onPressed: widget.enabled ? () => _pickFile(index) : null,
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: const Text('افزودن فایل')),
      );
    }
    final bytes = files.bytes(reference);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        if (bytes != null)
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes,
                  key: ValueKey('row-thumb:${ids[index]}'),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_outlined)))
        else
          const Icon(Icons.insert_drive_file_outlined,
              color: AsoudColors.warning),
        const SizedBox(width: 8),
        Expanded(
            child: Text(files.label(reference) ?? reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11))),
        IconButton(
            tooltip: 'حذف فایل',
            onPressed: widget.enabled ? () => _removeFile(index) : null,
            icon: const Icon(Icons.close, size: 18)),
      ]),
    );
  }

  Widget _row(int index) {
    final row = rows[index];
    final code = row['item_code'] as String;
    final units = unitLists.putIfAbsent(code, () => widget.uoms(code));
    final options = widget.rowOptions;
    return Card(
      key: ValueKey(ids[index]),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(names[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    if (names[index] != code)
                      Text(code,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 10, color: AsoudColors.muted)),
                  ]),
            ),
            IconButton(
              tooltip: 'حذف ردیف',
              onPressed: !widget.enabled
                  ? null
                  : () {
                      final file = rows[index]['attachment'];
                      if (file is String && file.isNotEmpty) {
                        widget.rowFiles?.remove(file);
                      }
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
          Padding(
            padding: const EdgeInsets.only(right: 0, left: 6),
            child: Row(children: [
              SizedBox(
                width: 84,
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
                    row['qty'] = num.tryParse(toLatinDigits(text.trim())) ?? 0;
                    _publish();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: units,
                  builder: (context, snapshot) {
                    final choices = <String>{
                      for (final unit
                          in snapshot.data ?? const <Map<String, dynamic>>[])
                        '${unit['value']}'
                    }.toList();
                    if (row['uom'] != null && !choices.contains(row['uom'])) {
                      choices.insert(0, '${row['uom']}');
                    }
                    return DropdownButtonFormField<String>(
                      key: ValueKey('uom:${ids[index]}:${choices.length}'),
                      initialValue: row['uom'] as String?,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          isDense: true, labelText: 'واحد'),
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
            ]),
          ),
          if (options != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _textRow(index, 'description', 'شرح / مشخصات'),
            ),
          if (options != null && options.note)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _textRow(index, 'note', 'توضیحات قلم', maxLength: 500),
            ),
          if (options != null && options.attachment && widget.rowFiles != null)
            _fileRow(index),
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
