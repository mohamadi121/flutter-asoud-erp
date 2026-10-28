import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/personnel_introduction_letter_repository.dart';

class PersonnelIntroductionLetterTemplateBuilderPage extends StatefulWidget {
  const PersonnelIntroductionLetterTemplateBuilderPage({required this.company, super.key});
  final String company;

  @override
  State<PersonnelIntroductionLetterTemplateBuilderPage> createState() =>
      _PersonnelIntroductionLetterTemplateBuilderPageState();
}

class _PersonnelIntroductionLetterTemplateBuilderPageState
    extends State<PersonnelIntroductionLetterTemplateBuilderPage> {
  late final PersonnelIntroductionLetterRepository _repository =
      RepositoryProvider.of<PersonnelIntroductionLetterRepository>(context, listen: false);

  int _selectedTab = 0; // 0 = template, 1 = preview
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _canManageTemplate = false;

  int _revision = 1;
  String _status = 'Draft';
  bool _requiredRecipient = true;
  bool _requiredPurpose = true;
  bool _hasExpiry = false;
  List<IntroductionLetterClause> _clauses = [];

  // Clause editing
  int? _expandedIndex = 0;
  int? _editingIndex;
  final _editTitleController = TextEditingController();
  final _editBodyController = TextEditingController();

  // New clause
  bool _showNewClauseForm = false;
  final _newTitleController = TextEditingController();
  final _newBodyController = TextEditingController();

  // Preview sample inputs
  final _previewRecipientController = TextEditingController(text: 'بانک ملت ـ شعبه مرکزی');
  final _previewPurposeController = TextEditingController(text: 'افتتاح حساب بانکی');
  final _previewPersonController = TextEditingController(text: 'علی محمدی');
  final _previewDateController = TextEditingController(text: '۱۴۰۵/۰۹/۳۰');

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
    _previewRecipientController.dispose();
    _previewPurposeController.dispose();
    _previewPersonController.dispose();
    _previewDateController.dispose();
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
      if (!tmpl.canManageTemplate) {
        setState(() {
          _loading = false;
          _canManageTemplate = false;
          _error = 'دسترسی مدیریت قالب معرفی‌نامه برای شما فعال نیست.';
        });
        return;
      }
      setState(() {
        _canManageTemplate = tmpl.canManageTemplate;
        _revision = tmpl.revision;
        _status = tmpl.status;
        _requiredRecipient = tmpl.requiredRecipient;
        _requiredPurpose = tmpl.requiredPurpose;
        _hasExpiry = tmpl.hasExpiry;
        _clauses = List.from(tmpl.clauses);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'بارگذاری قالب ناموفق بود.';
      });
    }
  }

  void _beginEditClause(int index) {
    setState(() {
      _editingIndex = index;
      _expandedIndex = index;
      _editTitleController.text = _clauses[index].title;
      _editBodyController.text = _clauses[index].body;
      _showNewClauseForm = false;
    });
  }

  void _saveEditClause() {
    final title = _editTitleController.text.trim();
    final body = _editBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عنوان و متن بند را کامل کنید.')),
      );
      return;
    }

    setState(() {
      _clauses[_editingIndex!] = _clauses[_editingIndex!].copyWith(title: title, body: body);
      _editingIndex = null;
    });
  }

  void _addNewClause() {
    final title = _newTitleController.text.trim();
    final body = _newBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عنوان و متن بند را کامل کنید.')),
      );
      return;
    }

    final newId = 'clause_${_clauses.length + 1}';
    setState(() {
      _clauses.add(IntroductionLetterClause(id: newId, title: title, body: body, enabled: true));
      _showNewClauseForm = false;
      _newTitleController.clear();
      _newBodyController.clear();
      _expandedIndex = _clauses.length - 1;
    });
  }

  void _moveClause(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _clauses.length) return;
    setState(() {
      final item = _clauses.removeAt(fromIndex);
      _clauses.insert(toIndex, item);
      _expandedIndex = toIndex;
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        String activeCategory = 'personnel';

        final Map<String, List<Map<String, String>>> fieldGroups = {
          'personnel': [
            {'label': 'نام و نام خانوادگی پرسنل', 'token': '{{employee.employee_name}}'},
            {'label': 'کد پرسنلی', 'token': '{{employee.employee_number}}'},
            {'label': 'کد ملی', 'token': '{{employee.national_id}}'},
            {'label': 'عنوان شغلی', 'token': '{{employee.designation}}'},
            {'label': 'واحد سازمانی', 'token': '{{employee.department}}'},
            {'label': 'تاریخ استخدام', 'token': '{{employee.date_of_joining}}'},
            {'label': 'محل خدمت', 'token': '{{employee.work_location}}'},
            {'label': 'شماره همراه', 'token': '{{employee.cell_number}}'},
            {'label': 'نشانی محل سکونت', 'token': '{{employee.current_address}}'},
          ],
          'company': [
            {'label': 'نام قانونی شرکت', 'token': '{{company.company_name}}'},
            {'label': 'نام نماینده قانونی', 'token': '{{company.representative}}'},
            {'label': 'سمت نماینده قانونی', 'token': '{{company.representative_position}}'},
            {'label': 'نشانی شرکت', 'token': '{{company.address}}'},
            {'label': 'تلفن شرکت', 'token': '{{company.phone}}'},
            {'label': 'شناسه ملی شرکت', 'token': '{{company.national_id}}'},
          ],
          'letter': [
            {'label': 'نام مرجع دریافت‌کننده', 'token': '{{letter.recipient}}'},
            {'label': 'هدف معرفی‌نامه', 'token': '{{letter.purpose}}'},
            {'label': 'توضیحات اختصاصی معرفی‌نامه', 'token': '{{letter.notes}}'},
            {'label': 'شماره معرفی‌نامه', 'token': '{{letter.number}}'},
            {'label': 'تاریخ صدور معرفی‌نامه', 'token': '{{letter.issue_date}}'},
            {'label': 'تاریخ اعتبار معرفی‌نامه', 'token': '{{letter.validity_date}}'},
            {'label': 'نام بانک مقصد', 'token': '{{letter.bank_name}}'},
            {'label': 'نام شعبه مقصد', 'token': '{{letter.branch_name}}'},
          ],
        };

        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeList = fieldGroups[activeCategory] ?? [];
            final filtered = activeList.where((f) {
              final q = query.toLowerCase().trim();
              return f['label']!.toLowerCase().contains(q) || f['token']!.toLowerCase().contains(q);
            }).toList();

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'انتخاب فیلد پویا جهت درج در بند',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('پرسنل', style: TextStyle(fontSize: 11)),
                            selected: activeCategory == 'personnel',
                            onSelected: (val) {
                              if (val) setModalState(() => activeCategory = 'personnel');
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('شرکت', style: TextStyle(fontSize: 11)),
                            selected: activeCategory == 'company',
                            onSelected: (val) {
                              if (val) setModalState(() => activeCategory = 'company');
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('معرفی‌نامه', style: TextStyle(fontSize: 11)),
                            selected: activeCategory == 'letter',
                            onSelected: (val) {
                              if (val) setModalState(() => activeCategory = 'letter');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'جست‌وجوی فیلد...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) => setModalState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('فیلدی یافت نشد.', style: TextStyle(fontSize: 11)),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filtered.map((f) {
                                  return ActionChip(
                                    label: Text(f['label']!, style: const TextStyle(fontSize: 11)),
                                    avatar: const Icon(Icons.add, size: 16, color: AsoudColors.primary),
                                    onPressed: () {
                                      _insertPlaceholder(controller, f['token']!);
                                      Navigator.of(ctx).pop();
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveDraft() async {
    if (!_canManageTemplate || _saving) return;
    setState(() => _saving = true);
    try {
      final res = await _repository.saveTemplateDraft(
        company: widget.company,
        revision: _revision,
        clauses: _clauses,
        requiredRecipient: _requiredRecipient,
        requiredPurpose: _requiredPurpose,
        hasExpiry: _hasExpiry,
      );
      if (!mounted) return;
      setState(() {
        _revision = res.revision;
        _status = res.status;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیش‌نویس قالب با موفقیت ذخیره شد.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'ذخیره پیش‌نویس قالب با خطا مواجه شد.')),
      );
    }
  }

  Future<void> _publish() async {
    if (!_canManageTemplate || _saving) return;
    setState(() => _saving = true);
    try {
      final res = await _repository.publishTemplate(
        company: widget.company,
        revision: _revision,
      );
      if (!mounted) return;
      setState(() {
        _revision = res.revision;
        _status = res.status;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قالب معرفی‌نامه با موفقیت منتشر گردید.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'انتشار قالب با خطا مواجه شد.')),
      );
    }
  }

  Widget _buildSettingsSection() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF5FC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune, color: Color(0xFF2379BE), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنظیمات قالب معرفی‌نامه',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF243F60)),
                      ),
                      Text(
                        'سند قابل صدور برای بانک‌ها و سازمان‌ها',
                        style: TextStyle(fontSize: 10, color: Color(0xFF748398)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _requiredRecipient,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('تعیین مخاطب هنگام صدور الزامی باشد', style: TextStyle(fontSize: 11)),
              onChanged: (val) => setState(() => _requiredRecipient = val ?? true),
            ),
            CheckboxListTile(
              value: _requiredPurpose,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('تعیین هدف معرفی‌نامه الزامی باشد', style: TextStyle(fontSize: 11)),
              onChanged: (val) => setState(() => _requiredPurpose = val ?? true),
            ),
            CheckboxListTile(
              value: _hasExpiry,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('نمایش تاریخ اعتبار معرفی‌نامه در پیش‌نمایش', style: TextStyle(fontSize: 11)),
              onChanged: (val) => setState(() => _hasExpiry = val ?? false),
            ),
            const Divider(height: 16),
            const Text(
              'شماره و تاریخ سند، نام مرجع، هدف معرفی و مشخصات کارمند از فیلدهای متصل تکمیل می‌شوند. این سند به‌صورت پیش‌فرض شامل ضمانت مالی یا افشای حقوق کارکنان نیست.',
              style: TextStyle(fontSize: 10, color: Color(0xFF748398), height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClauseCard(int index, IntroductionLetterClause clause) {
    final isExpanded = _expandedIndex == index;
    final isEditing = _editingIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing ? const Color(0xFF8DBDEB) : const Color(0xFFE4EAF1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
                if (!isExpanded) _editingIndex = null;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF5FC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFF2379BE),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      clause.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF748398),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE8ECF2)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _editTitleController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان بند',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _editBodyController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'متن بند',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: const Text('درج فیلد در متن بند', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(foregroundColor: AsoudColors.primary),
                          onPressed: () => _showPlaceholderPicker(_editBodyController),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AsoudColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _saveEditClause,
                                child: const Text('ذخیره تغییرات'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _editingIndex = null),
                                child: const Text('انصراف'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          clause.body,
                          style: const TextStyle(fontSize: 11, height: 1.8, color: Color(0xFF42556B)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              onPressed: index > 0 ? () => _moveClause(index, index - 1) : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward, size: 16),
                              onPressed: index < _clauses.length - 1 ? () => _moveClause(index, index + 1) : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('ویرایش', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AsoudColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () => _beginEditClause(index),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClausesSection() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF5FC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.format_list_numbered, color: Color(0xFF2379BE), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بندهای متن معرفی‌نامه',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF243F60)),
                      ),
                      Text(
                        '${_clauses.length} بند قابل تنظیم',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF748398)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < _clauses.length; i++) _buildClauseCard(i, _clauses[i]),
            if (_showNewClauseForm)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8DBDEB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('افزودن بند جدید', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newTitleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان بند',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newBodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'متن بند',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('درج فیلد در متن بند جدید', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(foregroundColor: AsoudColors.primary),
                      onPressed: () => _showPlaceholderPicker(_newBodyController),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AsoudColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _addNewClause,
                            child: const Text('افزودن بند'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _showNewClauseForm = false),
                            child: const Text('انصراف'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('افزودن بند جدید'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AsoudColors.primary,
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _showNewClauseForm = true;
                    _editingIndex = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTab() {
    String resolveTokens(String text) {
      final map = {
        '{{letter.recipient}}': _previewRecipientController.text,
        '{{letter.purpose}}': _previewPurposeController.text,
        '{{employee.employee_name}}': _previewPersonController.text,
        '{{letter.validity_date}}': _previewDateController.text,
        '{{employee.national_id}}': '[کد ملی]',
        '{{employee.employee_number}}': '[کد پرسنلی]',
        '{{employee.designation}}': '[عنوان شغلی]',
        '{{employee.department}}': '[واحد سازمانی]',
        '{{company.company_name}}': '[نام شرکت]',
        '{{company.representative}}': '[نماینده قانونی]',
        '{{company.representative_position}}': '[سمت نماینده]',
        '{{letter.notes}}': '[توضیحات اختصاصی]',
        '{{letter.number}}': '[شماره]',
        '{{letter.issue_date}}': '[تاریخ صدور]',
        '[نام مرجع دریافت‌کننده]': _previewRecipientController.text,
        '[هدف معرفی‌نامه]': _previewPurposeController.text,
        '[نام و نام خانوادگی پرسنل]': _previewPersonController.text,
      };

      var res = text;
      for (final entry in map.entries) {
        res = res.replaceAll(entry.key, entry.value);
      }
      return res;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('اطلاعات نمونه برای پیش‌نمایش سند', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _previewRecipientController,
                    decoration: const InputDecoration(
                      labelText: 'مخاطب نمونه',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _previewPurposeController,
                    decoration: const InputDecoration(
                      labelText: 'هدف نمونه',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _previewPersonController,
                    decoration: const InputDecoration(
                      labelText: 'نام پرسنل نمونه',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD6DFE9)),
              boxShadow: const [
                BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.corporate_fare, color: Color(0xFF2379BE), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'سربرگ سازمان',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF243F60)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                const Text(
                  'معرفی‌نامه پرسنل',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF243F60)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'پیش‌نمایش قالب ـ فاقد اعتبار نهایی',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9EACBC)),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('شماره: [شماره معرفی‌نامه]', style: TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                    Text('تاریخ: [تاریخ صدور]', style: TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                  ],
                ),
                if (_hasExpiry) ...[
                  const SizedBox(height: 4),
                  Text(
                    'اعتبار تا: ${_previewDateController.text}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF62768C)),
                  ),
                ],
                const SizedBox(height: 14),
                for (int i = 0; i < _clauses.length; i++) ...[
                  if (_clauses[i].enabled) ...[
                    Text(
                      '${i + 1}. ${_clauses[i].title}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF243F60)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resolveTokens(_clauses[i].body),
                      style: const TextStyle(fontSize: 11, height: 1.8, color: Color(0xFF42556B)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('نام و امضای مقام مجاز', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('مهر شرکت', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'پابرگ و اطلاعات شرکت از تنظیمات مشترک چاپ ASOUD ERP',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Color(0xFF748398)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('چاپ / ذخیره PDF پیش‌نمایش'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AsoudColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('چاپ در حالت پیش‌نمایش قالب ذخیره شد.')),
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _selectedTab = 0),
            child: const Text('بازگشت به ویرایش قالب'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: 'قالب معرفی‌نامه پرسنل',
          subtitle: 'کتابخانه اسناد / ویرایش قالب (نسخه $_revision)',
          action: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _status == 'Published' ? AsoudColors.successSurface : const Color(0xFFEDF0F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _status == 'Published' ? 'منتشرشده' : 'پیش‌نویس',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _status == 'Published' ? AsoudColors.success : const Color(0xFF62768C),
                ),
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(
                    failure: _error!,
                    onRetry: _loadTemplate,
                  )
                : Column(
                    children: [
                      Container(
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _selectedTab == 0 ? AsoudColors.primary : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'ویرایش قالب',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                                        color: _selectedTab == 0 ? AsoudColors.primary : const Color(0xFF62768C),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _selectedTab == 1 ? AsoudColors.primary : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'پیش‌نمایش سند',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                                        color: _selectedTab == 1 ? AsoudColors.primary : const Color(0xFF62768C),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _selectedTab == 1
                            ? _buildPreviewTab()
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildSettingsSection(),
                                    const SizedBox(height: 14),
                                    _buildClausesSection(),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.save_outlined, size: 18),
                                      label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره پیش‌نویس قالب'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AsoudColors.primary,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: _saving ? null : _saveDraft,
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.publish_outlined, size: 18),
                                      label: const Text('انتشار نسخه رسمی قالب'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AsoudColors.primary,
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: _saving ? null : _publish,
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.preview_outlined, size: 18),
                                      label: const Text('مشاهده پیش‌نمایش سند'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => setState(() => _selectedTab = 1),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
