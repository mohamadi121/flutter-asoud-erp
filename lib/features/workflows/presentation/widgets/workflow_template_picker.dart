import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/workflow_template_repository.dart';
import '../../domain/entities/workflow_definition.dart';

class WorkflowTemplatePicker extends StatefulWidget {
  const WorkflowTemplatePicker({required this.repository, required this.company,
    required this.modules, this.selected, super.key});
  final WorkflowTemplateRepository repository;
  final String company;
  final List<WorkflowModuleOption> modules;
  final WorkflowTemplate? selected;
  @override
  State<WorkflowTemplatePicker> createState() => _WorkflowTemplatePickerState();
}

class _WorkflowTemplatePickerState extends State<WorkflowTemplatePicker> {
  final search = TextEditingController();
  Timer? debounce;
  List<WorkflowTemplate> rows = [];
  late WorkflowTemplate? picked = widget.selected;
  String module = '';
  String? error;
  bool loading = true;
  int? nextStart;
  int epoch = 0;
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { debounce?.cancel(); search.dispose(); super.dispose(); }

  Future<void> load({bool more = false}) async {
    final request = ++epoch;
    setState(() { loading = true; error = null; if (!more) { rows = []; picked = null; nextStart = null; } });
    try {
      final result = await widget.repository.catalog(company: widget.company,
          search: search.text.trim(), module: module, start: more ? nextStart ?? 0 : 0);
      if (!mounted || request != epoch) return;
      setState(() { rows = [...rows, ...result.items]; nextStart = result.nextStart; });
    } catch (failure) {
      if (mounted && request == epoch) setState(() => error = failureDetail(failure));
    } finally {
      if (mounted && request == epoch) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
    child: SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .85,
      child: Padding(padding: EdgeInsets.fromLTRB(16, 0, 16,
          12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [const Expanded(child: Text('انتخاب الگوی آماده',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'بستن انتخاب الگو', onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close))]),
          TextField(key: const ValueKey('workflow-template-search'), controller: search,
            hintLocales: const [Locale('fa')],
            decoration: const InputDecoration(hintText: 'جست‌وجو در الگوها…', prefixIcon: Icon(Icons.search)),
            onChanged: (_) {
              debounce?.cancel();
              ++epoch;
              setState(() { picked = null; rows = []; loading = true; });
              debounce = Timer(const Duration(milliseconds: 350), () => load());
            }),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final key in ['', ...widget.modules.map((m) => m.key)])
                Padding(padding: const EdgeInsetsDirectional.only(end: 7),
                  child: ChoiceChip(label: Text(_moduleLabel(key)), selected: module == key,
                    onSelected: (_) { debounce?.cancel(); setState(() => module = key); load(); })),
            ])),
          const SizedBox(height: 8),
          Expanded(child: loading && rows.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(itemCount: rows.length + 1, itemBuilder: (context, index) {
                if (index == rows.length) {
                  return Column(children: [
                    if (error != null) ...[Text(error!, style: const TextStyle(color: AsoudColors.danger)),
                      TextButton(onPressed: loading ? null : () => load(more: rows.isNotEmpty),
                          child: const Text('تلاش دوباره'))],
                    if (rows.isEmpty && error == null) const Padding(padding: EdgeInsets.all(24),
                        child: Text('الگوی آماده‌ای برای این دفتر و فیلتر پیدا نشد.')),
                    if (loading) const LinearProgressIndicator(),
                    if (!loading && error == null && nextStart != null)
                      TextButton(onPressed: () => load(more: true), child: const Text('نمایش بیشتر')),
                  ]);
                }
                final row = rows[index];
                final active = picked?.id == row.id;
                return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: active ? AsoudColors.primary : AsoudColors.border)),
                  child: ListTile(key: ValueKey('workflow-template-${row.id}'),
                    leading: const AsoudIconBox(icon: Icons.account_tree_outlined,
                        color: AsoudColors.primary, size: 42),
                    title: Text(row.title), subtitle: Text(_moduleLabel(row.module)),
                    trailing: Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: active ? AsoudColors.primary : AsoudColors.muted),
                    onTap: loading ? null : () => setState(() => picked = row)));
              })),
          const SizedBox(height: 10),
          const Text('یک پیش‌نویس مستقل از الگو ساخته می‌شود؛ اصل الگو و سوابق آن تغییر نمی‌کنند.',
              style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
          const SizedBox(height: 10),
          FilledButton(onPressed: picked == null || loading ? null : () => Navigator.pop(context, picked),
              child: const Text('انتخاب الگو برای کپی مستقل')),
        ])))));
}

String _moduleLabel(String key) => switch (key) {
  '' => 'همه', 'Purchase' => 'خرید', 'Accounting' => 'مالی', 'Sales' => 'فروش',
  'Inventory' => 'انبار', 'Support' => 'پشتیبانی', 'HR' => 'منابع انسانی', _ => 'سایر',
};
