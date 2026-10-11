import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/data/workflow_automation_repository.dart';
import '../../../workflows/domain/entities/document_template.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/domain/repositories/workflow_repository.dart';
import '../../../workflows/presentation/pages/document_template_wizard_page.dart';
import '../../domain/request_templates.dart';
import '../cubit/request_type_builder_cubit.dart';
import 'request_type_builder_page.dart';

/// Shared management entry. Legacy editors remain intact until a versioned
/// schema and server-side publication contract can replace them safely.
class FormsManagementPage extends StatefulWidget {
  const FormsManagementPage({required this.company, super.key});
  final String company;

  @override
  State<FormsManagementPage> createState() => _FormsManagementPageState();
}

class _FormsManagementPageState extends State<FormsManagementPage> {
  late final documents = WorkflowAutomationRepository(
    context.read<FrappeApiClient>(),
  );
  final search = TextEditingController();
  bool documentTab = false, loading = true;
  String module = '', status = '', query = '';
  String? error;
  int revision = 0;
  List<WorkflowDefinition> requests = [];
  List<DocumentTemplate> templates = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final current = ++revision;
    final target = documentTab;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (target) {
        final rows = await documents.templates(
          company: widget.company,
          kind: 'custom',
        );
        if (!mounted || current != revision) return;
        setState(() => templates = rows);
      } else {
        final rows = await context.read<WorkflowRepository>().getWorkflows(
          company: widget.company,
        );
        if (!mounted || current != revision) return;
        setState(
          () => requests = rows
              .where((r) => r.targetDoctype == requestTargetDoctype)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted && current == revision) {
        setState(
          () => error =
              'دریافت فرم‌ها ممکن نشد؛ اتصال و مجوز دسترسی را بررسی کنید.',
        );
      }
    } finally {
      if (mounted && current == revision) setState(() => loading = false);
    }
  }

  String requestStatus(WorkflowDefinition item) => switch (item.status) {
    WorkflowDefinitionStatus.active => 'فعال',
    WorkflowDefinitionStatus.archived => 'بایگانی',
    WorkflowDefinitionStatus.inactive => 'غیرفعال',
  };

  Future<void> editRequest([
    WorkflowDefinition? item,
    RequestTemplate? preset,
  ]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RequestTypeBuilderPage(
          company: widget.company,
          existing: item,
          template: preset,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> editDocument([DocumentTemplate? item]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<DocumentTemplate>(
        builder: (_) => DocumentTemplateWizardPage(
          company: widget.company,
          repository: documents,
          initial: item,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> create() async {
    var type = documentTab;
    var ready = false;
    final choice = await showModalBottomSheet<(bool, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ایجاد فرم جدید',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'بستن',
                        onPressed: () => Navigator.pop(sheet),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  AsoudSegmentedControl<bool>(
                    value: type,
                    options: const [
                      AsoudSegmentedOption(value: false, label: 'درخواست'),
                      AsoudSegmentedOption(value: true, label: 'سند'),
                    ],
                    onChanged: (value) => update(() => type = value),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    selected: !ready,
                    leading: Icon(
                      !ready
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: const Text('ساخت از صفر'),
                    onTap: () => update(() => ready = false),
                  ),
                  ListTile(
                    selected: ready,
                    leading: Icon(
                      ready
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: const Text('قالب آماده آسود'),
                    onTap: () => update(() => ready = true),
                  ),
                  if (type)
                    const Text(
                      'در این نسخه، فرم سند الگوی ساخت سند و نگاشت فیلدهاست؛ قواعد سند اصلی تغییر نمی‌کنند.',
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheet, (type, ready)),
                    child: const Text('ادامه'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      documentTab = choice.$1;
      module = '';
      status = '';
    });
    await load();
    if (!mounted) return;
    if (!choice.$2) {
      if (choice.$1) {
        await editDocument();
      } else {
        await editRequest();
      }
      return;
    }
    if (choice.$1) {
      try {
        final rows = await documents.templates(
          company: widget.company,
          kind: 'ready',
        );
        if (!mounted) return;
        final picked = await pick<DocumentTemplate>(
          'قالب‌های سند',
          rows,
          (r) => r.title,
        );
        if (picked != null && mounted) await editDocument(picked);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('دریافت قالب‌ها ممکن نشد.')),
          );
        }
      }
    } else {
      final picked = await pick<RequestTemplate>(
        'قالب‌های درخواست',
        requestTemplates,
        (r) => r.info.title,
      );
      if (picked != null && mounted) await editRequest(null, picked);
    }
  }

  Future<T?> pick<T>(String title, List<T> rows, String Function(T) label) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .65,
            child: Column(
              children: [
                ListTile(
                  title: Text(title),
                  trailing: IconButton(
                    tooltip: 'بستن',
                    onPressed: () => Navigator.pop(sheet),
                    icon: const Icon(Icons.close),
                  ),
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('قالب قابل استفاده‌ای موجود نیست.'),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text(label(row)),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => Navigator.pop(sheet, row),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  void details(String title, String description) => showDialog<void>(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(description)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final repository = context.read<WorkflowRepository>();
    final local = documentTab
        ? documents.isLocal
        : repository is OfflinePreviewAware &&
              (repository as OfflinePreviewAware).isOfflinePreview;
    final modules =
        (documentTab
                ? templates.map((r) => r.module)
                : requests.map((r) => r.moduleKey ?? ''))
            .where((m) => m.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final requestRows = requests
        .where(
          (r) =>
              r.title.contains(query) &&
              (module.isEmpty || r.moduleKey == module) &&
              (status.isEmpty || requestStatus(r) == status),
        )
        .toList();
    final documentRows = templates
        .where(
          (r) =>
              r.title.contains(query) &&
              (module.isEmpty || r.module == module) &&
              (status.isEmpty || (r.isActive ? 'فعال' : 'غیرفعال') == status),
        )
        .toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: 'مدیریت فرم‌ها',
          subtitle: widget.company,
          action: IconButton(
            tooltip: 'بازخوانی',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (local) const AsoudOfflinePreviewBanner(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AsoudSegmentedControl<bool>(
                      value: documentTab,
                      options: const [
                        AsoudSegmentedOption(value: false, label: 'درخواست‌ها'),
                        AsoudSegmentedOption(value: true, label: 'سندها'),
                      ],
                      onChanged: (value) {
                        setState(() {
                          documentTab = value;
                          module = '';
                          status = '';
                        });
                        load();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: search,
                      onChanged: (value) =>
                          setState(() => query = value.trim()),
                      decoration: const InputDecoration(
                        hintText: 'جستجوی نام فرم',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final selected = await pick<String>(
                              'ماژول',
                              ['', ...modules],
                              (v) =>
                                  v.isEmpty ? 'همه ماژول‌ها' : _moduleTitle(v),
                            );
                            if (selected != null && mounted) {
                              setState(() => module = selected);
                            }
                          },
                          child: Text(
                            module.isEmpty
                                ? 'همه ماژول‌ها'
                                : _moduleTitle(module),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final selected = await pick<String>('وضعیت فعلی', [
                              '',
                              'فعال',
                              'غیرفعال',
                              if (!documentTab) 'بایگانی',
                            ], (v) => v.isEmpty ? 'همه وضعیت‌ها' : v);
                            if (selected != null && mounted) {
                              setState(() => status = selected);
                            }
                          },
                          child: Text(status.isEmpty ? 'همه وضعیت‌ها' : status),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'فعال بودن در نسخه فعلی، به معنی انتشار نسخه ساختاری فرم نیست. انتشار نسخه‌دار هنوز آماده نیست.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(error!),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    if (documentTab
                        ? documentRows.isEmpty
                        : requestRows.isEmpty)
                      const Text('فرمی با این فیلترها پیدا نشد.'),
                    if (!documentTab)
                      for (final row in requestRows)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(row.title),
                            subtitle: Text(
                              '${_moduleTitle(row.moduleKey ?? '')} · ${requestStatus(row)}',
                            ),
                            onTap: () => details(
                              row.title,
                              row.description ?? 'بدون توضیح',
                            ),
                            trailing: IconButton(
                              tooltip: 'ویرایش',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed:
                                  row.status == WorkflowDefinitionStatus.active
                                  ? () => details(
                                      'محافظت از فرم فعال',
                                      'نسخه‌بندی ساختار هنوز آماده نیست؛ ویرایش مستقیم فرم فعال از این صفحه انجام نمی‌شود.',
                                    )
                                  : () => editRequest(row),
                            ),
                          ),
                        ),
                    if (documentTab)
                      for (final row in documentRows)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: Text(row.title),
                            subtitle: Text(
                              '${_moduleTitle(row.module)} · ${row.isActive ? 'فعال' : 'غیرفعال'}',
                            ),
                            onTap: () => details(
                              row.title,
                              row.description.isEmpty
                                  ? 'الگوی نگاشت و ساخت سند'
                                  : row.description,
                            ),
                            trailing: IconButton(
                              tooltip: 'ویرایش الگو',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: row.isActive
                                  ? () => details(
                                      'محافظت از الگوی فعال',
                                      'برای حفظ رفتار گردش‌های موجود، ویرایش نسخه فعال از این صفحه مسدود است تا نسخه‌بندی تکمیل شود.',
                                    )
                                  : () => editDocument(row),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        ),
        bottomNavigationBar: AsoudBottomActions(
          primaryLabel: '+ ایجاد فرم جدید',
          onPrimary: create,
        ),
      ),
    );
  }
}

String _moduleTitle(String key) => switch (key) {
  'Finance' || 'Accounting' => 'مالی',
  'Purchase' => 'خرید',
  'Sales' => 'فروش',
  'HR' => 'منابع انسانی',
  'Inventory' || 'Stock' => 'انبار',
  'Support' => 'پشتیبانی',
  '' => 'عمومی',
  _ => key,
};
