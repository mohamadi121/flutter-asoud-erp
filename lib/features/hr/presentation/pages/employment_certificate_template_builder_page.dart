import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/employment_certificate_repository.dart';

class EmploymentCertificateTemplateBuilderPage extends StatefulWidget {
  const EmploymentCertificateTemplateBuilderPage({
    required this.company,
    this.canManageTemplate = false,
    super.key,
  });
  final String company;
  final bool canManageTemplate;

  @override
  State<EmploymentCertificateTemplateBuilderPage> createState() => _EmploymentCertificateTemplateBuilderPageState();
}

class _EmploymentCertificateTemplateBuilderPageState extends State<EmploymentCertificateTemplateBuilderPage> {
  late final EmploymentCertificateRepository _repository =
      RepositoryProvider.of<EmploymentCertificateRepository>(context, listen: false);

  int _tabIndex = 0; // 0: Editor, 1: Preview
  bool _loading = true;
  String? _error;
  bool _saving = false;

  int _revision = 1;
  String _status = 'Draft';
  bool _salaryEnabled = false;
  List<CertificateClause> _clauses = [];
  List<SalaryRowDefinition> _salaryRows = [];

  int? _editingIndex;
  final Set<int> _expandedClauses = {0, 1, 2, 3};
  String _selectedDrawerGroup = 'personnel';
  String _drawerSearchQuery = '';

  static const _drawerGroupLabels = {
    'personnel': 'اطلاعات پرسنل',
    'company': 'مشخصات شرکت',
    'decree': 'اطلاعات گواهی',
    'payroll': 'حقوق و دستمزد',
  };

  static const _catalogGroups = {
    'personnel': [
      'نام کامل پرسنل',
      'کد پرسنلی',
      'کد ملی',
      'عنوان شغلی',
      'واحد سازمانی',
      'تاریخ شروع همکاری',
      'نوع قرارداد',
      'محل خدمت',
      'شماره شناسنامه',
    ],
    'company': [
      'نام شرکت',
      'شناسه ملی شرکت',
      'شماره ثبت',
      'نشانی قانونی شرکت',
      'کد پستی شرکت',
      'تلفن شرکت',
    ],
    'decree': [
      'شماره گواهی',
      'تاریخ صدور گواهی',
      'گیرنده گواهی',
      'هدف صدور گواهی',
      'مدت اعتبار گواهی',
    ],
    'payroll': [
      'حقوق پایه',
      'حق مسکن',
      'بن خواربار',
      'حق جذب',
      'پایه سنوات',
      'سایر مزایا',
    ],
  };

  static const _tokenMap = {
    'نام کامل پرسنل': '{{employee.employee_name}}',
    'کد پرسنلی': '{{employee.employee_number}}',
    'کد ملی': '{{employee.national_id}}',
    'عنوان شغلی': '{{employee.designation}}',
    'واحد سازمانی': '{{employee.department}}',
    'تاریخ شروع همکاری': '{{employee.date_of_joining}}',
    'نوع قرارداد': '{{employee.contract_type}}',
    'محل خدمت': '{{employee.work_location}}',
    'شماره شناسنامه': '{{employee.id_number}}',
    'نام شرکت': '{{company.company_name}}',
    'شناسه ملی شرکت': '{{company.tax_id}}',
    'شماره ثبت': '{{company.registration_number}}',
    'نشانی قانونی شرکت': '{{company.address}}',
    'کد پستی شرکت': '{{company.postal_code}}',
    'تلفن شرکت': '{{company.phone}}',
    'شماره گواهی': '{{certificate.number}}',
    'تاریخ صدور گواهی': '{{certificate.issue_date}}',
    'گیرنده گواهی': '{{certificate.addressee_name}}',
    'هدف صدور گواهی': '{{certificate.purpose}}',
    'مدت اعتبار گواهی': '{{certificate.validity}}',
    'حقوق پایه': '{{payroll.base}}',
    'حق مسکن': '{{payroll.housing}}',
    'بن خواربار': '{{payroll.food}}',
    'حق جذب': '{{payroll.merit}}',
    'پایه سنوات': '{{payroll.seniority}}',
    'سایر مزایا': '{{payroll.other}}',
  };

  final _editTitleController = TextEditingController();
  final _editBodyController = TextEditingController();

  final _newTitleController = TextEditingController();
  final _newBodyController = TextEditingController();
  bool _showNewClauseForm = false;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _editTitleController.dispose();
    _editBodyController.dispose();
    _newTitleController.dispose();
    _newBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tmpl = await _repository.getTemplate(company: widget.company);
      if (!mounted) return;
      setState(() {
        _revision = tmpl.revision;
        _status = tmpl.status;
        _salaryEnabled = tmpl.salaryEnabled;
        _clauses = List.from(tmpl.clauses);
        _salaryRows = List.from(tmpl.salaryRows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failureMessage(e);
      });
    }
  }

  void _beginEditClause(int index) {
    setState(() {
      _editingIndex = index;
      _expandedClauses.add(index);
      _editTitleController.text = _clauses[index].title;
      _editBodyController.text = _clauses[index].body;
      _showNewClauseForm = false;
    });
  }

  void _saveEditClause() {
    final title = _editTitleController.text.trim();
    final body = _editBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عنوان و متن بند را کامل کنید.')));
      return;
    }

    setState(() {
      _clauses[_editingIndex!] = _clauses[_editingIndex!].copyWith(title: title, body: body);
      _editingIndex = null;
    });
  }

  void _insertPlaceholder(TextEditingController controller, String token) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, token);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void _showPlaceholderPicker(TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final fields = _catalogGroups[_selectedDrawerGroup] ?? const [];
            final filtered = fields.where((f) => f.contains(_drawerSearchQuery.trim())).toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storage_rounded, size: 18, color: AsoudColors.primary),
                              SizedBox(width: 8),
                              Text('انتخاب فیلد موجود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDrawerGroup,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'گروه فیلدها', isDense: true, border: OutlineInputBorder()),
                        items: _drawerGroupLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() => _selectedDrawerGroup = v);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'نام فیلد را جست‌وجو کنید...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setSheetState(() => _drawerSearchQuery = v),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final field = filtered[idx];
                            final token = _tokenMap[field] ?? '[$field]';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.add_circle_outline, size: 18, color: AsoudColors.primary),
                              title: Text(field, style: const TextStyle(fontSize: 13)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('درج', style: TextStyle(fontSize: 11, color: AsoudColors.primary)),
                              ),
                              onTap: () {
                                _insertPlaceholder(controller, token);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addNewClause() {
    final title = _newTitleController.text.trim();
    final body = _newBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عنوان و متن بند جدید را وارد کنید.')));
      return;
    }

    final id = 'clause_${DateTime.now().millisecondsSinceEpoch % 100000}';
    setState(() {
      _clauses.add(CertificateClause(id: id, title: title, body: body, enabled: true));
      _newTitleController.clear();
      _newBodyController.clear();
      _showNewClauseForm = false;
    });
  }

  void _moveClause(int index, int dir) {
    final newIndex = index + dir;
    if (newIndex < 0 || newIndex >= _clauses.length) return;
    setState(() {
      final item = _clauses.removeAt(index);
      _clauses.insert(newIndex, item);
      _editingIndex = null;
    });
  }

  void _deleteClause(int index) {
    setState(() {
      _clauses.removeAt(index);
      if (_editingIndex == index) _editingIndex = null;
    });
  }

  Future<void> _saveDraft() async {
    if (!widget.canManageTemplate) return;
    setState(() => _saving = true);
    try {
      final updated = await _repository.saveTemplateDraft(
        company: widget.company,
        revision: _revision,
        clauses: _clauses,
        salaryEnabled: _salaryEnabled,
        salaryRows: _salaryRows,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _revision = updated.revision;
        _status = updated.status;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پیش‌نویس قالب با موفقیت ذخیره شد.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = failureMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _publish() async {
    if (!widget.canManageTemplate) return;
    setState(() => _saving = true);
    try {
      final updated = await _repository.publishTemplate(
        company: widget.company,
        revision: _revision,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _revision = updated.revision;
        _status = updated.status;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قالب با موفقیت منتشر شد.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = failureMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: const AsoudHeader(title: 'قالب گواهی اشتغال به کار', subtitle: 'کتابخانه اسناد پرسنلی'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: const AsoudHeader(title: 'قالب گواهی اشتغال به کار', subtitle: 'کتابخانه اسناد پرسنلی'),
        body: ErrorState(failure: _error!, onRetry: _loadTemplate),
      );
    }

    return Scaffold(
      appBar: const AsoudHeader(title: 'قالب گواهی اشتغال به کار', subtitle: 'کتابخانه اسناد پرسنلی'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'ویرایش قالب',
                      active: _tabIndex == 0,
                      onTap: () => setState(() => _tabIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TabButton(
                      label: 'پیش‌نمایش سند',
                      active: _tabIndex == 1,
                      onTap: () => setState(() => _tabIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tabIndex == 0 ? _buildEditor() : _buildPreview(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'وضعیت قالب: ${_status == 'Published' ? 'منتشرشده' : 'پیش‌نویس'} (نسخه ${toPersianDigits(_revision)})',
                style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _status == 'Published' ? AsoudColors.successSurface : AsoudColors.warningSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _status == 'Published' ? 'منتشرشده' : 'پیش‌نویس',
                style: TextStyle(fontSize: 10, color: _status == 'Published' ? AsoudColors.success : AsoudColors.warning, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Settings Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تنظیمات قالب گواهی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('درج اطلاعات حقوق و درآمد در گواهی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('اختیاری؛ فقط در صورت مجوز قانونی و با استناد به داده‌های حقوق و دستمزد.', style: TextStyle(fontSize: 10)),
                  value: _salaryEnabled,
                  onChanged: (val) {
                    setState(() {
                      _salaryEnabled = val;
                      if (val && _salaryRows.isEmpty) {
                        _salaryRows.add(const SalaryRowDefinition(id: 'base', title: 'حقوق پایه', fieldRef: 'payroll.base', period: 'monthly'));
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Clauses Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('بندهای متن گواهی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${_clauses.length} بند', style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
                  ],
                ),
                const SizedBox(height: 12),

                for (int i = 0; i < _clauses.length; i++) ...[
                  _buildClauseItem(i),
                  const SizedBox(height: 8),
                ],

                if (_showNewClauseForm) ...[
                  _buildNewClauseForm(),
                ] else ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('افزودن بند جدید'),
                    onPressed: () => setState(() => _showNewClauseForm = true),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Bottom Actions
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AsoudColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: !widget.canManageTemplate || _saving ? null : _saveDraft,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('ذخیره پیش‌نویس قالب'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AsoudColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: !widget.canManageTemplate || _saving ? null : _publish,
          child: const Text('انتشار قالب'),
        ),
      ],
    );
  }

  Widget _buildClauseItem(int i) {
    final c = _clauses[i];
    final isEditing = _editingIndex == i;
    final isExpanded = _expandedClauses.contains(i);
    final isSalaryClause = c.id == 'clause_salary' || c.id == '4' || i == 3;

    return Container(
      decoration: BoxDecoration(
        color: isEditing ? const Color(0xFFF8FAFC) : Colors.white,
        border: Border.all(
          color: isEditing ? AsoudColors.primary : const Color(0xFFE4EAF1),
          width: isEditing ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedClauses.remove(i);
                } else {
                  _expandedClauses.add(i);
                }
              });
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFEDF5FC),
                  child: Text(
                    toPersianDigits('${i + 1}'),
                    style: const TextStyle(fontSize: 11, color: AsoudColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AsoudColors.muted,
                  size: 18,
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            if (isEditing) ...[
              // Inline edit form directly under the article
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F9FD),
                  border: Border.all(color: const Color(0xFF8DBDEB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ویرایش بند ${toPersianDigits('${i + 1}')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _editTitleController,
                      decoration: const InputDecoration(labelText: 'عنوان بند', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _editBodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'متن بند', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('درج فیلد در متن بند'),
                      onPressed: () => _showPlaceholderPicker(_editBodyController),
                    ),
                    if (isSalaryClause && _salaryEnabled) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('جدول اختیاری حقوق و درآمد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 8),
                            for (int rIdx = 0; rIdx < _salaryRows.length; rIdx++) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('ردیف ${toPersianDigits('${rIdx + 1}')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: AsoudColors.danger),
                                          onPressed: () => setState(() => _salaryRows.removeAt(rIdx)),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: _salaryRows[rIdx].title,
                                      decoration: const InputDecoration(labelText: 'عنوان قلم درآمدی', isDense: true, border: OutlineInputBorder()),
                                      onChanged: (val) => _salaryRows[rIdx] = _salaryRows[rIdx].copyWith(title: val),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('فیلد متصل: ${_salaryRows[rIdx].fieldRef}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      initialValue: _salaryRows[rIdx].period,
                                      decoration: const InputDecoration(labelText: 'دوره پرداخت', isDense: true, border: OutlineInputBorder()),
                                      items: const [
                                        DropdownMenuItem(value: 'monthly', child: Text('ماهانه')),
                                        DropdownMenuItem(value: 'annual', child: Text('سالانه')),
                                        DropdownMenuItem(value: 'once', child: Text('یک‌باره')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _salaryRows[rIdx] = _salaryRows[rIdx].copyWith(period: val));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('افزودن ردیف درآمدی'),
                              onPressed: () {
                                setState(() {
                                  _salaryRows.add(SalaryRowDefinition(
                                    id: 'row_${DateTime.now().millisecondsSinceEpoch % 10000}',
                                    title: 'قلم درآمدی جدید',
                                    fieldRef: 'payroll.base',
                                    period: 'monthly',
                                  ));
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _saveEditClause,
                          style: ElevatedButton.styleFrom(backgroundColor: AsoudColors.primary, foregroundColor: Colors.white),
                          child: const Text('ذخیره تغییرات'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(() => _editingIndex = null),
                          child: const Text('انصراف'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(c.body, style: const TextStyle(fontSize: 11, color: AsoudColors.muted, height: 1.6)),
              if (isSalaryClause && _salaryEnabled) ...[
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('جدول اختیاری حقوق و درآمد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      for (int rIdx = 0; rIdx < _salaryRows.length; rIdx++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${toPersianDigits('${rIdx + 1}')}. ${_salaryRows[rIdx].title}', style: const TextStyle(fontSize: 11)),
                              Text(
                                switch (_salaryRows[rIdx].period) {
                                  'monthly' => 'ماهانه',
                                  'annual' => 'سالانه',
                                  'once' => 'یک‌باره',
                                  _ => 'ماهانه',
                                },
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.arrow_upward, size: 16), onPressed: i > 0 ? () => _moveClause(i, -1) : null),
                  IconButton(icon: const Icon(Icons.arrow_downward, size: 16), onPressed: i < _clauses.length - 1 ? () => _moveClause(i, 1) : null),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('ویرایش'),
                    onPressed: () => _beginEditClause(i),
                  ),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AsoudColors.danger), onPressed: () => _deleteClause(i)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNewClauseForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FD),
        border: Border.all(color: const Color(0xFF8DBDEB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('افزودن بند جدید', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          TextFormField(controller: _newTitleController, decoration: const InputDecoration(labelText: 'عنوان بند', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 8),
          TextFormField(controller: _newBodyController, maxLines: 4, decoration: const InputDecoration(labelText: 'متن بند', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('درج فیلد در بند جدید'),
            onPressed: () => _showPlaceholderPicker(_newBodyController),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _addNewClause,
                style: ElevatedButton.styleFrom(backgroundColor: AsoudColors.primary, foregroundColor: Colors.white),
                child: const Text('افزودن بند'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _showNewClauseForm = false),
                child: const Text('انصراف'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD6DFE9)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.business, color: Color(0xFF243F60), size: 28),
                  SizedBox(width: 8),
                  Text('سربرگ سازمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF243F60))),
                ],
              ),
              const Divider(color: Color(0xFFB8C6D3), height: 24),
              const Center(
                child: Text('گواهی اشتغال به کار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF243F60))),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text('پیش‌نمایش قالب ـ فاقد اعتبار نهایی', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9EACBC))),
              ),
              const SizedBox(height: 16),
              for (final c in _clauses) ...[
                if (c.enabled) ...[
                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(c.body, style: const TextStyle(fontSize: 11, height: 1.8)),
                  const SizedBox(height: 12),
                ],
              ],
              if (_salaryEnabled && _salaryRows.isNotEmpty) ...[
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(color: const Color(0xFFD6DFE9)),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF0F3F7)),
                      children: const [
                        Padding(padding: EdgeInsets.all(6), child: Text('عنوان قلم', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(6), child: Text('دوره', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(6), child: Text('مبلغ (ریال)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    for (final r in _salaryRows) ...[
                      TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text(r.title, style: const TextStyle(fontSize: 10))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(switch (r.period) { 'monthly' => 'ماهانه', 'annual' => 'سالانه', 'once' => 'یک‌باره', _ => 'ماهانه' }, style: const TextStyle(fontSize: 10))),
                          Padding(padding: const EdgeInsets.all(6), child: Text('[${r.fieldRef}]', style: const TextStyle(fontSize: 10))),
                        ],
                      ),
                    ],
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: [
                        Padding(padding: EdgeInsets.all(6), child: Text('جمع اقلام ماهانه', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(6), child: Text('—', style: TextStyle(fontSize: 10))),
                        Padding(padding: EdgeInsets.all(6), child: Text('[محاسبه سیستم]', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AsoudColors.primary))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('نام و امضای مقام مجاز', style: TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                  Text('مهر شرکت', style: TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                ],
              ),
              const Divider(color: Color(0xFFB8C6D3), height: 32),
              const Center(child: Text('پابرگ و نشانی شرکت از تنظیمات سازمان', style: TextStyle(fontSize: 9, color: Color(0xFF748398)))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.print, size: 16),
          label: const Text('چاپ / ذخیره PDF پیش‌نمایش'),
          style: ElevatedButton.styleFrom(backgroundColor: AsoudColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پیش‌نمایش چاپ آماده است.')));
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => _tabIndex = 0),
          child: const Text('بازگشت به ویرایش قالب'),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AsoudColors.primary : const Color(0xFFEDF2F7),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : AsoudColors.muted,
          ),
        ),
      ),
    );
  }
}
