import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../data/workflow_automation_repository.dart';
import '../../domain/entities/document_template.dart';
import '../widgets/document_template_visuals.dart';
import 'document_template_wizard_page.dart';

/// The "Create Document" part of an automatic stage.
class CreateDocumentConfig {
  const CreateDocumentConfig({
    this.template,
    this.module = 'Finance',
    this.documentType = '',
    this.transferValues = true,
    this.remark = '',
  });
  final DocumentTemplate? template;
  final String module, documentType, remark;
  final bool transferValues;
}

/// «تنظیمات ایجاد سند»: target module, document type, template, data transfer.
class CreateDocumentSettingsPage extends StatefulWidget {
  const CreateDocumentSettingsPage({
    required this.company,
    required this.repository,
    this.initial = const CreateDocumentConfig(),
    this.sourceWorkflow,
    super.key,
  });
  final String company;
  final WorkflowAutomationRepository repository;
  final CreateDocumentConfig initial;
  final String? sourceWorkflow;

  @override
  State<CreateDocumentSettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<CreateDocumentSettingsPage> {
  DocumentTemplateOptions? options;
  String? error;
  late String module = widget.initial.module;
  late String documentType = widget.initial.documentType;
  late DocumentTemplate? template = widget.initial.template;
  late bool transfer = widget.initial.transferValues;
  late final remark = TextEditingController(text: widget.initial.remark);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    remark.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final value = await widget.repository.templateOptions(
          company: widget.company, workflow: widget.sourceWorkflow);
      if (!mounted) return;
      setState(() {
        options = value;
        if (documentType.isEmpty) {
          documentType = value
                  .module(module)
                  ?.types
                  .where((type) => type.enabled)
                  .map((type) => type.key)
                  .firstOrNull ??
              '';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'دریافت اطلاعات ماژول‌ها ممکن نشد.');
      }
    }
  }

  Future<void> pickModule() async {
    final current = options!.module(module);
    final choice = await Navigator.push<DocumentModule>(
        context,
        MaterialPageRoute(
            builder: (_) => ChoiceListPage<DocumentModule>(
                  title: 'انتخاب ماژول مقصد',
                  searchHint: 'جستجوی ماژول‌ها...',
                  items: options!.modules,
                  selected: current,
                  labelOf: (item) => item.label,
                  subtitleOf: (item) =>
                      item.available ? item.description : 'به‌زودی',
                  iconOf: (item) => moduleVisual(item.key),
                  enabledOf: (item) => item.available,
                )));
    if (choice == null || choice.key == module) return;
    setState(() {
      module = choice.key;
      documentType = choice.types
              .where((type) => type.enabled)
              .map((type) => type.key)
              .firstOrNull ??
          '';
      template = null;
    });
  }

  Future<void> pickType() async {
    final types = options!.module(module)?.types ?? const [];
    final choice = await Navigator.push<DocumentTypeOption>(
        context,
        MaterialPageRoute(
            builder: (_) => ChoiceListPage<DocumentTypeOption>(
                  title: 'انتخاب نوع سند',
                  searchHint: 'جستجوی نوع سند...',
                  items: types,
                  selected: types
                      .where((type) => type.key == documentType)
                      .firstOrNull,
                  labelOf: (item) => item.label,
                  subtitleOf: (item) => item.enabled ? '' : 'به‌زودی',
                  iconOf: (item) => documentTypeVisual(item.key),
                  enabledOf: (item) => item.enabled,
                )));
    if (choice == null || choice.key == documentType) return;
    setState(() {
      documentType = choice.key;
      template = null;
    });
  }

  Future<void> pickTemplate() async {
    final choice = await Navigator.push<DocumentTemplate>(
        context,
        MaterialPageRoute(
            builder: (_) => TemplatePickerPage(
                company: widget.company,
                repository: widget.repository,
                module: module,
                documentType: documentType,
                typeLabel: options!.typeLabel(documentType),
                sourceWorkflow: widget.sourceWorkflow,
                selected: template)));
    if (choice != null) setState(() => template = choice);
  }

  void save() {
    if (template == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الگوی سند را انتخاب کنید.')));
      return;
    }
    Navigator.pop(
        context,
        CreateDocumentConfig(
            template: template,
            module: module,
            documentType: documentType,
            transferValues: transfer,
            remark: remark.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final value = options;
    return Scaffold(
      appBar: const AsoudHeader(title: 'تنظیمات ایجاد سند'),
      body: value == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(error!, textAlign: TextAlign.center),
                      TextButton(
                          onPressed: load, child: const Text('تلاش دوباره')),
                    ]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AsoudColors.primary.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.integration_instructions_outlined,
                      color: AsoudColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'در این مرحله مشخص کنید از فرم درخواست چه سندی در سیستم ایجاد شود.',
                          style: TextStyle(fontSize: 12, height: 1.6))),
                ]),
              ),
              const SizedBox(height: 16),
              PickerField(
                label: 'ماژول مقصد',
                value: value.module(module)?.label ?? '',
                placeholder: 'انتخاب ماژول',
                icon: moduleVisual(module).icon,
                iconColor: moduleVisual(module).color,
                onTap: pickModule,
              ),
              const SizedBox(height: 12),
              PickerField(
                label: 'نوع سند',
                value:
                    documentType.isEmpty ? '' : value.typeLabel(documentType),
                placeholder: 'انتخاب نوع سند',
                icon: documentTypeVisual(documentType).icon,
                iconColor: documentTypeVisual(documentType).color,
                onTap: pickType,
              ),
              const SizedBox(height: 12),
              PickerField(
                label: 'الگوی سند',
                value: template?.title ?? '',
                placeholder: 'انتخاب الگو',
                icon: Icons.snippet_folder_outlined,
                onTap: documentType.isEmpty ? null : pickTemplate,
              ),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  title: const Text('انتقال اطلاعات',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text(
                      'مقادیر مورد نیاز از فرم درخواست قبل از ایجاد سند به صورت خودکار منتقل می‌شوند.',
                      style: TextStyle(fontSize: 11)),
                  value: transfer,
                  onChanged: (next) => setState(() => transfer = next),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remark,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                    labelText: 'توضیحات سند',
                    hintText: 'ایجاد خودکار بر اساس درخواست {{RequestNo}}',
                    alignLabelWithHint: true),
              ),
            ]),
      bottomNavigationBar: value == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child:
                    FilledButton(onPressed: save, child: const Text('ذخیره')),
              ),
            ),
    );
  }
}

/// «انتخاب الگوی سند»: ready or custom templates of one document type.
class TemplatePickerPage extends StatefulWidget {
  const TemplatePickerPage({
    required this.company,
    required this.repository,
    required this.module,
    required this.documentType,
    required this.typeLabel,
    this.sourceWorkflow,
    this.selected,
    super.key,
  });
  final String company, module, documentType, typeLabel;
  final WorkflowAutomationRepository repository;
  final String? sourceWorkflow;
  final DocumentTemplate? selected;

  @override
  State<TemplatePickerPage> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<TemplatePickerPage> {
  String kind = 'custom';
  String query = '';
  List<DocumentTemplate> rows = const [];
  late DocumentTemplate? selected = widget.selected;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.templates(
          company: widget.company,
          kind: kind,
          module: widget.module,
          documentType: widget.documentType);
      if (mounted) {
        setState(() =>
            rows = value.where((row) => row.isReady || row.isActive).toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = e is ApiException ? e.message : 'دریافت الگوها ممکن نشد.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Opens the wizard; a ready template is copied into a custom one there.
  Future<void> create([DocumentTemplate? preset]) async {
    final saved = await Navigator.push<DocumentTemplate>(
        context,
        MaterialPageRoute(
            builder: (_) => DocumentTemplateWizardPage(
                company: widget.company,
                repository: widget.repository,
                initial: preset,
                module: widget.module,
                documentType: widget.documentType,
                sourceWorkflow: widget.sourceWorkflow)));
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  void confirm() {
    final choice = selected;
    if (choice == null) return;
    if (choice.isReady) {
      create(choice);
    } else {
      Navigator.pop(context, choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where((row) => query.isEmpty || row.title.contains(query))
        .toList();
    return Scaffold(
      appBar: const AsoudHeader(title: 'انتخاب الگوی سند'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          AsoudPickerIcon(
              icon: documentTypeVisual(widget.documentType).icon,
              color: documentTypeVisual(widget.documentType).color),
          const SizedBox(width: 8),
          Expanded(
              child: Text('نوع سند: ${widget.typeLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تغییر')),
        ]),
        const SizedBox(height: 8),
        AsoudSegmentedControl<String>(
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
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(
              hintText: 'جستجوی الگوها...',
              prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (value) => setState(() => query = value.trim()),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()))
        else if (error != null)
          Column(children: [
            Text(error!, textAlign: TextAlign.center),
            TextButton(onPressed: load, child: const Text('تلاش دوباره')),
          ])
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
                kind == 'custom'
                    ? 'الگوی سفارشی برای این نوع سند ساخته نشده است.'
                    : 'الگوی آماده‌ای برای این نوع سند وجود ندارد.',
                textAlign: TextAlign.center),
          ),
        for (final row in visible)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: selected?.name == row.name
                ? AsoudColors.primary.withValues(alpha: .06)
                : null,
            child: ListTile(
              leading: AsoudPickerIcon(
                  icon: templateVisual(row).icon,
                  color: templateVisual(row).color),
              title: Text(row.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
              subtitle: Text(row.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11)),
              trailing: Icon(
                  selected?.name == row.name
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected?.name == row.name
                      ? AsoudColors.primary
                      : AsoudColors.border),
              onTap: () => setState(() => selected = row),
            ),
          ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          onPressed: () => create(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('ایجاد الگوی جدید'),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: selected == null ? null : confirm,
            child: Text(selected?.isReady == true
                ? 'تکمیل و انتخاب الگو'
                : 'تأیید انتخاب'),
          ),
        ),
      ),
    );
  }
}
