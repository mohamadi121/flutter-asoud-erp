import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/personnel_introduction_letter_repository.dart';
import 'personnel_introduction_letter_preview_page.dart';

class PersonnelIntroductionLetterFormPage extends StatefulWidget {
  const PersonnelIntroductionLetterFormPage({
    required this.company,
    this.initialLetterName = '',
    super.key,
  });

  final String company;
  final String initialLetterName;

  @override
  State<PersonnelIntroductionLetterFormPage> createState() =>
      _PersonnelIntroductionLetterFormPageState();
}

class _PersonnelIntroductionLetterFormPageState
    extends State<PersonnelIntroductionLetterFormPage> {
  late final PersonnelIntroductionLetterRepository _repository =
      RepositoryProvider.of<PersonnelIntroductionLetterRepository>(context, listen: false);

  bool _loading = true;
  String? _error;
  bool _saving = false;
  final String _draftRequestKey = 'draft-${DateTime.now().microsecondsSinceEpoch}';
  final String _finalizeRequestKey = 'finalize-${DateTime.now().microsecondsSinceEpoch}';

  PersonnelIntroductionTemplate? _template;
  List<Map<String, dynamic>> _employees = const [];

  String _selectedEmployee = '';
  String _recipientType = 'bank';
  final _bankNameController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _purposeController = TextEditingController(text: 'افتتاح حساب');
  final _validityDateController = TextEditingController();
  final _notesController = TextEditingController();

  int _revision = 0;
  String _letterName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _branchNameController.dispose();
    _recipientNameController.dispose();
    _purposeController.dispose();
    _validityDateController.dispose();
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

      final tmpl = await tmplFuture;
      final emps = await empFuture;

      if (!mounted) return;
      _template = tmpl;
      _employees = emps;

      if (widget.initialLetterName.isNotEmpty) {
        final existing = await _repository.getLetter(name: widget.initialLetterName);
        if (!mounted) return;
        _letterName = existing.name;
        _selectedEmployee = existing.employee;
        _recipientType = existing.recipientType;
        _bankNameController.text = existing.bankName;
        _branchNameController.text = existing.branchName;
        _recipientNameController.text = existing.recipientName;
        _purposeController.text = existing.purpose;
        _validityDateController.text = existing.validityDate;
        _notesController.text = existing.notes;
        _revision = existing.revision;
      } else if (_employees.isNotEmpty) {
        _selectedEmployee = _employees.first['employee']?.toString() ??
            _employees.first['name']?.toString() ??
            '';
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'بارگذاری اطلاعات با خطا مواجه شد.';
      });
    }
  }

  Map<String, dynamic>? get _currentEmployeeInfo {
    for (final emp in _employees) {
      final id = emp['employee']?.toString() ?? emp['name']?.toString();
      if (id == _selectedEmployee) return emp;
    }
    return null;
  }

  String get _recipientDisplay {
    if (_recipientType == 'bank') {
      final bank = _bankNameController.text.trim();
      final branch = _branchNameController.text.trim();
      if (bank.isEmpty) return 'نام بانک تعیین نشده';
      return branch.isNotEmpty ? '$bank ـ شعبه $branch' : bank;
    }
    final rec = _recipientNameController.text.trim();
    return rec.isNotEmpty ? rec : 'مخاطب تعیین نشده';
  }

  Future<void> _saveDraft({bool andPreview = false, bool andFinalize = false}) async {
    if (_saving) return;
    if (_selectedEmployee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً پرسنل را انتخاب نمایید.')),
      );
      return;
    }

    final reqRecipient = _template?.requiredRecipient ?? true;
    final reqPurpose = _template?.requiredPurpose ?? true;

    if (reqRecipient) {
      if (_recipientType == 'bank' && _bankNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نام بانک الزامی است.')),
        );
        return;
      }
      if (_recipientType != 'bank' && _recipientNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نام مرجع دریافت‌کننده الزامی است.')),
        );
        return;
      }
    }

    if (reqPurpose && _purposeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هدف معرفی‌نامه الزامی است.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = await _repository.saveDraft(
        company: widget.company,
        employee: _selectedEmployee,
        recipientType: _recipientType,
        recipientName: _recipientNameController.text.trim(),
        bankName: _bankNameController.text.trim(),
        branchName: _branchNameController.text.trim(),
        purpose: _purposeController.text.trim(),
        validityDate: _validityDateController.text.trim(),
        notes: _notesController.text.trim(),
        requestKey: _draftRequestKey,
        revision: _revision,
        name: _letterName,
      );

      if (!mounted) return;
      setState(() {
        _letterName = draft.name;
        _revision = draft.revision;
      });

      if (andFinalize) {
        final finalRes = await _repository.finalizeLetter(
          name: draft.name,
          revision: draft.revision,
          requestKey: _finalizeRequestKey,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RepositoryProvider.value(
              value: _repository,
              child: PersonnelIntroductionLetterPreviewPage(
                letterName: finalRes.name,
                company: widget.company,
              ),
            ),
          ),
        );
        return;
      }

      if (andPreview) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RepositoryProvider.value(
              value: _repository,
              child: PersonnelIntroductionLetterPreviewPage(
                letterName: draft.name,
                company: widget.company,
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پیش‌نویس معرفی‌نامه با موفقیت ذخیره شد.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'ذخیره معرفی‌نامه با خطا مواجه شد.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showEmployeePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _employees.where((emp) {
              final name = emp['employee_name']?.toString() ?? '';
              final code = emp['employee_number']?.toString() ?? emp['name']?.toString() ?? '';
              final job = emp['designation']?.toString() ?? '';
              final query = filter.toLowerCase().trim();
              return name.toLowerCase().contains(query) ||
                  code.toLowerCase().contains(query) ||
                  job.toLowerCase().contains(query);
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
                      'انتخاب پرسنل جهت صدور معرفی‌نامه',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'جست‌وجوی نام، کد پرسنلی یا عنوان شغلی...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) {
                        setModalState(() => filter = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('پرسنلی با این مشخصات یافت نشد.', style: TextStyle(fontSize: 12)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, index) {
                                final emp = filtered[index];
                                final id = emp['employee']?.toString() ?? emp['name']?.toString() ?? '';
                                final name = emp['employee_name']?.toString() ?? 'نامشخص';
                                final code = emp['employee_number']?.toString() ?? id;
                                final job = emp['designation']?.toString() ?? '—';
                                final isSelected = id == _selectedEmployee;

                                return ListTile(
                                  dense: true,
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  subtitle: Text('$code ـ $job', style: const TextStyle(fontSize: 10)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: AsoudColors.primary, size: 20)
                                      : null,
                                  onTap: () {
                                    setState(() => _selectedEmployee = id);
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
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

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF62768C))),
          Text(
            value != null && value.isNotEmpty ? value : 'پس از انتخاب',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF243F60)),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonnelCard() {
    final emp = _currentEmployeeInfo;
    final name = emp?['employee_name']?.toString();
    final code = emp?['employee_number']?.toString() ?? emp?['name']?.toString();
    final nationalId = emp?['national_id']?.toString();
    final dept = emp?['department']?.toString();
    final job = emp?['designation']?.toString();
    final location = emp?['work_location']?.toString();

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
                  child: const Icon(Icons.person_outline, color: Color(0xFF2379BE), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '۱. مشخصات پرسنل',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF243F60)),
                      ),
                      Text(
                        'دریافت خودکار از پرونده منابع انسانی',
                        style: TextStyle(fontSize: 10, color: Color(0xFF748398)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('انتخاب', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _showEmployeePicker,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8ECF2)),
              ),
              child: Column(
                children: [
                  _buildInfoRow('نام و نام خانوادگی', name),
                  _buildInfoRow('کد ملی', nationalId),
                  _buildInfoRow('کد پرسنلی', code),
                  _buildInfoRow('واحد سازمانی', dept),
                  _buildInfoRow('عنوان شغلی', job),
                  _buildInfoRow('محل خدمت', location),
                  _buildInfoRow('کارفرما', 'از مشخصات شرکت'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientCard() {
    final reqRecipient = _template?.requiredRecipient ?? true;
    final reqPurpose = _template?.requiredPurpose ?? true;
    final hasExpiry = _template?.hasExpiry ?? false;

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
                  child: const Icon(Icons.domain_outlined, color: Color(0xFF2379BE), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '۲. مخاطب معرفی‌نامه',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF243F60)),
                      ),
                      Text(
                        'بانک، سازمان یا مرجع دیگر',
                        style: TextStyle(fontSize: 10, color: Color(0xFF748398)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _recipientType,
              decoration: const InputDecoration(
                labelText: 'نوع مرجع دریافت‌کننده',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'bank', child: Text('بانک')),
                DropdownMenuItem(value: 'organization', child: Text('سازمان / اداره')),
                DropdownMenuItem(value: 'other', child: Text('سایر مراجع')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _recipientType = val);
              },
            ),
            const SizedBox(height: 10),
            if (_recipientType == 'bank') ...[
              TextField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: reqRecipient ? 'نام بانک *' : 'نام بانک',
                  hintText: 'مثلاً بانک ملت، ملی، تجارت...',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _branchNameController,
                decoration: const InputDecoration(
                  labelText: 'نام شعبه (اختیاری)',
                  hintText: 'مثلاً شعبه مرکزی یا کد شعبه',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              TextField(
                controller: _recipientNameController,
                decoration: InputDecoration(
                  labelText: reqRecipient ? 'نام مرجع دریافت‌کننده *' : 'نام مرجع دریافت‌کننده',
                  hintText: 'مثلاً اداره ثبت شرکت‌ها، سفارت، شرکت مقصد...',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildInfoRow('مخاطب چاپی', _recipientDisplay),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _purposeController,
              decoration: InputDecoration(
                labelText: reqPurpose ? 'هدف معرفی‌نامه *' : 'هدف معرفی‌نامه',
                hintText: 'مثلاً افتتاح حساب بانکی، دریافت تسهیلات، ضمانت...',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (hasExpiry) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _validityDateController,
                decoration: const InputDecoration(
                  labelText: 'تاریخ اعتبار معرفی‌نامه (شمسی)',
                  hintText: 'مثلاً ۱۴۰۵/۰۹/۳۰',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'توضیحات اختصاصی مجاز',
                hintText: 'در صورت نیاز؛ بدون تعهد مالی خودکار',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow('شماره معرفی‌نامه', 'پس از صدور نهایی'),
                  _buildInfoRow('تاریخ صدور', 'پس از صدور نهایی'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: widget.initialLetterName.isNotEmpty ? 'ویرایش معرفی‌نامه' : 'صدور معرفی‌نامه پرسنل',
          subtitle: 'منابع انسانی / اسناد پرسنلی',
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(
                    failure: _error!,
                    onRetry: _loadData,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF5FC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBCE0FD)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF2379BE), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'قالب منتشرشده «معرفی‌نامه پرسنل» بارگذاری شده است. بندها و فیلدهای آن در فرم‌ساز تعریف شده‌اند؛ اینجا فقط اطلاعات مربوط به معرفی‌نامه تکمیل می‌شود.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF243F60), height: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildPersonnelCard(),
                        const SizedBox(height: 14),
                        _buildRecipientCard(),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره پیش‌نویس'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AsoudColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _saving ? null : () => _saveDraft(),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.verified_outlined, size: 18),
                          label: const Text('تأیید و صدور نهایی'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AsoudColors.primary,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _saving ? null : () => _saveDraft(andFinalize: true),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.preview_outlined, size: 18),
                          label: const Text('پیش‌نمایش سند'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _saving ? null : () => _saveDraft(andPreview: true),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}
