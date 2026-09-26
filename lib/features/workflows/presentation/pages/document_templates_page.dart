import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/workflow_automation_repository.dart';
import '../../domain/entities/document_template.dart';
import '../widgets/document_template_visuals.dart';
import 'document_template_wizard_page.dart';

/// «الگوهای سند»: saved (custom) templates and the built-in ready ones.
class DocumentTemplatesPage extends StatefulWidget {
  const DocumentTemplatesPage(
      {required this.company, this.repository, super.key});
  final String company;
  final WorkflowAutomationRepository? repository;

  @override
  State<DocumentTemplatesPage> createState() => _DocumentTemplatesPageState();
}

class _DocumentTemplatesPageState extends State<DocumentTemplatesPage> {
  late final WorkflowAutomationRepository repository = widget.repository ??
      WorkflowAutomationRepository(context.read<FrappeApiClient>());
  String kind = 'custom';
  String query = '';
  String? module;
  List<DocumentTemplate> rows = const [];
  String? error;
  bool loading = true;
  int request = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await repository.templates(
          company: widget.company, kind: kind, module: module, search: query);
      if (mounted && current == request) setState(() => rows = value);
    } catch (e) {
      if (mounted && current == request) {
        setState(() => error = e is ApiException
            ? e.message
            : 'دریافت الگوها ممکن نشد؛ دوباره تلاش کنید.');
      }
    } finally {
      if (mounted && current == request) setState(() => loading = false);
    }
  }

  Future<void> open([DocumentTemplate? template]) async {
    final saved = await Navigator.push<DocumentTemplate>(
        context,
        MaterialPageRoute(
            builder: (_) => DocumentTemplateWizardPage(
                company: widget.company,
                repository: repository,
                initial: template)));
    if (saved != null && mounted) {
      setState(() => kind = 'custom');
      await load();
    }
  }

  Future<void> toggle(DocumentTemplate template) async {
    try {
      await repository.setTemplateStatus(
          template.name, template.isActive ? 'Inactive' : 'Active');
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e is ApiException ? e.message : 'تغییر وضعیت الگو انجام نشد.')));
    }
  }

  Future<void> filter() async {
    const modules = {
      '': 'همه ماژول‌ها',
      'Finance': 'مالی',
      'Purchase': 'خرید',
    };
    final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final entry in modules.entries)
                ListTile(
                    title: Text(entry.value),
                    trailing: (module ?? '') == entry.key
                        ? const Icon(Icons.check_rounded,
                            color: AsoudColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, entry.key)),
            ])));
    if (choice == null) return;
    setState(() => module = choice.isEmpty ? null : choice);
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(
            title: 'الگوهای سند',
            action: IconButton(
                tooltip: 'راهنما',
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AlertDialog(
                        title: Text('الگوی سند'),
                        content: Text(
                            'الگو مشخص می‌کند در مرحله «اقدام خودکار» گردش کار، '
                            'کدام سند ERPNext و با چه مقادیری ساخته شود.'))),
                icon: const Icon(Icons.help_outline_rounded))),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AsoudSegmentedControl<String>(
              value: kind,
              options: const [
                AsoudSegmentedOption(value: 'custom', label: 'الگوهای سفارشی'),
                AsoudSegmentedOption(value: 'ready', label: 'الگوهای آماده'),
              ],
              onChanged: (next) {
                setState(() => kind = next);
                load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                      hintText: 'جستجو در الگوها...',
                      prefixIcon: Icon(Icons.search_rounded)),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => query = value,
                  onSubmitted: (_) => load(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                  tooltip: 'فیلتر',
                  onPressed: filter,
                  icon: Icon(Icons.filter_alt_outlined,
                      color: module == null
                          ? AsoudColors.muted
                          : AsoudColors.primary)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(error!, textAlign: TextAlign.center),
                        TextButton(
                            onPressed: load, child: const Text('تلاش دوباره')),
                      ]))
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          children: [
                            if (rows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                    kind == 'custom'
                                        ? 'هنوز الگویی ساخته نشده است.'
                                        : 'الگوی آماده‌ای یافت نشد.',
                                    textAlign: TextAlign.center),
                              ),
                            for (final template in rows)
                              _TemplateCard(
                                template: template,
                                onTap: () => open(template),
                                onToggle: template.isReady
                                    ? null
                                    : () => toggle(template),
                              ),
                          ],
                        ),
                      ),
          ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: () => open(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('ایجاد الگوی جدید'),
            ),
          ),
        ),
      );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard(
      {required this.template, required this.onTap, this.onToggle});
  final DocumentTemplate template;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final visual = templateVisual(template);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            AsoudIconBox(icon: visual.icon, color: visual.color, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                        template.description.isEmpty
                            ? template.documentType
                            : template.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AsoudColors.muted)),
                  ]),
            ),
            if (template.isReady)
              const TemplateChip('آماده', color: AsoudColors.primary)
            else if (!template.isActive)
              const TemplateChip('غیرفعال', color: AsoudColors.muted)
            else
              const TemplateChip('سفارشی'),
            if (onToggle == null)
              const Icon(Icons.chevron_left_rounded, color: AsoudColors.muted)
            else
              PopupMenuButton<String>(
                tooltip: 'عملیات',
                onSelected: (_) => onToggle!(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                          template.isActive ? 'غیرفعال‌سازی' : 'فعال‌سازی')),
                ],
              ),
          ]),
        ),
      ),
    );
  }
}
