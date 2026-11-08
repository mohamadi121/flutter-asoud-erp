import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../form_builder/form_repository.dart';
import '../../../form_builder/form_runtime/form_preview_page.dart';

sealed class StageFormChoice {
  const StageFormChoice();
}

class StageFormPicked extends StageFormChoice {
  const StageFormPicked(
      {required this.name, required this.builtinKey, required this.title});
  final String? name;
  final String? builtinKey;
  final String title;
}

class StageFormCreate extends StageFormChoice {
  const StageFormCreate();
}

/// Contract order of the five built-in stage forms (contract C3).
const _defaultOrder = [
  'stage_request_checklist',
  'stage_expert_opinion',
  'stage_hr_review',
  'stage_finance_review',
  'stage_operations_review',
];

Future<StageFormChoice?> showStageFormSheet(
  BuildContext context, {
  required FormRepository repository,
  required String company,
  String? selectedName,
}) =>
    showModalBottomSheet<StageFormChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .6,
              child: StageFormSheet(
                  repository: repository,
                  company: company,
                  selectedName: selectedName),
            ),
          ),
        ),
      ),
    );

class StageFormSheet extends StatefulWidget {
  const StageFormSheet(
      {required this.repository,
      required this.company,
      this.selectedName,
      super.key});
  final FormRepository repository;
  final String company;
  final String? selectedName;

  @override
  State<StageFormSheet> createState() => _StageFormSheetState();
}

class _StageFormSheetState extends State<StageFormSheet> {
  String query = '';
  List<FormMap>? _rows;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = formMaps(await widget.repository.call('list_forms', {
        'company': widget.company,
        'kind': 'Stage',
      }));
      if (mounted) setState(() => _rows = rows);
    } catch (failure) {
      if (mounted) {
        setState(() => _error = failure is ApiException
            ? failure.message
            : 'دریافت فرم‌ها ممکن نشد.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalize(String value) =>
      value.replaceAll('ي', 'ی').replaceAll('ك', 'ک');

  List<FormMap> get _ordered {
    final rows = _rows ?? const <FormMap>[];
    final defaults = [
      for (final key in _defaultOrder)
        rows.where((row) => row['builtin_key'] == key).firstOrNull
    ].whereType<FormMap>().toList();
    final rest = rows
        .where((row) =>
            row['builtin_key'] == null ||
            !_defaultOrder.contains(row['builtin_key']))
        .toList()
      ..sort((a, b) => '${a['title'] ?? ''}'.compareTo('${b['title'] ?? ''}'));
    return [...defaults, ...rest];
  }

  List<FormMap> get _visible {
    final q = _normalize(query.trim());
    if (q.isEmpty) return _ordered;
    return _ordered
        .where((row) =>
            _normalize('${row['title'] ?? ''}').contains(q) ||
            _normalize('${row['description'] ?? ''}').contains(q))
        .toList();
  }

  Color _color(FormMap row) {
    final raw = '${row['color'] ?? formMap(row['schema'])['color'] ?? ''}';
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(raw);
    return match == null
        ? AsoudColors.primary
        : Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  Future<void> _preview(FormMap row) async {
    FormMap schema;
    try {
      final inline = formMap(row['schema']);
      if (inline.isNotEmpty) {
        schema = inline;
      } else {
        final data = formMap(
            await widget.repository.call('get_form', {'name': row['name']}));
        schema = formMap(data['schema']);
      }
    } catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(failure is ApiException
                ? failure.message
                : 'پیش‌نمایش فرم ممکن نشد.')));
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) =>
              FormPreviewPage(schema: schema, repository: widget.repository)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(children: [
          const Expanded(
              child: Text('انتخاب فرم',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(
              onPressed: () => Navigator.pop(context),
              tooltip: 'بستن',
              icon: const Icon(Icons.close_rounded)),
        ]),
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
              hintText: 'جستجو در فرم‌های این گردش کار...',
              prefixIcon: Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AsoudColors.border))),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading:
              const Icon(Icons.edit_note_rounded, color: AsoudColors.primary),
          title: const Text('ساخت فرم اختصاصی'),
          onTap: () => Navigator.pop(context, const StageFormCreate()),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_error != null) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!,
            style: const TextStyle(color: AsoudColors.danger, fontSize: 13)),
        const SizedBox(height: 8),
        TextButton(onPressed: load, child: const Text('تلاش دوباره')),
      ]));
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return const Center(child: Text('نتیجه‌ای پیدا نشد.'));
    }
    return ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [for (final row in rows) _card(row)]);
  }

  Widget _card(FormMap row) {
    final color = _color(row);
    final title = '${row['title'] ?? ''}';
    final description =
        '${row['description'] ?? formMap(row['schema'])['description'] ?? ''}';
    final selected =
        widget.selectedName != null && row['name'] == widget.selectedName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(
              context,
              StageFormPicked(
                  name: row['name'] as String?,
                  builtinKey: row['builtin_key'] as String?,
                  title: title)),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: .25)),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.description_outlined, color: color)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (description.isNotEmpty)
                      Text(description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AsoudColors.muted)),
                  ])),
              if (selected)
                const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle_rounded,
                        color: AsoudColors.primary)),
              const SizedBox(width: 8),
              OutlinedButton(
                key: ValueKey('stage-form-preview-${row['name']}'),
                onPressed: () => _preview(row),
                style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999))),
                child: const Text('پیش‌نمایش',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
