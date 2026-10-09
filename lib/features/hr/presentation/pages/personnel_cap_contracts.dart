part of 'personnel_page.dart';

/// Capability (A): Contracts & Promotion.
class PersonnelContractsSlot extends StatelessWidget {
  const PersonnelContractsSlot({
    required this.file,
    required this.profileId,
    required this.canEdit,
    this.repository,
    this.onRefresh,
    super.key,
  });

  final PersonnelFile? file;
  final String profileId;
  final bool canEdit;
  final PersonnelFileRepository? repository;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    if (file == null) return const SizedBox.shrink();

    final current = currentContract(file);
    final history = file.contracts.where((c) => c != current).toList();
    final repo = repository;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      capSectionTitle('قرارداد فعلی'),
      if (current == null)
        const Text(capEmpty)
      else
        _CapContractCard(contract: current, repository: repo),
      capSectionTitle('سوابق قراردادها'),
      if (history.isEmpty)
        const Text(capEmpty)
      else
        for (final contract in history)
          _CapContractCard(contract: contract, repository: repo),
      if (canEdit && repo != null) ...[
        const SizedBox(height: 10),
        FilledButton.icon(
            onPressed: () async {
              final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ContractFormPage(
                          profileId: profileId, repository: repo)));
              if (saved == true && onRefresh != null) await onRefresh!();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('افزودن قرارداد')),
      ],
      const SizedBox(height: 12),
    ]);
  }
}

class _CapContractCard extends StatelessWidget {
  const _CapContractCard({required this.contract, this.repository});
  final ContractSummary contract;
  final PersonnelFileRepository? repository;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: CapChip(contractStateLabel(contract),
                color: contractStateColor(contract))),
        const SizedBox(height: 6),
        CapRows(values: {
          'تاریخ شروع': capDate(contract.startDate),
          'تاریخ پایان': capDate(contract.endDate),
          'زمان باقی‌مانده': daysRemainingLabel(contract),
        }),
        if (contract.file != null && repository != null)
          OutlinedButton.icon(
              onPressed: () => savePersonnelFileAttachment(
                  context, () => repository!.contractFile(contract.name)),
              icon: const Icon(Icons.download_outlined),
              label: const Text('مشاهده فایل')),
      ]));
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
    final startText = start.text.trim();
    final endText = end.text.trim();
    if (startText.isNotEmpty && endText.isNotEmpty) {
      try {
        if (DateTime.parse(endText).isBefore(DateTime.parse(startText))) {
          setState(() => error = 'تاریخ پایان نباید پیش از تاریخ شروع باشد.');
          return;
        }
      } catch (_) {}
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.saveContract(
          profileId: widget.profileId,
          startDate: startText,
          endDate: endText.isEmpty ? null : endText,
          terms: terms.text.trim(),
          isSigned: signed,
          submit: submit,
          filename: attachment?.name,
          fileBase64:
              attachment == null ? null : base64Encode(attachment!.bytes!));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = capError(e));
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

class PersonnelPromotionSlot extends StatelessWidget {
  const PersonnelPromotionSlot({
    required this.profileId,
    required this.canEdit,
    required this.personnel,
    this.repository,
    this.onPromoted,
    super.key,
  });

  final String profileId;
  final bool canEdit;
  final PersonnelRepository personnel;
  final PersonnelFileRepository? repository;
  final VoidCallback? onPromoted;

  @override
  Widget build(BuildContext context) {
    final repo = repository;
    if (!canEdit || repo == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FilledButton.icon(
          onPressed: () async {
            final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => PromotionFormPage(
                        profileId: profileId,
                        repository: repo,
                        personnel: personnel)));
            if (saved == true && onPromoted != null) onPromoted!();
          },
          icon: const Icon(Icons.trending_up, size: 18),
          label: const Text('ثبت ارتقا یا تغییر سمت')),
    );
  }
}

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
      if (mounted) setState(() => error = capError(e));
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
      if (mounted) setState(() => error = capError(e));
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
