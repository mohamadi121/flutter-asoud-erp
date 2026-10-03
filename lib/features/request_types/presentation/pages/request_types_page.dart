import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/domain/repositories/workflow_repository.dart';
import '../../domain/request_type_catalog.dart';
import '../../domain/request_templates.dart';
import '../cubit/request_type_builder_cubit.dart';
import 'request_type_builder_page.dart';

/// Admin list of request types, the entry point of the builder.
class RequestTypesPage extends StatefulWidget {
  const RequestTypesPage({required this.company, super.key});
  final String company;

  @override
  State<RequestTypesPage> createState() => _RequestTypesPageState();
}

class _RequestTypesPageState extends State<RequestTypesPage> {
  late Future<List<WorkflowDefinition>> future = _load();
  String query = '';

  Future<List<WorkflowDefinition>> _load() async => (await context
          .read<WorkflowRepository>()
          .getWorkflows(company: widget.company))
      .where((item) => item.targetDoctype == requestTargetDoctype)
      .toList();

  void _reload() => setState(() {
        future = _load();
      });

  Future<void> _open([WorkflowDefinition? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => RequestTypeBuilderPage(
            company: widget.company, existing: existing)));
    if (saved == true && mounted) _reload();
  }

  Future<void> _templates() async {
    final template = await showModalBottomSheet<RequestTemplate>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      const Text('درخواست‌های آماده',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      const Text(
                          'یک الگو انتخاب کنید؛ تمام فیلدها قابل ویرایش‌اند. قبل از استفاده باید نقش‌های مجاز و گردش تأیید را تکمیل کنید. انتخاب الگو چیزی ثبت نمی‌کند.'),
                      for (final item in requestTemplates)
                        Card(
                            child: ListTile(
                          leading: AsoudIconBox(
                              icon: requestIconFor(item.info.iconKey).icon,
                              color: requestIconFor(item.info.iconKey).color),
                          title: Text(item.info.title),
                          subtitle: Text(item.fields
                              .map((field) => field.label)
                              .join('، ')),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => Navigator.pop(context, item),
                        )),
                    ])))));
    if (template == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => RequestTypeBuilderPage(
            company: widget.company, template: template)));
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(
              title: 'انواع درخواست',
              subtitle: 'تعریف فرم، گردش کار و دسترسی هر درخواست'),
          body: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        onPressed: _templates,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('استفاده از درخواست آماده')))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => query = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'جستجو در انواع درخواست‌ها...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<WorkflowDefinition>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: TextButton(
                            onPressed: _reload,
                            child: const Text('دریافت ناموفق؛ تلاش دوباره')));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!
                      .where((item) =>
                          query.isEmpty ||
                          item.title.contains(query) ||
                          (item.shortTitle ?? '').contains(query))
                      .toList();
                  if (items.isEmpty) {
                    return const Center(
                        child: Text('هنوز نوع درخواستی تعریف نشده است.',
                            style: TextStyle(color: AsoudColors.muted)));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        for (final item in items)
                          _RequestTypeCard(
                              item: item, onTap: () => _open(item)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]),
          bottomNavigationBar: AsoudBottomActions(
              primaryLabel: 'ایجاد نوع درخواست جدید', onPrimary: _open),
        ),
      );
}

class _RequestTypeCard extends StatelessWidget {
  const _RequestTypeCard({required this.item, required this.onTap});
  final WorkflowDefinition item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = requestIconFor(item.iconKey);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(children: [
                PopupMenuButton<String>(
                    tooltip: 'عملیات درخواست',
                    onSelected: (_) => onTap(),
                    itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'edit', child: Text('ویرایش نوع درخواست')),
                        ]),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                          item.shortTitle?.isNotEmpty == true
                              ? item.shortTitle!
                              : item.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: visual.color)),
                      const SizedBox(height: 3),
                      Text(
                          'نسخه ${item.version} · ${item.stepsCount} مرحله${item.status == WorkflowDefinitionStatus.active ? '' : ' · پیش‌نویس / غیرفعال'}',
                          style: const TextStyle(
                              fontSize: 10, color: AsoudColors.muted)),
                    ])),
                const SizedBox(width: 12),
                AsoudIconBox(icon: visual.icon, color: visual.color, size: 42),
              ]))),
    );
  }
}
