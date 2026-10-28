import 'package:flutter/material.dart';

import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import 'hr_contract_builder_widgets.dart';
import 'hr_contract_print_page.dart';

class HrContractBuilderPage extends StatefulWidget {
  const HrContractBuilderPage({
    required this.company,
    this.repository,
    this.canManageTemplate = false,
    super.key,
  });

  final String company;
  final HrContractTemplateRepository? repository;
  final bool canManageTemplate;

  @override
  State<HrContractBuilderPage> createState() => _HrContractBuilderPageState();
}

class _HrContractBuilderPageState extends State<HrContractBuilderPage> {
  late final HrContractTemplateRepository repository =
      widget.repository ?? FakeHrContractTemplateRepository();

  bool loading = true;
  String? error;
  late HrContractTemplate template;
  int currentTab = 0; // 0: template, 1: contract preview, 2: print preview

  Object? expandedClauseId;
  Object? editingClauseId;
  final TextEditingController editTitleController = TextEditingController();
  final TextEditingController editBodyController = TextEditingController();
  List<HrPayrollTableRow> draftPayrollRows = [];

  bool isNewArticleOpen = false;
  final TextEditingController newTitleController = TextEditingController();
  final TextEditingController newBodyController = TextEditingController();

  Map<String, List<String>> catalogFields = defaultCatalogGroups;
  List<HrPayrollFieldOption> payrollFields = defaultPayrollFields;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    editTitleController.dispose();
    editBodyController.dispose();
    newTitleController.dispose();
    newBodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final t = await repository.getTemplate(company: widget.company);
      final fields =
          await repository.getAvailableCatalogFields(company: widget.company);
      final pFields = await repository.getPayrollFields(company: widget.company);
      if (mounted) {
        setState(() {
          template = t;
          catalogFields = fields;
          payrollFields = pFields;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'دریافت قالب قرارداد انجام نشد؛ دوباره تلاش کنید.';
          loading = false;
        });
      }
    }
  }

  void _startEdit(HrContractClause clause) {
    setState(() {
      editingClauseId = clause.id;
      expandedClauseId = clause.id;
      isNewArticleOpen = false;
      editTitleController.text = clause.title;
      editBodyController.text = clause.body;
      draftPayrollRows = template.payrollRows.map((r) => r.copyWith()).toList();
    });
  }

  void _cancelEdit() {
    setState(() {
      editingClauseId = null;
      editTitleController.clear();
      editBodyController.clear();
      draftPayrollRows.clear();
    });
  }

  void _saveEdit() {
    if (editingClauseId == null) return;
    final updatedClauses = template.clauses.map((c) {
      if (c.id == editingClauseId) {
        return c.copyWith(
          title: editTitleController.text.trim(),
          body: editBodyController.text.trim(),
        );
      }
      return c;
    }).toList();

    setState(() {
      template = template.copyWith(
        clauses: updatedClauses,
        payrollRows: editingClauseId == 4 ? draftPayrollRows : template.payrollRows,
      );
      editingClauseId = null;
    });
    repository.saveDraft(company: widget.company, template: template);
  }

  void _saveNewArticle() {
    final title = newTitleController.text.trim();
    final body = newBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    final nextId = 'clause_${DateTime.now().microsecondsSinceEpoch}';
    final newClause = HrContractClause(id: nextId, title: title, body: body);

    setState(() {
      template = template.copyWith(
        clauses: [...template.clauses, newClause],
      );
      isNewArticleOpen = false;
      newTitleController.clear();
      newBodyController.clear();
      expandedClauseId = nextId;
    });
    repository.saveDraft(company: widget.company, template: template);
  }

  void _moveClause(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= template.clauses.length) return;

    final clauses = List<HrContractClause>.from(template.clauses);
    final item = clauses.removeAt(index);
    clauses.insert(newIndex, item);

    setState(() {
      template = template.copyWith(clauses: clauses);
    });
    repository.saveDraft(company: widget.company, template: template);
  }

  void _openInsertDrawer(TextEditingController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => InsertFieldDrawer(
        catalog: catalogFields,
        onFieldSelected: (tag) {
          final text = controller.text;
          final selection = controller.selection;
          if (selection.start >= 0 && selection.end >= selection.start) {
            final newText = text.replaceRange(
                selection.start, selection.end, ' $tag ');
            controller.text = newText;
            controller.selection = TextSelection.collapsed(
                offset: selection.start + tag.length + 2);
          } else {
            controller.text = '$text $tag';
          }
        },
      ),
    );
  }

  void _openSalaryPicker(Object rowId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SalaryPickerSheet(
        payrollFields: payrollFields,
        onSelected: (field) {
          setState(() {
            draftPayrollRows = draftPayrollRows.map((r) {
              if (r.id == rowId) {
                return r.copyWith(fieldRef: field.id, name: field.label);
              }
              return r;
            }).toList();
          });
        },
      ),
    );
  }

  void _addDraftPayrollRow() {
    final nextId = 'row_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      draftPayrollRows.add(HrPayrollTableRow(
        id: nextId,
        name: '',
        fieldRef: '',
        period: 'monthly',
      ));
    });
  }

  void _deleteDraftPayrollRow(Object rowId) {
    setState(() {
      draftPayrollRows.removeWhere((r) => r.id == rowId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: 'قالب قرارداد کار',
          subtitle: widget.company,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load, child: const Text('تلاش مجدد')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _TabButton(
                              label: 'قالب قرارداد',
                              isActive: currentTab == 0,
                              onTap: () => setState(() => currentTab = 0),
                            ),
                            const SizedBox(width: 8),
                            _TabButton(
                              label: 'قرارداد جدید',
                              isActive: currentTab == 1,
                              onTap: () => setState(() => currentTab = 1),
                            ),
                            const SizedBox(width: 8),
                            _TabButton(
                              label: 'چاپ پیش‌نویس',
                              isActive: currentTab == 2,
                              onTap: () => setState(() => currentTab = 2),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      Expanded(
                        child: currentTab == 0
                            ? _buildTemplateTab()
                            : currentTab == 1
                                ? _buildPreviewContractTab()
                                : _buildPrintPreviewTab(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTemplateTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!widget.canManageTemplate)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFF59E0B)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'دسترسی فقط‌خواندنی: شما به عنوان کارشناس منابع انسانی امکان مشاهده قالب را دارید؛ تغییر قالب نیازمند دسترسی مدیریت است.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.format_list_bulleted,
                    size: 18, color: AsoudColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'مواد قرارداد',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${toPersianDigits('${template.clauses.length}')})',
                  style: const TextStyle(
                      fontSize: 11, color: AsoudColors.muted),
                ),
              ],
            ),
            if (widget.canManageTemplate)
              InkWell(
                onTap: () {
                  repository.publishTemplate(
                      company: widget.company, template: template);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('نسخه جدید قالب با موفقیت منتشر شد.')),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    border: Border.all(color: AsoudColors.primary),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.publish, size: 14, color: AsoudColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'انتشار نسخه',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AsoudColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < template.clauses.length; i++) ...[
          ArticleCard(
            clause: template.clauses[i],
            index: i,
            isExpanded: expandedClauseId == template.clauses[i].id,
            isEditing: editingClauseId == template.clauses[i].id,
            canManage: widget.canManageTemplate,
            isFirst: i == 0,
            isLast: i == template.clauses.length - 1,
            payrollRows: template.payrollRows,
            onToggleExpand: () {
              setState(() {
                expandedClauseId = expandedClauseId == template.clauses[i].id
                    ? null
                    : template.clauses[i].id;
              });
            },
            onStartEdit: () => _startEdit(template.clauses[i]),
            onMoveUp: () => _moveClause(i, -1),
            onMoveDown: () => _moveClause(i, 1),
            editTitleController: editTitleController,
            editBodyController: editBodyController,
            draftPayrollRows: draftPayrollRows,
            onSaveEdit: _saveEdit,
            onCancelEdit: _cancelEdit,
            onOpenDrawer: _openInsertDrawer,
            onOpenSalaryPicker: _openSalaryPicker,
            onAddDraftPayrollRow: _addDraftPayrollRow,
            onDeleteDraftPayrollRow: _deleteDraftPayrollRow,
          ),
        ],
        if (widget.canManageTemplate) ...[
          const SizedBox(height: 8),
          if (isNewArticleOpen)
            NewArticleForm(
              titleController: newTitleController,
              bodyController: newBodyController,
              onSave: _saveNewArticle,
              onCancel: () => setState(() => isNewArticleOpen = false),
              onOpenDrawer: () => _openInsertDrawer(newBodyController),
            )
          else
            OutlinedButton.icon(
              onPressed: () => setState(() => isNewArticleOpen = true),
              icon: const Icon(Icons.add),
              label: const Text('افزودن ماده جدید'),
            ),
        ],
      ],
    );
  }

  Widget _buildPreviewContractTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AsoudColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'این صفحه پیش‌نمایشی از نحوه رندر قالب در زمان صدور قرارداد است.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < template.clauses.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ماده ${toPersianDigits('${i + 1}')} ـ ${template.clauses[i].title}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  template.clauses[i].body,
                  style: const TextStyle(
                      fontSize: 12, height: 1.6, color: Color(0xFF475569)),
                ),
                if (template.clauses[i].id == 4) ...[
                  const SizedBox(height: 8),
                  PayrollMiniTable(rows: template.payrollRows),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrintPreviewTab() {
    final sampleRecord = HrContractRecord(
      id: 'CRT-1405-021',
      staffId: 'p1',
      employeeName: 'پرسنل نمونه',
      employeeCode: 'HR-101',
      kind: 'مدت‌معین',
      status: 'پیش‌نویس',
      startDate: '۱۴۰۵/۰۱/۰۱',
      endDate: '۱۴۰۵/۱۲/۲۹',
      workplace: 'دفتر مرکزی',
      salaries: const {
        'payroll.base_salary': 235000000,
        'payroll.housing': 9000000,
        'payroll.food': 22000000,
      },
      templateVersion: template.version,
      snapshotClauses: template.clauses,
      snapshotPayrollRows: template.payrollRows,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HrContractPrintLayout(
        contract: sampleRecord,
        template: template,
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AsoudColors.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
