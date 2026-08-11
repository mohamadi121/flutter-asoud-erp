import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../accounting/domain/entities/detail_group.dart';
import '../../../accounting/domain/repositories/detail_group_repository.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import 'personnel_roles_page.dart';

class PartyFormPage extends StatefulWidget {
  const PartyFormPage(
      {required this.initialRole,
      this.company,
      this.profile,
      this.initialKind,
      this.pageTitle,
      super.key});
  final PartyRole initialRole;
  final String? company;
  final PartyProfile? profile;
  final PartyKind? initialKind;
  final String? pageTitle;
  @override
  State<PartyFormPage> createState() => _PartyFormPageState();
}

class _PartyFormPageState extends State<PartyFormPage> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late PartyKind kind;
  late Set<PartyRole> roles;
  late Set<String> selectedGroups;
  late Set<String> employeeRoles;
  List<DetailGroup> groups = const [];
  String? previewCode, error;
  bool saving = false, loadingGroups = true;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    kind = p?.kind ?? widget.initialKind ?? PartyKind.individual;
    roles = {...?p?.roles, widget.initialRole};
    selectedGroups = {...?p?.detailGroups};
    employeeRoles = {...?p?.employeeRoles};
    final displayParts = (p?.displayName ?? '').trim().split(RegExp(r'\s+'));
    for (final entry in {
      'name': p?.displayName,
      'firstName': p?.kind == PartyKind.individual && displayParts.isNotEmpty
          ? displayParts.first
          : null,
      'lastName': p?.kind == PartyKind.individual && displayParts.length > 1
          ? displayParts.skip(1).join(' ')
          : null,
      'alias': p?.aliasName,
      'manager': p?.managerName,
      'registration': p?.registrationNumber,
      'economic': p?.economicCode,
      'founding': p?.foundingDate,
      'national': p?.nationalId,
      'mobile': p?.mobile,
      'phone': p?.phone,
      'secondaryPhone': p?.secondaryPhone,
      'email': p?.email,
      'website': p?.website,
      'province': p?.province ?? 'تهران',
      'city': p?.city ?? 'تهران',
      'address': p?.address,
      'postal': p?.postalCode,
      'region': p?.region,
      'neighborhood': p?.neighborhood,
      'plaque': p?.plaque,
      'unit': p?.unit,
      'latitude': p?.latitude?.toString(),
      'longitude': p?.longitude?.toString(),
      'bank': p?.bankName,
      'iban': p?.iban,
      'account': p?.accountNumber,
      'card': p?.cardNumber,
      'accountHolder': p?.accountHolder,
      'credit': p?.creditLimit?.toString(),
      'opening': p?.openingBalance?.toString(),
      'balanceType': p?.balanceType ?? 'None',
      'birth': p?.birthDate,
      'employeeGender': p?.employeeGender,
      'joiningDate': p?.dateOfJoining,
      'fatherName': p?.fatherName,
      'birthCertificate': p?.birthCertificateNumber,
      'birthIssuePlace': p?.birthCertificateIssuePlace,
      'employment': p?.employmentType,
      'job': p?.jobTitle,
      'department': p?.department,
      'description': p?.description,
    }.entries) {
      fields[entry.key] = TextEditingController(text: entry.value);
    }
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final result = await context.read<DetailGroupRepository>().getGroups();
      if (!mounted) return;
      final roleKey = switch (widget.initialRole) {
        PartyRole.customer => 'Customer',
        PartyRole.supplier => 'Supplier',
        PartyRole.employee => 'Employee',
        _ => null,
      };
      final preferred =
          result.where((group) => group.partyRole == roleKey).firstOrNull?.id;
      setState(() {
        groups = result;
        if (selectedGroups.isEmpty) {
          selectedGroups = {
            if (preferred != null && result.any((g) => g.id == preferred))
              preferred
            else if (result.isNotEmpty)
              result.first.id,
          };
        }
        loadingGroups = false;
      });
      await _preview();
    } catch (_) {
      if (mounted) setState(() => loadingGroups = false);
    }
  }

  Future<void> _preview() async {
    if (selectedGroups.isEmpty) return;
    try {
      final code = await context
          .read<PartyRepository>()
          .previewNextCode(selectedGroups.first);
      if (mounted) setState(() => previewCode = code);
    } catch (_) {
      if (mounted) setState(() => previewCode = null);
    }
  }

  Future<void> _changeRoles(Set<PartyRole> value) async {
    final matching = groups
        .where(
            (group) => value.any((role) => group.partyRole == _roleKey(role)))
        .map((group) => group.id)
        .toSet();
    setState(() {
      roles = value;
      if (value.contains(PartyRole.employee)) kind = PartyKind.individual;
      if (matching.isNotEmpty) selectedGroups = matching;
      previewCode = null;
    });
    await _preview();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final displayName = kind == PartyKind.individual
          ? '${fields['firstName']!.text.trim()} ${fields['lastName']!.text.trim()}'
              .trim()
          : fields['name']!.text.trim();
      await context.read<PartyRepository>().save(
          PartyProfile(
            id: widget.profile?.id,
            company: widget.company,
            kind: kind,
            displayName: displayName,
            roles: roles,
            nationalId: _value('national'),
            mobile: _value('mobile'),
            phone: _value('phone'),
            email: _value('email'),
            website: _value('website'),
            province: _value('province'),
            city: _value('city'),
            address: _value('address'),
            postalCode: _value('postal'),
            bankName: _value('bank'),
            iban: _value('iban'),
            accountNumber: _value('account'),
            birthDate: _value('birth'),
            employeeGender: _value('employeeGender'),
            dateOfJoining: _value('joiningDate'),
            fatherName: _value('fatherName'),
            birthCertificateNumber: _value('birthCertificate'),
            birthCertificateIssuePlace: _value('birthIssuePlace'),
            employmentType: _value('employment'),
            jobTitle: _value('job'),
            department: _value('department'),
            description: _value('description'),
            aliasName: _value('alias'),
            managerName: _value('manager'),
            registrationNumber: _value('registration'),
            economicCode: _value('economic'),
            foundingDate: _value('founding'),
            secondaryPhone: _value('secondaryPhone'),
            creditLimit: _number('credit'),
            openingBalance: _number('opening'),
            balanceType: _value('balanceType'),
            cardNumber: _value('card'),
            accountHolder: _value('accountHolder'),
            region: _value('region'),
            neighborhood: _value('neighborhood'),
            plaque: _value('plaque'),
            unit: _value('unit'),
            latitude: _number('latitude'),
            longitude: _number('longitude'),
            employeeRoles: employeeRoles,
            detailGroups: selectedGroups,
          ),
          primaryRole: widget.initialRole,
          detailGroups: selectedGroups);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'ذخیره در ASOUD ERP انجام نشد؛ اطلاعات یا اتصال سرور را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? _value(String key) {
    final value = fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _number(String key) => double.tryParse(
        fields[key]!.text.trim().replaceAll(',', ''),
      );

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = roles.contains(PartyRole.employee);
    return Scaffold(
      appBar: AsoudHeader(
        title: widget.pageTitle ??
            (widget.profile == null
                ? 'ایجاد ${_roleLabel(widget.initialRole)}'
                : 'ویرایش ${_roleLabel(widget.initialRole)}'),
        subtitle: 'فرم مشخصات و گروه تفصیلی',
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _AutomaticDetailCode(
                code: previewCode,
                groups: groups,
                selected: selectedGroups,
                loading: loadingGroups,
                onChanged: (group) async {
                  setState(() {
                    selectedGroups = {group};
                    previewCode = null;
                  });
                  await _preview();
                },
              ),
              const SizedBox(height: 12),
              const AsoudSectionTitle(title: 'تکمیل اطلاعات'),
              AsoudSegmentedControl<PartyKind>(
                value: kind,
                options: const [
                  AsoudSegmentedOption(
                      value: PartyKind.individual,
                      label: 'حقیقی',
                      icon: Icons.person_outline_rounded),
                  AsoudSegmentedOption(
                      value: PartyKind.organization,
                      label: 'حقوقی',
                      icon: Icons.apartment_outlined),
                ],
                onChanged: (value) {
                  if (employee && value == PartyKind.organization) return;
                  setState(() => kind = value);
                },
              ),
              const SizedBox(height: 12),
              _PrimaryRoleGrid(value: roles, onChanged: _changeRoles),
              const SizedBox(height: 10),
              if (employee)
                _AdditionalRoleSelector(
                  value: employeeRoles,
                  onChanged: (value) => setState(() => employeeRoles = value),
                ),
              const SizedBox(height: 14),
              _FormSection(
                title: 'اطلاعات اصلی',
                children: [
                  if (kind == PartyKind.individual)
                    Row(children: [
                      Expanded(
                          child: _input('firstName', 'نام *', required: true)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _input('lastName', 'نام خانوادگی *',
                              required: true)),
                    ])
                  else ...[
                    _input('name', 'نام شرکت *', required: true),
                    _input('manager', 'نام مدیر شرکت'),
                  ],
                  _input(
                      'alias',
                      kind == PartyKind.individual
                          ? 'نام مستعار'
                          : 'نام تجاری'),
                  Row(children: [
                    Expanded(child: _input('national', 'کد ملی / شناسه ملی')),
                    const SizedBox(width: 8),
                    Expanded(child: _input('mobile', 'شماره موبایل')),
                  ]),
                  if (kind == PartyKind.organization)
                    Row(children: [
                      Expanded(child: _input('registration', 'شماره ثبت')),
                      const SizedBox(width: 8),
                      Expanded(child: _input('economic', 'کد اقتصادی')),
                    ]),
                  if (kind == PartyKind.organization)
                    _input('founding', 'تاریخ تأسیس'),
                  if (employee)
                    Row(children: [
                      Expanded(child: _input('job', 'سمت شغلی')),
                      const SizedBox(width: 8),
                      Expanded(child: _input('department', 'واحد سازمانی')),
                    ]),
                ],
              ),
              _FormSection(
                title: 'راه‌های ارتباطی',
                children: [
                  Row(children: [
                    Expanded(child: _input('phone', 'تلفن ثابت')),
                    const SizedBox(width: 8),
                    Expanded(child: _input('secondaryPhone', 'تلفن دوم')),
                  ]),
                  _input('email', 'ایمیل اصلی'),
                  _input('website', 'وب‌سایت'),
                ],
              ),
              _FormSection(
                title: 'آدرس و موقعیت',
                children: [
                  Row(children: [
                    Expanded(child: _input('province', 'استان')),
                    const SizedBox(width: 8),
                    Expanded(child: _input('city', 'شهر')),
                  ]),
                  _input('address', 'نشانی کامل', lines: 2),
                  Row(children: [
                    Expanded(child: _input('region', 'منطقه')),
                    const SizedBox(width: 8),
                    Expanded(child: _input('neighborhood', 'محله')),
                  ]),
                  Row(children: [
                    Expanded(child: _input('plaque', 'پلاک')),
                    const SizedBox(width: 8),
                    Expanded(child: _input('unit', 'واحد')),
                  ]),
                  _input('postal', 'کد پستی'),
                  Row(children: [
                    Expanded(child: _input('latitude', 'عرض جغرافیایی')),
                    const SizedBox(width: 8),
                    Expanded(child: _input('longitude', 'طول جغرافیایی')),
                  ]),
                ],
              ),
              _FormSection(
                title:
                    employee ? 'اطلاعات شغلی و بانکی' : 'اطلاعات مالی و بانکی',
                children: [
                  if (employee) ...[
                    _employeeGenderInput(),
                    Row(children: [
                      Expanded(
                          child: _dateInput('birth', 'تاریخ تولد *',
                              required: true)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _dateInput(
                              'joiningDate', 'تاریخ شروع همکاری *',
                              required: true)),
                    ]),
                    _input('employment', 'نوع همکاری'),
                    Row(children: [
                      Expanded(child: _input('fatherName', 'نام پدر')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _input('birthCertificate', 'شماره شناسنامه')),
                    ]),
                    _input('birthIssuePlace', 'محل صدور'),
                    OutlinedButton.icon(
                      onPressed: _configurePersonnelRoles,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('تنظیم ترکیب نقش‌های پرسنلی'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _input('credit', 'سقف اعتبار'),
                  _BalanceSection(
                    value: fields['balanceType']!.text,
                    amountController: fields['opening']!,
                    onChanged: (value) => setState(
                      () => fields['balanceType']!.text = value,
                    ),
                  ),
                  _input('bank', 'نام بانک'),
                  _input('accountHolder', 'نام صاحب حساب'),
                  _input('iban', 'شماره شبا'),
                  _input('account', 'شماره حساب'),
                  _input('card', 'شماره کارت'),
                ],
              ),
              _FormSection(title: 'توضیحات', children: [
                _input('description', 'توضیحات تکمیلی', lines: 3)
              ]),
              if (error != null)
                Text(error!,
                    style: const TextStyle(
                        color: AsoudColors.danger, fontSize: 10)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AsoudBottomActions(
        primaryLabel: saving ? 'در حال ذخیره...' : 'ذخیره',
        onPrimary: saving ? null : _save,
        secondaryLabel: 'انصراف',
        onSecondary: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _input(String key, String label,
          {bool required = false, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TextFormField(
          controller: fields[key],
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
          validator: required
              ? (value) => value == null || value.trim().length < 3
                  ? 'این فیلد الزامی است.'
                  : null
              : null,
        ),
      );

  Widget _dateInput(String key, String label, {bool required = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TextFormField(
          controller: fields[key],
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'YYYY-MM-DD',
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          validator: (value) {
            final normalized = value?.trim() ?? '';
            if (!required && normalized.isEmpty) return null;
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
              return 'تاریخ را به شکل YYYY-MM-DD وارد کنید.';
            }
            return null;
          },
        ),
      );

  Widget _employeeGenderInput() => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: DropdownButtonFormField<String>(
          initialValue: fields['employeeGender']!.text.isEmpty
              ? null
              : fields['employeeGender']!.text,
          decoration: const InputDecoration(labelText: 'جنسیت *'),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('مرد')),
            DropdownMenuItem(value: 'Female', child: Text('زن')),
            DropdownMenuItem(value: 'Other', child: Text('سایر')),
          ],
          onChanged: (value) => fields['employeeGender']!.text = value ?? '',
          validator: (value) => value == null ? 'جنسیت را انتخاب کنید.' : null,
        ),
      );

  Future<void> _configurePersonnelRoles() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute<Set<String>>(
        builder: (_) => PersonnelRolesPage(initialValue: employeeRoles),
      ),
    );
    if (result != null && mounted) {
      setState(() => employeeRoles = result);
    }
  }
}

String? _roleKey(PartyRole role) => switch (role) {
      PartyRole.customer => 'Customer',
      PartyRole.supplier => 'Supplier',
      PartyRole.employee => 'Employee',
      _ => null,
    };

String _roleLabel(PartyRole role) => switch (role) {
      PartyRole.customer => 'مشتری',
      PartyRole.supplier => 'تأمین‌کننده',
      PartyRole.employee => 'پرسنل',
      PartyRole.shareholder => 'سهام‌دار',
      PartyRole.other => 'شخص',
    };

class _AutomaticDetailCode extends StatelessWidget {
  const _AutomaticDetailCode({
    required this.code,
    required this.groups,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });
  final String? code;
  final List<DetailGroup> groups;
  final Set<String> selected;
  final bool loading;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const AsoudIconBox(
              icon: Icons.tag_rounded, color: AsoudColors.primary, size: 32),
          title: Text(
              loading ? 'در حال محاسبه کد...' : (code ?? 'کد پس از اتصال سرور'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          subtitle: Text(_selectedNames,
              style: const TextStyle(fontSize: 9, color: AsoudColors.primary)),
          children: [
            if (loading)
              const LinearProgressIndicator()
            else if (groups.isEmpty)
              const Text('گروه فعالی از Backend دریافت نشد.',
                  style: TextStyle(fontSize: 10, color: AsoudColors.warning))
            else
              for (final group in groups)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected.contains(group.id)
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected.contains(group.id)
                        ? AsoudColors.primary
                        : AsoudColors.muted,
                  ),
                  trailing: AsoudIconBox(
                    icon: _groupIcon(group.iconKey),
                    color: _groupColor(group.colorHex),
                    size: 30,
                  ),
                  title: Text(group.title,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                  subtitle: Text('کد گروه: ${group.code}',
                      style: const TextStyle(fontSize: 8)),
                  onTap: group.disabled ? null : () => onChanged(group.id),
                ),
          ],
        ),
      );

  String get _selectedNames {
    final names = groups
        .where((group) => selected.contains(group.id))
        .map((group) => group.title)
        .toList();
    return names.isEmpty
        ? 'انتخاب کارت، گروه متناظر را تعیین می‌کند'
        : names.join(' • ');
  }
}

Color _groupColor(String? value) {
  final normalized = value?.replaceFirst('#', '');
  final parsed =
      normalized == null ? null : int.tryParse(normalized, radix: 16);
  if (parsed == null) return AsoudColors.primary;
  return Color(normalized!.length == 6 ? 0xFF000000 | parsed : parsed);
}

IconData _groupIcon(String? value) => switch (value) {
      'supplier' => Icons.inventory_2_outlined,
      'employee' => Icons.badge_outlined,
      'cash' => Icons.account_balance_wallet_outlined,
      'bank' => Icons.account_balance_outlined,
      'project' => Icons.work_outline_rounded,
      _ => Icons.people_outline_rounded,
    };

class _AdditionalRoleSelector extends StatelessWidget {
  const _AdditionalRoleSelector({required this.value, required this.onChanged});
  final Set<String> value;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    const roles = [
      ('بازاریاب', Icons.campaign_outlined, AsoudColors.warning),
      ('تنخواه‌گردان', Icons.payments_outlined, AsoudColors.success),
      ('فروشنده', Icons.storefront_outlined, AsoudColors.purple),
      ('صندوق', Icons.account_balance_wallet_outlined, AsoudColors.primary),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('نقش‌های پرسنلی',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: .9,
          crossAxisSpacing: 6,
          children: roles.map((role) {
            final selected = value.contains(role.$1);
            return InkWell(
              onTap: () {
                final next = {...value};
                selected ? next.remove(role.$1) : next.add(role.$1);
                onChanged(next);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
                decoration: BoxDecoration(
                  color:
                      selected ? role.$3.withValues(alpha: .09) : Colors.white,
                  border: Border.all(
                      color: selected ? role.$3 : AsoudColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(role.$2, size: 20, color: role.$3),
                      const SizedBox(height: 5),
                      Text(role.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Icon(
                          selected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 14,
                          color: selected ? role.$3 : AsoudColors.muted),
                    ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _PrimaryRoleGrid extends StatelessWidget {
  const _PrimaryRoleGrid({required this.value, required this.onChanged});
  final Set<PartyRole> value;
  final ValueChanged<Set<PartyRole>> onChanged;
  @override
  Widget build(BuildContext context) {
    const options = [
      (
        PartyRole.customer,
        'مشتری',
        Icons.person_outline_rounded,
        AsoudColors.primary
      ),
      (
        PartyRole.supplier,
        'تأمین‌کننده',
        Icons.handshake_outlined,
        AsoudColors.success
      ),
      (PartyRole.employee, 'پرسنل', Icons.badge_outlined, AsoudColors.warning),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: .82,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: options.map((item) {
        final selected = value.contains(item.$1);
        return InkWell(
          onTap: () {
            final next = {...value};
            selected ? next.remove(item.$1) : next.add(item.$1);
            if (next.isNotEmpty) onChanged(next);
          },
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? item.$4.withValues(alpha: .08) : Colors.white,
              border: Border.all(
                color: selected ? item.$4 : AsoudColors.border,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 15,
                color: selected ? item.$4 : AsoudColors.muted,
              ),
              const SizedBox(height: 5),
              AsoudIconBox(icon: item.$3, color: item.$4, size: 34),
              const SizedBox(height: 5),
              Text(
                item.$2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          children: children,
        ),
      );
}

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({
    required this.value,
    required this.amountController,
    required this.onChanged,
  });

  final String value;
  final TextEditingController amountController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = const {'Debit', 'Credit'}.contains(value) ? value : 'None';
    final color = type == 'Debit'
        ? AsoudColors.success
        : type == 'Credit'
            ? AsoudColors.warning
            : AsoudColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مانده اول دوره هنگام استقرار',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
        const Text(
            'فقط در صورتی تکمیل شود که حساب در زمان شروع کار نرم‌افزار مانده دارد.',
            style: TextStyle(fontSize: 8, color: AsoudColors.muted)),
        const SizedBox(height: 8),
        Row(children: [
          _BalanceChoice(
              label: 'ندارد',
              value: 'None',
              selected: type == 'None',
              color: AsoudColors.primary,
              onTap: onChanged),
          const SizedBox(width: 5),
          _BalanceChoice(
              label: 'مانده بدهکار',
              value: 'Debit',
              selected: type == 'Debit',
              color: AsoudColors.success,
              onTap: onChanged),
          const SizedBox(width: 5),
          _BalanceChoice(
              label: 'مانده بستانکار',
              value: 'Credit',
              selected: type == 'Credit',
              color: AsoudColors.warning,
              onTap: onChanged),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: amountController,
          enabled: type != 'None',
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'مبلغ', suffixText: 'ریال'),
        ),
      ]),
    );
  }
}

class _BalanceChoice extends StatelessWidget {
  const _BalanceChoice(
      {required this.label,
      required this.value,
      required this.selected,
      required this.color,
      required this.onTap});
  final String label, value;
  final bool selected;
  final Color color;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: () => onTap(value),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: .11) : Colors.white,
              border: Border.all(color: selected ? color : AsoudColors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : AsoudColors.muted)),
          ),
        ),
      );
}
