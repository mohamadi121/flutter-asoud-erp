import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/employment_certificate_repository.dart';
import 'employment_certificate_preview_page.dart';

class EmploymentCertificateFormPage extends StatefulWidget {
  const EmploymentCertificateFormPage({
    required this.company,
    this.initialCertificateName = '',
    super.key,
  });

  final String company;
  final String initialCertificateName;

  @override
  State<EmploymentCertificateFormPage> createState() => _EmploymentCertificateFormPageState();
}

class _EmploymentCertificateFormPageState extends State<EmploymentCertificateFormPage> {
  late final EmploymentCertificateRepository _repository =
      RepositoryProvider.of<EmploymentCertificateRepository>(context, listen: false);

  bool _loading = true;
  String? _error;
  bool _saving = false;

  EmploymentCertificateTemplate? _template;
  List<Map<String, dynamic>> _employees = const [];

  String _selectedEmployee = '';
  final _addresseeNameController = TextEditingController();
  final _addresseeTypeController = TextEditingController(text: 'بانک');
  final _addresseeTitleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  String _purpose = 'ارائه به بانک';
  bool _includeSalary = false;
  int _revision = 0;
  String _certificateName = '';

  int? _expandedClauseIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _addresseeNameController.dispose();
    _addresseeTypeController.dispose();
    _addresseeTitleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tmplFuture = _repository.getTemplate(company: widget.company);
      final empFuture = _repository.getEmployeeOptions(company: widget.company);
      final certFuture = widget.initialCertificateName.isNotEmpty
          ? _repository.getCertificate(name: widget.initialCertificateName)
          : null;

      final tmpl = await tmplFuture;
      final emps = await empFuture;
      final cert = certFuture != null ? await certFuture : null;

      if (!mounted) return;

      setState(() {
        _template = tmpl;
        _employees = emps;
        if (cert != null) {
          _certificateName = cert.name;
          _selectedEmployee = cert.employee;
          _addresseeNameController.text = cert.addresseeName;
          _addresseeTypeController.text = cert.addresseeType;
          _addresseeTitleController.text = cert.addresseeTitle;
          _locationController.text = cert.location;
          _notesController.text = cert.notes;
          _purpose = cert.purpose.isNotEmpty ? cert.purpose : 'ارائه به بانک';
          _includeSalary = cert.hasSalary;
          _revision = cert.revision;
        } else if (emps.isNotEmpty) {
          _selectedEmployee = emps.first['name']?.toString() ?? '';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'بارگذاری اطلاعات با خطا مواجه شد؛ لطفاً دوباره تلاش کنید.';
      });
    }
  }

  Map<String, dynamic>? get _currentEmployeeInfo {
    if (_selectedEmployee.isEmpty) return null;
    return _employees.firstWhere(
      (e) => e['name']?.toString() == _selectedEmployee,
      orElse: () => const {},
    );
  }

  String _resolveClauseText(String body) {
    final emp = _currentEmployeeInfo;
    var resolved = body;
    resolved = resolved.replaceAll('{{certificate.addressee_name}}', _addresseeNameController.text.isNotEmpty ? _addresseeNameController.text : '[گیرنده گواهی]');
    resolved = resolved.replaceAll('{{certificate.purpose}}', _purpose);
    resolved = resolved.replaceAll('{{company.company_name}}', widget.company);
    resolved = resolved.replaceAll('{{employee.employee_name}}', emp?['employee_name']?.toString() ?? '[نام پرسنل]');
    resolved = resolved.replaceAll('{{employee.employee_number}}', emp?['name']?.toString() ?? '[کد پرسنلی]');
    resolved = resolved.replaceAll('{{employee.national_id}}', '[کد ملی]');
    resolved = resolved.replaceAll('{{employee.designation}}', emp?['designation']?.toString() ?? '[عنوان شغلی]');
    resolved = resolved.replaceAll('{{employee.date_of_joining}}', emp?['date_of_joining']?.toString() ?? '[تاریخ شروع]');
    return resolved;
  }

  Future<void> _saveDraft({bool navigateToPreview = false}) async {
    if (_selectedEmployee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً پرسنل را انتخاب کنید.')));
      return;
    }
    if (_addresseeNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نام دقیق مخاطب گواهی الزامی است.')));
      return;
    }

    setState(() => _saving = true);

    try {
      final reqKey = 'draft-${widget.company}-$_selectedEmployee-${DateTime.now().millisecondsSinceEpoch}';
      final detail = await _repository.saveDraft(
        company: widget.company,
        employee: _selectedEmployee,
        addresseeType: _addresseeTypeController.text.trim(),
        addresseeName: _addresseeNameController.text.trim(),
        addresseeTitle: _addresseeTitleController.text.trim(),
        purpose: _purpose,
        requestKey: reqKey,
        revision: _revision,
        name: _certificateName,
        notes: _notesController.text.trim(),
        includeSalary: _includeSalary,
        location: _locationController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _certificateName = detail.name;
        _revision = detail.revision;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیش‌نویس گواهی با موفقیت ذخیره شد.')),
      );

      if (navigateToPreview) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmploymentCertificatePreviewPage(
              certificateName: detail.name,
              company: widget.company,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e is ApiException ? e.message : 'ذخیره پیش‌نویس ناموفق بود.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: const AsoudHeader(title: 'صدور گواهی اشتغال', subtitle: 'اسناد پرسنلی'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: const AsoudHeader(title: 'صدور گواهی اشتغال', subtitle: 'اسناد پرسنلی'),
        body: ErrorState(failure: _error!, onRetry: _loadData),
      );
    }

    final empInfo = _currentEmployeeInfo;
    final isSalaryAllowed = _template?.salaryEnabled == true;

    return Scaffold(
      appBar: AsoudHeader(
        title: _certificateName.isNotEmpty ? 'ویرایش گواهی اشتغال' : 'صدور گواهی اشتغال',
        subtitle: 'اسناد پرسنلی',
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBE9F5)),
              ),
              child: const Text(
                'قالب منتشرشده «گواهی اشتغال به کار» بارگذاری شده است. متن بندها و اتصال فیلدها در فرم‌ساز تعیین شده‌اند؛ در این صفحه مشخصات گواهی تکمیل می‌شود.',
                style: TextStyle(fontSize: 11, height: 1.8, color: Color(0xFF426886)),
              ),
            ),
            const SizedBox(height: 16),

            // Card 1: Employee
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('۱. مشخصات پرسنل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedEmployee.isNotEmpty ? _selectedEmployee : null,
                      decoration: const InputDecoration(
                        labelText: 'انتخاب پرسنل *',
                        border: OutlineInputBorder(),
                      ),
                      items: _employees.map((e) {
                        final name = e['employee_name']?.toString() ?? '';
                        final code = e['name']?.toString() ?? '';
                        return DropdownMenuItem(value: code, child: Text('$name ($code)'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedEmployee = val);
                      },
                    ),
                    if (empInfo != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(label: 'نام و نام خانوادگی', value: empInfo['employee_name']?.toString() ?? '—'),
                            _InfoRow(label: 'کد پرسنلی', value: empInfo['name']?.toString() ?? '—'),
                            _InfoRow(label: 'واحد سازمانی', value: empInfo['department']?.toString() ?? '—'),
                            _InfoRow(label: 'عنوان شغلی', value: empInfo['designation']?.toString() ?? '—'),
                            _InfoRow(label: 'تاریخ شروع به کار', value: empInfo['date_of_joining']?.toString() ?? '—'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Certificate details
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('۲. مشخصات گواهی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _purpose,
                      decoration: const InputDecoration(labelText: 'هدف صدور *', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'ارائه به بانک', child: Text('ارائه به بانک')),
                        DropdownMenuItem(value: 'ارائه به سفارت', child: Text('ارائه به سفارت')),
                        DropdownMenuItem(value: 'ارائه به سازمان', child: Text('ارائه به سازمان')),
                        DropdownMenuItem(value: 'سایر موارد', child: Text('سایر موارد')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _purpose = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addresseeNameController,
                      decoration: const InputDecoration(
                        labelText: 'نام دقیق مخاطب گواهی *',
                        hintText: 'مثلاً بانک ملت ـ شعبه مرکزی',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'محل خدمت',
                        hintText: 'مثلاً دفتر مرکزی تهران',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'توضیحات اختصاصی مجاز',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Salary section
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('۳. حقوق و درآمد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (isSalaryAllowed) ...[
                      SwitchListTile(
                        title: const Text('نمایش اطلاعات حقوق و درآمد در این گواهی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('فقط در صورت ضرورت و با مجوز قانونی؛ پیش‌فرض خاموش است.', style: TextStyle(fontSize: 10)),
                        value: _includeSalary,
                        onChanged: (val) => setState(() => _includeSalary = val),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'در قالب مصوب این شرکت، بخش حقوق و درآمد غیرفعال است. برای فعال‌سازی باید در فرم‌ساز قالب فعال شود.',
                          style: TextStyle(fontSize: 11, color: AsoudColors.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Clauses text preview
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('۴. متن گواهی (جهت مشاهده)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < (_template?.clauses.length ?? 0); i++) ...[
                      if (_template!.clauses[i].enabled) ...[
                        ExpansionTile(
                          key: Key('clause_$i'),
                          title: Text(_template!.clauses[i].title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          initiallyExpanded: _expandedClauseIndex == i,
                          onExpansionChanged: (open) => setState(() => _expandedClauseIndex = open ? i : null),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _resolveClauseText(_template!.clauses[i].body),
                                style: const TextStyle(fontSize: 11, height: 1.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Buttons
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AsoudColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _saving ? null : () => _saveDraft(navigateToPreview: true),
              child: const Text('بازبینی و پیش‌نمایش چاپ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _saveDraft(navigateToPreview: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('ذخیره پیش‌نویس'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('انصراف / بازگشت', style: TextStyle(color: AsoudColors.muted)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AsoudColors.muted)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
