import 'package:flutter/material.dart';
import 'dart:math';

import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:asoud_erp/core/widgets/states.dart';
import 'package:asoud_erp/features/hr/data/hr_contracts_repository.dart';
import 'package:asoud_erp/features/hr/data/hr_contract_template_repository.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import 'hr_contract_print_page.dart';

class HrContractIssuePage extends StatefulWidget {
  const HrContractIssuePage({
    required this.company,
    required this.repository,
    required this.templateRepository,
    this.initialDraft,
    super.key,
  });

  final String company;
  final HrContractsRepository repository;
  final HrContractTemplateRepository templateRepository;
  final HrContractRecord? initialDraft;

  @override
  State<HrContractIssuePage> createState() => _HrContractIssuePageState();
}

class _HrContractIssuePageState extends State<HrContractIssuePage> {
  final _formKey = GlobalKey<FormState>();
  late final String _clientId = widget.initialDraft?.clientId ??
      List.generate(24, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  late String? _savedContractId = widget.initialDraft?.id;

  bool loading = true;
  bool saving = false;
  String? errorMessage;
  String? loadError;

  late HrContractTemplate template;
  List<EmployeeOption> staffList = [];

  EmployeeOption? selectedEmployee;
  Map<String, int?> currentSalaries = {};

  String contractKind = 'مدت‌معین';
  final TextEditingController startDateController =
      TextEditingController(text: toPersianDigits(JalaliDate.fromDateTime(DateTime.now()).format()));
  final TextEditingController endDateController =
      TextEditingController();
  final TextEditingController workplaceController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  int? openClauseIndex;

  static const List<String> contractKinds = [
    'مدت‌معین',
    'غیرمدت‌معین',
    'کار معین',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    workplaceController.dispose();
    subjectController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final t = await widget.templateRepository.getTemplate(company: widget.company);
      final staff = await widget.repository.getStaffList(company: widget.company);

      if (mounted) {
        setState(() {
          template = t;
          staffList = staff;
          loading = false;
        });

        if (widget.initialDraft != null) {
          final draft = widget.initialDraft!;
          contractKind = draft.kind;
          startDateController.text = draft.startDate;
          endDateController.text = draft.endDate ?? '';
          workplaceController.text = draft.workplace;
          subjectController.text = draft.subject ?? '';
          notesController.text = draft.notes ?? '';

          final match = staff.where((s) => s.id == draft.staffId).firstOrNull;
          if (match != null) {
            _onEmployeeSelected(match, initialSalaries: draft.salaries);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadError = failureDetail(e);
          loading = false;
        });
      }
    }
  }

  Future<void> _onEmployeeSelected(EmployeeOption employee,
      {Map<String, int?>? initialSalaries}) async {
    setState(() {
      selectedEmployee = employee;
      currentSalaries = initialSalaries ?? {};
    });

    if (initialSalaries == null) {
      try {
        final salaries = await widget.repository.getStaffSalaries(
          company: widget.company,
          staffId: employee.id,
        );
        if (mounted && selectedEmployee?.id == employee.id) {
          setState(() {
            currentSalaries = salaries;
          });
        }
      } catch (_) {}
    }
  }

  String _formatMoney(int? amount) {
    if (amount == null) return 'اطلاعات موجود نیست';
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return '${toPersianDigits(buffer.toString())} ریال';
  }

  bool _isSalaryValid() {
    if (selectedEmployee == null) return false;
    final monthlyRows =
        template.payrollRows.where((r) => r.period == 'monthly').toList();
    return monthlyRows.every((r) =>
        currentSalaries.containsKey(r.fieldRef) &&
        currentSalaries[r.fieldRef] != null);
  }

  int _calculateMonthlyTotal() {
    final monthlyRows =
        template.payrollRows.where((r) => r.period == 'monthly').toList();
    return monthlyRows.fold<int>(
      0,
      (sum, r) => sum + (currentSalaries[r.fieldRef] ?? 0),
    );
  }

  HrContractRecord _buildContractRecord({required String status}) {
    final employee = selectedEmployee!;
    return HrContractRecord(
      clientId: _clientId,
      id: _savedContractId ?? 'شماره پس از صدور',
      staffId: employee.id,
      employeeName: employee.name,
      employeeCode: employee.code,
      unit: employee.unit,
      jobTitle: employee.jobTitle,
      kind: contractKind,
      status: status,
      startDate: startDateController.text.trim(),
      endDate: contractKind == 'مدت‌معین' ? endDateController.text.trim() : null,
      workplace: workplaceController.text.trim(),
      subject: contractKind == 'کار معین' ? subjectController.text.trim() : null,
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      salaries: currentSalaries,
      templateVersion: template.version,
      snapshotClauses: template.clauses,
      snapshotPayrollRows: template.payrollRows,
    );
  }

  String? _startDateError(String? value) {
    if (value == null || value.trim().isEmpty) return 'تاریخ شروع الزامی است.';
    return parseJalaliDate(value) == null ? 'تاریخ شروع معتبر نیست.' : null;
  }

  String? _endDateError(String? value) {
    if (value == null || value.trim().isEmpty) return 'تاریخ پایان الزامی است.';
    final end = parseJalaliDate(value);
    if (end == null) return 'تاریخ پایان معتبر نیست.';
    final start = parseJalaliDate(startDateController.text);
    return start != null && end.isBefore(start)
        ? 'تاریخ پایان نباید پیش از تاریخ شروع باشد.' : null;
  }

  bool _validateDates() {
    final message = _startDateError(startDateController.text) ??
        (contractKind == 'مدت‌معین' ? _endDateError(endDateController.text) : null);
    if (message == null) return true;
    setState(() => errorMessage = message);
    return false;
  }

  Future<void> _saveDraft() async {
    if (saving) return;
    if (selectedEmployee == null) {
      setState(() => errorMessage = 'برای ثبت پیش‌نویس، ابتدا پرسنل را انتخاب کنید.');
      return;
    }
    if (!_validateDates()) return;
    setState(() {
      saving = true;
      errorMessage = null;
    });

    try {
      final record = _buildContractRecord(status: 'پیش‌نویس');
      await widget.repository.saveDraftContract(
        company: widget.company,
        draft: record,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = failureMessage(error));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _submitFinal() async {
    if (saving) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => errorMessage = 'لطفاً فیلدهای الزامی را تکمیل کنید.');
      return;
    }
    if (selectedEmployee == null) {
      setState(() => errorMessage = 'انتخاب پرسنل الزامی است.');
      return;
    }
    if (!_isSalaryValid()) {
      setState(() => errorMessage =
          'یکی از فیلدهای حقوقی ناقص است. قبل از ثبت نهایی باید مقادیر حقوقی تکمیل شوند.');
      return;
    }

    setState(() {
      saving = true;
      errorMessage = null;
    });

    try {
      final record = _buildContractRecord(status: 'نهایی');
      await widget.repository.submitContract(
        company: widget.company,
        draft: record,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = failureMessage(error));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openPrintPreview() async {
    if (saving) return;
    if (selectedEmployee == null) {
      setState(() => errorMessage = 'برای پیش‌نمایش، ابتدا پرسنل را انتخاب کنید.');
      return;
    }
    if (!_validateDates()) return;
    final record = _buildContractRecord(
        status: widget.initialDraft?.status ?? 'پیش‌نویس');
    setState(() => saving = true);
    try {
    final saved = await widget.repository.saveDraftContract(company: widget.company, draft: record);
    _savedContractId = saved.id;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HrContractPrintPage(
          contract: saved,
          template: template,
          loadPayload: () => widget.repository.getPrintPayload(company: widget.company, id: saved.id),
        ),
      ),
    );
    } catch (error) {
      if (mounted) setState(() => errorMessage = failureMessage(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: 'ایجاد قرارداد کار',
          subtitle: widget.company,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
            ? ErrorState(failure: loadError!, onRetry: _load)
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6FC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD7E8F7)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'قالب قرارداد کار آماده است',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'مواد و اتصال فیلدها از فرم‌ساز سند بارگذاری شده‌اند؛ در این صفحه قابل طراحی نیستند.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AsoudColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ۱. مشخصات طرفین
                    _buildSectionCard(
                      icon: Icons.person_outline,
                      title: '۱. مشخصات طرفین',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedEmployee?.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'انتخاب پرسنل *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          hint: const Text('انتخاب پرسنل...'),
                          items: staffList
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(
                                      '${s.name} (${s.code})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (id) {
                            if (id != null) {
                              final staff =
                                  staffList.firstWhere((s) => s.id == id);
                              _onEmployeeSelected(staff);
                            }
                          },
                          validator: (v) =>
                              v == null ? 'انتخاب پرسنل الزامی است.' : null,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'اطلاعات سیستمی',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('نام و نام خانوادگی',
                                  selectedEmployee?.name ?? 'پس از انتخاب'),
                              _buildInfoRow('کد پرسنلی',
                                  selectedEmployee?.code ?? 'پس از انتخاب'),
                              _buildInfoRow('واحد',
                                  selectedEmployee?.unit ?? 'پس از انتخاب'),
                              _buildInfoRow('جایگاه شغلی',
                                  selectedEmployee?.jobTitle ?? 'پس از انتخاب'),
                              _buildInfoRow(
                                  'کارفرما', 'از تنظیمات سازمان'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ۲. شرایط قرارداد
                    _buildSectionCard(
                      icon: Icons.grid_view,
                      title: '۲. شرایط قرارداد',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: contractKind,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'نوع قرارداد',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: contractKinds
                              .map((k) =>
                                  DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => contractKind = v);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: startDateController,
                                decoration: const InputDecoration(
                                  labelText: 'شروع (شمسی)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                validator: _startDateError,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: contractKind == 'مدت‌معین'
                                  ? TextFormField(
                                      controller: endDateController,
                                      decoration: const InputDecoration(
                                        labelText: 'پایان (شمسی)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      validator: _endDateError,
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'مطابق نوع قرارداد',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B)),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: workplaceController,
                          decoration: const InputDecoration(
                            labelText: 'محل انجام کار *',
                            hintText: 'محل خدمت یا کارگاه',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'محل انجام کار الزامی است.'
                              : null,
                        ),
                        if (contractKind == 'کار معین') ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: subjectController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'موضوع کار معین',
                              hintText: 'شرح کار موردنظر',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'موضوع کار معین الزامی است.'
                                : null,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ۳. ماده ۴ ـ حقوق و مزایا
                    _buildSectionCard(
                      icon: Icons.attach_money,
                      title: '۳. ماده ۴ ـ حقوق و مزایا',
                      subtitle: 'از ردیف‌های متصل‌شده در فرم‌ساز سند',
                      children: [
                        for (int i = 0; i < template.payrollRows.length; i++) ...[
                          _buildSalaryRow(i, template.payrollRows[i]),
                          const SizedBox(height: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'جمع اقلام ماهانه',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  selectedEmployee != null && _isSalaryValid()
                                      ? _formatMoney(_calculateMonthlyTotal())
                                      : 'ناقص',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedEmployee != null &&
                                            _isSalaryValid()
                                        ? AsoudColors.primary
                                        : Colors.orange,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedEmployee != null && !_isSalaryValid()) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF87171)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 16, color: Colors.red),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'یکی از فیلدهای حقوقی داده ندارد و قبل از صدور نهایی باید در منبع اصلی بررسی شود.',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFF991B1B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ۴. مفاد قرارداد (Read-only view)
                    _buildSectionCard(
                      icon: Icons.description_outlined,
                      title: '۴. مفاد قرارداد',
                      subtitle:
                          'مواد مصوب فقط جهت مشاهده هستند؛ تغییر قالب در این صفحه انجام نمی‌شود.',
                      children: [
                        for (int i = 0; i < template.clauses.length; i++) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      openClauseIndex = openClauseIndex == i
                                          ? null
                                          : i;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            toPersianDigits('${i + 1}'),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            template.clauses[i].title,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Icon(
                                          openClauseIndex == i
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          size: 18,
                                          color: AsoudColors.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (openClauseIndex == i)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        10, 0, 10, 10),
                                    child: Text(
                                      template.clauses[i].body,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.5,
                                          color: Color(0xFF475569)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'شروط اختصاصی مجاز',
                            hintText: 'شرط یا توضیح مجاز برای این قرارداد',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving ? null : _openPrintPreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('◉ پیش‌نمایش چاپ'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AsoudColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving ? null : _saveDraft,
                            child: const Text('ذخیره پیش‌نویس'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: saving ? null : _submitFinal,
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('ثبت نهایی'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: AsoudColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(int index, HrPayrollTableRow row) {
    final value = currentSalaries[row.fieldRef];
    final isMissing = selectedEmployee != null && value == null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMissing ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${toPersianDigits('${index + 1}')}. ${row.name}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Text('ماهانه',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('مبلغ (ریال)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  selectedEmployee != null
                      ? _formatMoney(value)
                      : 'پس از انتخاب',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMissing ? Colors.red : const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
