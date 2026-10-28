import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../form_builder/form_repository.dart';

class StageFormSourcePicker extends StatefulWidget {
  const StageFormSourcePicker({required this.repository, super.key});
  final FormRepository repository;
  @override
  State<StageFormSourcePicker> createState() => _StageFormSourcePickerState();
}

class _StageFormSourcePickerState extends State<StageFormSourcePicker> {
  final cache = <String, List<FormMap>>{};
  final errors = <String, String>{};
  final loading = <String>{};
  String kind = 'Request', module = '', query = '';
  FormMap? picked;
  bool confirming = false, showAll = true;
  @override
  void initState() { super.initState(); load(kind); }

  Future<void> load(String target) async {
    if (loading.contains(target)) return;
    setState(() { loading.add(target); errors.remove(target); });
    try {
      final result = await widget.repository.list(target);
      if (mounted) setState(() => cache[target] = result.where((r) => r['removed'] != true).toList());
    } catch (failure) {
      if (mounted) setState(() => errors[target] = failureDetail(failure));
    } finally {
      if (mounted) setState(() => loading.remove(target));
    }
  }

  Future<void> confirm() async {
    if (confirming || picked == null) return;
    final row = picked!;
    setState(() { confirming = true; errors.remove(kind); });
    try {
      final identity = row['builtin_pending'] == true
          ? formMap(await widget.repository.call('open_builtin',
              {'company': widget.repository.company, 'key': row['builtin_key'], 'manage': 1})) : row;
      if (identity['active_revision'] is! String) {
        throw const ApiException(kind: ApiFailureKind.validation,
            message: 'این فرم نسخهٔ منتشرشده ندارد؛ ابتدا آن را منتشر کنید.');
      }
      // Design authority is distinct from permission to SUBMIT this form. Fetch
      // the pinned published revision, never an unpublished management draft.
      final result = formMap(await widget.repository.call('get_form',
          {'name': identity['name'], 'manage': 1, 'revision_name': identity['active_revision']}));
      final schema = formMap(result['schema']);
      if (result['disabled'] == true || (result.containsKey('active_revision') &&
          result['revision'] != result['active_revision'])) {
        throw const ApiException(kind: ApiFailureKind.validation,
            message: 'فرم غیرفعال یا نسخهٔ آن تغییر کرده است؛ فهرست را دوباره دریافت کنید.');
      }
      if (result['submission_source_version'] != 1) {
        throw const ApiException(kind: ApiFailureKind.validation,
            message: 'برای اتصال ارسال فرم به گردش‌کار، بک‌اند باید به نسخهٔ جدید به‌روزرسانی شود.');
      }
      if (result['name'] is! String || result['revision'] is! String || schema['title'] is! String) {
        throw StateError('پاسخ قالب معتبر نیست.');
      }
      if (mounted) {
        Navigator.pop(context, <String, dynamic>{'form': result['name'],
          'revision': result['revision'], 'title': schema['title'], 'kind': schema['kind']});
      }
    } catch (failure) {
      if (mounted) setState(() => errors[kind] = failureDetail(failure));
    } finally {
      if (mounted) setState(() => confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = (cache[kind] ?? []).where((row) =>
      (module.isEmpty || _module(row) == module) &&
      '${row['title'] ?? ''}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Directionality(textDirection: TextDirection.rtl,
      child: SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .9,
        child: Column(children: [
          Expanded(child: ListView(key: const ValueKey('stage-source-list'),
            padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            Row(children: [const Expanded(child: Text('انتخاب درخواست یا سند',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'بستن انتخاب درخواست یا سند', onPressed: confirming ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close))]),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(
              color: Colors.white, border: Border.all(color: AsoudColors.border), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [for (final tab in const [('Request', 'درخواست‌ها'), ('Document', 'سندها')])
                Expanded(child: TextButton(style: TextButton.styleFrom(
                    backgroundColor: kind == tab.$1 ? AsoudColors.primary : Colors.white,
                    foregroundColor: kind == tab.$1 ? Colors.white : AsoudColors.text,
                    minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: confirming ? null : () { setState(() { kind = tab.$1; picked = null; });
                    if (!cache.containsKey(kind)) load(kind); }, child: Text(tab.$2)))])),
            const SizedBox(height: 16),
            TextField(hintLocales: const [Locale('fa')], enabled: !confirming,
              key: const ValueKey('stage-source-search'), onChanged: (v) => setState(() => query = v.trim()),
              decoration: InputDecoration(hintText: kind == 'Request' ? 'جست‌وجوی درخواست…' : 'جست‌وجوی سند…',
                prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white)),
            const SizedBox(height: 12),
            Row(children: [const Expanded(child: Text('ماژول‌ها', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: confirming ? null : () => setState(() => showAll = !showAll),
                child: Text(showAll ? 'نمایش کمتر' : 'نمایش همه'))]),
            LayoutBuilder(builder: (context, constraints) => Wrap(spacing: 8, runSpacing: 8, children: [
              for (final item in showAll ? _modules : _modules.take(4))
                SizedBox(width: (constraints.maxWidth - 24) / 4, height: 86,
                  child: InkWell(onTap: confirming ? null : () => setState(() { module = item.$1; picked = null; }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(decoration: BoxDecoration(color: item.$4.withValues(alpha: .10),
                      border: Border.all(color: module == item.$1 ? AsoudColors.primary : AsoudColors.border,
                          width: module == item.$1 ? 1.5 : 1), borderRadius: BorderRadius.circular(12)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(item.$3, size: 23, color: item.$4), const SizedBox(height: 10),
                        Text(item.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))])))),
            ])),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: Text(kind == 'Request' ? 'درخواست‌های موجود' : 'سندهای موجود',
                style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(formatCount(rows.length, 'مورد'), style: const TextStyle(fontSize: 11, color: AsoudColors.muted))]),
            const SizedBox(height: 10),
            if (loading.contains(kind)) const LinearProgressIndicator(),
            if (errors[kind] != null) ...[
              Text(errors[kind]!, style: const TextStyle(color: AsoudColors.danger)),
              TextButton(onPressed: confirming ? null : () => load(kind), child: const Text('تلاش دوباره'))],
            if (!loading.contains(kind) && errors[kind] == null && rows.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text('درخواست یا سندی با این جست‌وجو و فیلتر پیدا نشد.')),
            for (final row in rows) _row(row),
            const SizedBox(height: 12),
          ])),
          Container(padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AsoudColors.border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
                color: AsoudColors.primary.withValues(alpha: .06), borderRadius: BorderRadius.circular(10)),
                child: const Text('پس از تکمیل و ارسال این نوع درخواست یا سند، همین ثبت اصلی وارد گردش‌کار می‌شود؛ این انتخاب فرم یا سند تازه‌ای نمی‌سازد.',
                    style: TextStyle(fontSize: 11, height: 1.8, color: AsoudColors.muted))),
              const SizedBox(height: 10),
              FilledButton(onPressed: picked == null || confirming ? null : confirm,
                  child: Text(confirming ? 'در حال بررسی انتخاب…' : 'انتخاب و تأیید')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: confirming ? null : () => Navigator.pop(context), child: const Text('انصراف')),
            ])),
        ]))));
  }

  Widget _row(FormMap row) {
    final available = row['status'] == 'Published' && row['local'] != true && row['cached'] != true;
    final selected = picked?['name'] == row['name'];
    final meta = _modules.where((m) => m.$1 == _module(row)).firstOrNull ?? _modules.first;
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: selected ? AsoudColors.primary : AsoudColors.border)),
      child: ListTile(key: ValueKey('stage-source-${row['name']}'), enabled: available && !confirming,
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: meta.$4.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12)), child: Icon(Icons.description_outlined, color: meta.$4)),
        title: Text('${row['title'] ?? 'فرم بدون عنوان'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(available ? meta.$2 : 'برای انتخاب، ابتدا این فرم را منتشر کنید.', style: const TextStyle(fontSize: 11)),
        trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AsoudColors.primary : AsoudColors.muted),
        onTap: available && !confirming ? () => setState(() => picked = row) : null));
  }
}

String _module(FormMap row) {
  final key = '${row['module_key'] ?? formMap(row['schema'])['module'] ?? ''}';
  return switch (key) {'Stock' => 'Inventory', 'Accounting' => 'Finance', 'Administration' => 'Admin', _ => key};
}
const _modules = [('', 'همه', Icons.grid_view_rounded, Color(0xff2478e7)),
  ('HR', 'منابع انسانی', Icons.people_outline, Color(0xff279468)),
  ('Finance', 'مالی', Icons.account_balance_wallet_outlined, Color(0xffdd9417)),
  ('Admin', 'اداری', Icons.description_outlined, Color(0xffec467a)),
  ('Inventory', 'انبار', Icons.inventory_2_outlined, Color(0xff19a6a2)),
  ('Sales', 'فروش', Icons.storefront_outlined, Color(0xffa449ce)),
  ('Purchase', 'خرید', Icons.shopping_cart_outlined, Color(0xff647eae))];
