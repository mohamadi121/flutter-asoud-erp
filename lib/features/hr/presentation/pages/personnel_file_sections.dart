part of 'personnel_page.dart';

const _fileSections = [
  ('اطلاعات فردی', 'هویت، تماس و سوابق فردی', Icons.person_outline),
  ('اطلاعات سازمانی', 'شرکت، واحد و مدیر مستقیم', Icons.apartment_outlined),
  ('اطلاعات استخدامی', 'نوع همکاری، تاریخ شروع و وضعیت', Icons.work_outline),
  ('قراردادها', 'قرارداد جاری و سوابق قراردادها', Icons.description_outlined),
  ('حقوق و مزایا', 'حقوق، فیش و تاریخچه تغییرات', Icons.payments_outlined),
  ('حضور و غیاب', 'کارکرد ماه و مانده مرخصی', Icons.access_time),
];

String _fileAmount(num amount) {
  final parts = (amount == amount.roundToDouble()
          ? amount.toInt().toString()
          : amount.toStringAsFixed(2))
      .split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  return toPersianDigits([whole, ...parts.skip(1)].join('.'));
}

class _FileDetailShell extends StatelessWidget {
  const _FileDetailShell(
      {required this.title,
      required this.header,
      required this.personnel,
      required this.children,
      this.bottom});
  final String title;
  final PersonnelHeader header;
  final PersonnelRepository personnel;
  final List<Widget> children;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AsoudHeader(title: title),
          bottomNavigationBar: bottom,
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FileHeader(header: header, personnel: personnel),
                    const SizedBox(height: 16),
                    ...children,
                  ]))));
}

class _FileRows extends StatelessWidget {
  const _FileRows({required this.title, required this.values});
  final String title;
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AsoudSectionTitle(title: title),
            for (final (index, entry) in values.entries.indexed) ...[
              if (index > 0) const Divider(height: 1),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text(entry.key,
                                style: const TextStyle(
                                    color: AsoudColors.muted, fontSize: 11))),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 3,
                            child: Text(_fileValue(entry.value),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))),
                      ])),
            ],
          ])));
}

class _FileSectionPage extends StatefulWidget {
  const _FileSectionPage(
      {required this.section,
      required this.file,
      required this.canEdit,
      required this.mine,
      required this.repository,
      required this.personnel});
  final String section;
  final PersonnelFile file;
  final bool canEdit, mine;
  final PersonnelFileRepository repository;
  final PersonnelRepository personnel;
  @override
  State<_FileSectionPage> createState() => _FileSectionPageState();
}

class _FileSectionPageState extends State<_FileSectionPage> {
  late PersonnelFile file = widget.file;
  bool loading = false;
  String? error;
  bool get canEdit =>
      widget.canEdit && !widget.mine && file.canEdit && error == null;
  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = widget.mine
          ? await widget.repository.myFile()
          : await widget.repository.file(file.profileId);
      if (mounted) setState(() => file = value);
    } catch (e) {
      if (mounted) setState(() => error = _fileError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addContract() async {
    await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => ContractFormPage(
                profileId: file.profileId, repository: widget.repository)));
    if (mounted) await reload();
  }

  List<Widget> personal() {
    final p = file.personal;
    return [
      _FileRows(title: 'هویتی', values: {
        'نام': file.header.name,
        'کد ملی': p.nationalId,
        'نام پدر': p.fatherName,
        'تاریخ تولد': _fileDate(p.birthDate),
        'جنسیت': _fileLabel(p.gender),
        'وضعیت تأهل': _fileLabel(p.maritalStatus),
        'گروه خونی': p.bloodGroup,
      }),
      _FileRows(title: 'تماس', values: {
        'موبایل': p.mobile,
        'تلفن': p.phone,
        'ایمیل': p.email,
        'ایمیل سازمانی': p.companyEmail,
        'آدرس': p.address,
        'استان/شهر':
            [p.province, p.city].where((s) => s.isNotEmpty).join(' / '),
        'کد پستی': p.postalCode,
        'آدرس دائمی': p.permanentAddress,
      }),
      _FileRows(title: 'تماس اضطراری', values: {
        'نام': p.emergency.name,
        'تلفن': p.emergency.phone,
        'نسبت': p.emergency.relation
      }),
      const AsoudSectionTitle(title: 'تحصیلات'),
      if (p.education.isEmpty) const Text('—'),
      for (final education in p.education)
        _FileRows(title: _fileValue(education.qualification), values: {
          'مؤسسه آموزشی': education.school,
          'مقطع': _fileLabel(education.level),
          'رشته': education.major,
          'سال پایان': education.yearOfPassing == null
              ? '—'
              : toPersianDigits(education.yearOfPassing!),
        }),
      const AsoudSectionTitle(title: 'سوابق کاری قبلی'),
      if (p.previousWork.isEmpty) const Text('—'),
      for (final work in p.previousWork)
        _FileRows(title: _fileValue(work.company), values: {
          'سمت': work.designation,
          'سابقه': work.experience,
        }),
      const AsoudSectionTitle(title: 'مدارک هویتی'),
      if (!file.documents.any((d) => d.category == 'Identity'))
        const Text('مدرکی ثبت نشده است.'),
      for (final doc in file.documents.where((d) => d.category == 'Identity'))
        _FileDocumentRow(
            document: doc,
            onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => _FileDocumentPage(
                        file: file,
                        document: doc,
                        personnel: widget.personnel)))),
    ];
  }

  List<Widget> organization() {
    final o = file.organization, manager = o.reportsTo;
    return [
      _FileRows(title: 'جایگاه سازمانی', values: {
        'شرکت': o.company,
        'مسیر واحد': o.departmentPath.join(' / '),
        'سمت': o.designation,
        'شعبه': o.branch,
        'شماره پرسنلی': o.employeeNumber,
      }),
      const AsoudSectionTitle(title: 'مدیر مستقیم'),
      if (manager == null)
        const Text('—')
      else
        Card(
            child: ListTile(
                leading: CircleAvatar(child: Text(_initials(manager.name))),
                title: Text(_fileValue(manager.name)),
                subtitle: Text(
                    '${_fileValue(manager.designation)}\n${_fileValue(manager.departmentName)}'))),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
              'زیرمجموعه مستقیم: ${toPersianDigits(o.directReports)} نفر')),
    ];
  }

  List<Widget> employment() {
    final e = file.employment;
    return [
      _FileRows(title: 'وضعیت همکاری', values: {
        'نوع همکاری': _fileLabel(e.employmentType),
        'تاریخ شروع': _fileDate(e.dateOfJoining),
        'سابقه': e.serviceLength?.label ?? '—',
        'وضعیت': _fileLabel(e.status),
        'پایان دوره آزمایشی': _fileDate(e.finalConfirmationDate.isEmpty
            ? e.scheduledConfirmationDate
            : e.finalConfirmationDate),
        'پایان قرارداد': _fileDate(e.contractEndDate),
        'مهلت اعلام (روز)': toPersianDigits(e.noticeDays),
        'تقویم تعطیلات': e.holidayList,
        'شیفت': e.defaultShift,
        'تاریخ پایان همکاری': _fileDate(e.relievingDate),
      })
    ];
  }

  List<Widget> contracts() {
    final current = _currentContract(file);
    return [
      const AsoudSectionTitle(title: 'قرارداد فعلی'),
      if (current == null)
        const Text('ثبت نشده')
      else
        _FileContractCard(contract: current, repository: widget.repository),
      const AsoudSectionTitle(title: 'سوابق قراردادها'),
      if (file.contracts.where((c) => c != current).isEmpty) const Text('—'),
      for (final contract in file.contracts.where((c) => c != current))
        _FileContractCard(contract: contract, repository: widget.repository),
    ];
  }

  Widget assignment(SalaryAssignment salary) =>
      _FileRows(title: _fileValue(salary.salaryStructure), values: {
        'ساختار حقوقی': salary.salaryStructure,
        'حقوق پایه': _fileAmount(salary.base),
        'متغیر': _fileAmount(salary.variable),
        'از تاریخ': _fileDate(salary.fromDate),
      });
  List<Widget> salary() {
    final s = file.salary, slip = s.latestSlip;
    return [
      if (s.visible) ...[
        const AsoudSectionTitle(title: 'حقوق فعلی'),
        if (s.current == null)
          const Text('ثبت نشده')
        else
          assignment(s.current!),
        const AsoudSectionTitle(title: 'آخرین فیش حقوقی'),
        if (slip == null)
          const Text('ثبت نشده')
        else ...[
          _FileRows(title: 'خلاصه فیش', values: {
            'دوره': '${_fileDate(slip.startDate)} — ${_fileDate(slip.endDate)}',
            'ناخالص': _fileAmount(slip.grossPay),
            'کسورات': _fileAmount(slip.totalDeduction),
            'خالص': _fileAmount(slip.netPay),
          }),
          const AsoudSectionTitle(title: 'مزایا'),
          for (final line in slip.earnings)
            _FileRows(
                title: line.component,
                values: {'مبلغ': _fileAmount(line.amount)}),
          const AsoudSectionTitle(title: 'کسورات'),
          for (final line in slip.deductions)
            _FileRows(
                title: line.component,
                values: {'مبلغ': _fileAmount(line.amount)}),
        ],
        const AsoudSectionTitle(title: 'تاریخچه تغییرات'),
        if (s.history.isEmpty) const Text('—'),
        for (final item in s.history) assignment(item),
      ] else
        const Text('اطلاعات حقوق و مزایا در دسترس نیست.'),
      if (canEdit && s.legacy != null)
        _FileRows(title: 'مبالغ ثبت‌شده پیش از حقوق و دستمزد', values: {
          for (final entry in s.legacy!.entries)
            if (_benefits.containsKey(entry.key))
              _benefits[entry.key]!: num.tryParse(entry.value) == null
                  ? '—'
                  : _fileAmount(num.parse(entry.value)),
        }),
    ];
  }

  List<Widget> attendance() {
    final a = file.attendance, checkin = a?.lastCheckin;
    return [
      if (a == null)
        const Text('اطلاعات حضور و غیاب ثبت نشده است.')
      else
        _FileRows(title: 'کارکرد این ماه', values: {
          'حاضر': toPersianDigits(a.present),
          'غایب': toPersianDigits(a.absent),
          'مرخصی': toPersianDigits(a.onLeave),
          'نیم‌روز': toPersianDigits(a.halfDay),
          'تأخیر': toPersianDigits(a.lateEntries),
          'تعجیل': toPersianDigits(a.earlyExits),
        }),
      _FileRows(title: 'آخرین تردد', values: {
        'زمان': checkin == null ? '—' : formatJalaliDateTimeIso(checkin.time),
        'نوع': switch (checkin?.logType) {
          'IN' => 'ورود',
          'OUT' => 'خروج',
          _ => '—'
        },
      }),
      const AsoudSectionTitle(title: 'مانده مرخصی'),
      if (file.leave.isEmpty) const Text('—'),
      for (final leave in file.leave)
        _FileRows(title: _fileLabel(leave.leaveType), values: {
          'مانده از کل':
              '${_fileAmount(leave.remainingLeaves)} از ${_fileAmount(leave.totalLeaves)}',
          'استفاده‌شده': _fileAmount(leave.leavesTaken),
          'در انتظار تأیید': _fileAmount(leave.leavesPendingApproval),
        }),
    ];
  }

  @override
  Widget build(BuildContext context) => _FileDetailShell(
          title: widget.section,
          header: file.header,
          personnel: widget.personnel,
          bottom: widget.section == 'قراردادها' && canEdit
              ? _HrActionBar(
                  label: 'افزودن قرارداد',
                  icon: Icons.add,
                  onPressed: loading ? null : addContract)
              : null,
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!),
              TextButton(onPressed: reload, child: const Text('تلاش دوباره'))
            ],
            ...switch (widget.section) {
              'اطلاعات فردی' => personal(),
              'اطلاعات سازمانی' => organization(),
              'اطلاعات استخدامی' => employment(),
              'قراردادها' => contracts(),
              'حقوق و مزایا' => salary(),
              _ => attendance(),
            },
          ]);
}

Future<void> _saveFileAttachment(BuildContext context,
    Future<({String filename, String contentBase64})> Function() load) async {
  try {
    final result = await load();
    final bytes = base64Decode(result.contentBase64);
    if (bytes.isEmpty) throw const FormatException('فایل خالی است.');
    await FilePicker.platform.saveFile(
        fileName: result.filename.split(RegExp(r'[/\\]')).last, bytes: bytes);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('دریافت فایل ممکن نشد.')));
    }
  }
}

class _FileContractCard extends StatelessWidget {
  const _FileContractCard({required this.contract, required this.repository});
  final ContractSummary contract;
  final PersonnelFileRepository repository;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: _FileChip(contract.stateLabel,
                color: contract.state == 'active'
                    ? AsoudColors.success
                    : contract.state == 'expired'
                        ? AsoudColors.danger
                        : AsoudColors.warning)),
        _FileRows(title: _fileValue(contract.terms), values: {
          'تاریخ شروع': _fileDate(contract.startDate),
          'تاریخ پایان': _fileDate(contract.endDate),
          'زمان باقی‌مانده': _daysRemaining(contract),
        }),
        if (contract.file != null)
          OutlinedButton.icon(
              onPressed: () => _saveFileAttachment(
                  context, () => repository.contractFile(contract.name)),
              icon: const Icon(Icons.download_outlined),
              label: const Text('مشاهده فایل')),
      ]));
}

class _FileDocumentRow extends StatelessWidget {
  const _FileDocumentRow({required this.document, required this.onTap});
  final PersonnelDocument document;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.insert_drive_file_outlined,
                    color: AsoudColors.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(document.title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (document.documentNumber.isNotEmpty)
                        Text(document.documentNumber,
                            textDirection: TextDirection.ltr),
                      Text('انقضا: ${_fileDate(document.expiryDate)}',
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 6),
                      _documentStatus(document),
                    ])),
                const Icon(Icons.chevron_left, size: 20),
              ]))));
}

Widget _documentStatus(PersonnelDocument document) =>
    _FileChip(document.statusLabel,
        color: switch (document.status) {
          'valid' => AsoudColors.success,
          'expiring' => AsoudColors.warning,
          'expired' => AsoudColors.danger,
          _ => AsoudColors.muted,
        });

class _FileDocumentPage extends StatelessWidget {
  const _FileDocumentPage(
      {required this.file, required this.document, required this.personnel});
  final PersonnelFile file;
  final PersonnelDocument document;
  final PersonnelRepository personnel;
  @override
  Widget build(BuildContext context) => _FileDetailShell(
          title: 'جزئیات مدرک',
          header: file.header,
          personnel: personnel,
          children: [
            _FileRows(title: document.title, values: {
              'نوع': document.categoryLabel,
              'شماره': document.documentNumber,
              'تاریخ صدور': _fileDate(document.issueDate),
              'تاریخ انقضا': _fileDate(document.expiryDate),
              'وضعیت': document.statusLabel,
              'فایل': document.filename,
            }),
            OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: const Text('مشاهده/دانلود فایل'),
                onPressed: () => _saveFileAttachment(context, () async {
                      final result = await personnel.record(document.id);
                      return (
                        filename: '${result['filename'] ?? document.filename}',
                        contentBase64: '${result['file'] ?? ''}'
                      );
                    })),
          ]);
}

class ContractFormPage extends StatefulWidget {
  const ContractFormPage(
      {required this.profileId, required this.repository, super.key});
  final String profileId;
  final PersonnelFileRepository repository;
  @override
  State<ContractFormPage> createState() => _ContractFormPageState();
}

class _ContractFormPageState extends State<ContractFormPage> {
  final formKey = GlobalKey<FormState>();
  final start = TextEditingController(),
      end = TextEditingController(),
      terms = TextEditingController();
  bool signed = false, submit = false, saving = false;
  PlatformFile? attachment;
  String? error;
  @override
  void dispose() {
    start.dispose();
    end.dispose();
    terms.dispose();
    super.dispose();
  }

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.bytes == null ||
          file.bytes!.isEmpty ||
          file.size > 5 * 1024 * 1024 ||
          file.bytes!.length > 5 * 1024 * 1024 ||
          !['pdf', 'jpg', 'jpeg', 'png']
              .contains(file.extension?.toLowerCase())) {
        setState(() => error = 'فایل معتبر تا ۵ مگابایت انتخاب کنید.');
        return;
      }
      setState(() {
        attachment = file;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'انتخاب فایل انجام نشد؛ دوباره تلاش کنید.');
      }
    }
  }

  Future<void> save() async {
    if (saving) return;
    if (!formKey.currentState!.validate()) {
      setState(() => error = 'فیلدهای مشخص‌شده در بخش‌های فرم را بررسی کنید.');
      return;
    }
    if (end.text.trim().isNotEmpty &&
        DateTime.parse(end.text.trim())
            .isBefore(DateTime.parse(start.text.trim()))) {
      setState(() => error = 'تاریخ پایان نباید پیش از تاریخ شروع باشد.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.saveContract(
          profileId: widget.profileId,
          startDate: start.text.trim(),
          endDate: end.text.trim().isEmpty ? null : end.text.trim(),
          terms: terms.text.trim(),
          isSigned: signed,
          submit: submit,
          filename: attachment?.name,
          fileBase64:
              attachment == null ? null : base64Encode(attachment!.bytes!));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = _fileError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AsoudFormPage(
          title: 'افزودن قرارداد',
          subtitle: 'پرونده پرسنلی',
          formKey: formKey,
          saving: saving,
          error: error,
          onSave: save,
          children: [
            AsoudFormSection(title: 'اطلاعات قرارداد', children: [
              AsoudFormDateField(
                  controller: start,
                  label: 'تاریخ شروع *',
                  required: true,
                  enabled: !saving),
              AsoudFormDateField(
                  controller: end, label: 'تاریخ پایان', enabled: !saving),
              AsoudFormField(
                  controller: terms,
                  label: 'شرح قرارداد *',
                  lines: 4,
                  enabled: !saving,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'شرح قرارداد الزامی است.'
                      : null),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('امضا شده'),
                  value: signed,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => signed = value)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ثبت نهایی'),
                  value: submit,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => submit = value)),
            ]),
            AsoudFormSection(title: 'پیوست قرارداد', children: [
              if (attachment != null) Text(attachment!.name),
              OutlinedButton.icon(
                  onPressed: saving ? null : pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('انتخاب فایل')),
              const Text('سند یا تصویر، حداکثر ۵ مگابایت',
                  style: TextStyle(fontSize: 11)),
            ]),
          ]);
}

Map<String, String> _personnelLinkOptions(
        Map<String, dynamic> options, String key) =>
    {
      for (final row in options[key] as List? ?? [])
        if (row is Map)
          '${row['name']}': key == 'reports_to'
              ? [row['employee_name'], row['designation']]
                  .where((v) => v != null && '$v'.isNotEmpty)
                  .join(' — ')
              : '${row['label'] ?? row['department_name'] ?? row['name']}'
        else
          '$row': _fileLabel('$row'),
    };

class PromotionFormPage extends StatefulWidget {
  const PromotionFormPage(
      {required this.profileId,
      required this.repository,
      required this.personnel,
      super.key});
  final String profileId;
  final PersonnelFileRepository repository;
  final PersonnelRepository personnel;
  @override
  State<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends State<PromotionFormPage> {
  final formKey = GlobalKey<FormState>();
  final date = TextEditingController(),
      designation = TextEditingController(),
      department = TextEditingController(),
      branch = TextEditingController(),
      remarks = TextEditingController();
  Map<String, dynamic> options = {};
  bool loading = true, saving = false, loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [date, designation, department, branch, remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.personnel.profileOptions(widget.profileId);
      if (mounted) {
        setState(() {
          options = value;
          loaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _fileError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (saving || loading || !loaded) return;
    if (!formKey.currentState!.validate()) {
      setState(() => error = 'فیلدهای مشخص‌شده در بخش‌های فرم را بررسی کنید.');
      return;
    }
    if ([designation, department, branch].every((c) => c.text.isEmpty)) {
      setState(
          () => error = 'حداقل یکی از سمت، واحد یا شعبه جدید را انتخاب کنید.');
      return;
    }
    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.addPromotion(
          profileId: widget.profileId,
          promotionDate: date.text.trim(),
          designation: optional(designation),
          department: optional(department),
          branch: optional(branch),
          remarks: optional(remarks));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = _fileError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AsoudFormPage(
          title: 'ثبت ارتقا یا تغییر سمت',
          subtitle: 'پرونده پرسنلی',
          formKey: formKey,
          saving: saving,
          error: error,
          onSave: save,
          children: [
            if (loading) const LinearProgressIndicator(),
            if (!loaded && !loading)
              TextButton(onPressed: load, child: const Text('تلاش دوباره')),
            AsoudFormSection(title: 'اطلاعات تغییر سمت', children: [
              AsoudFormDateField(
                  controller: date,
                  label: 'تاریخ *',
                  required: true,
                  enabled: !saving),
              for (final field in [
                (designation, 'job_title', 'سمت جدید'),
                (department, 'department', 'واحد جدید'),
                (branch, 'branch', 'شعبه جدید')
              ])
                AsoudFormDropdown(
                    controller: field.$1,
                    label: field.$3,
                    options: _personnelLinkOptions(options, field.$2),
                    enabled: !saving && !loading && loaded),
              AsoudFormField(
                  controller: remarks,
                  label: 'توضیحات',
                  lines: 4,
                  enabled: !saving),
            ]),
          ]);
}
