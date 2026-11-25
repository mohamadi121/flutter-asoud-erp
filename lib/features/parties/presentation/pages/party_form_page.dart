import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/offline/queued_offline_exception.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/utils/organization_labels.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../accounting/domain/entities/detail_group.dart';
import '../../../accounting/domain/repositories/detail_group_repository.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import '../../../office_setup/domain/office_input_validation.dart';
import '../../../auth/domain/identity_validators.dart';

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
  bool dirty = false, allowLeave = false, confirmingLeave = false;
  Map<String, dynamic> options = {};
  String? optionsError, birthError;
  bool get canEditFinancial => options['can_edit_financial'] == true;
  bool get _newPersonnel => widget.profile == null &&
      widget.initialRole == PartyRole.employee &&
      roles.contains(PartyRole.employee);

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
      'province': p?.province ?? (p == null && !_newPersonnel ? 'تهران' : null),
      'city': p?.city ?? (p == null && !_newPersonnel ? 'تهران' : null),
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
    for (final controller in fields.values) {
      controller.addListener(() {
        if (!dirty && mounted) setState(() => dirty = true);
      });
    }
    fields['birth']!.addListener(() {
      if (mounted && birthError != null) setState(() => birthError = null);
    });
    _loadOptions();
    _loadGroups();
  }

  Future<void> _loadOptions() async {
    try {
      final client = context.read<FrappeApiClient>();
      final result = await client.callAsoudMethod(
          'asoud_erp.api.v1.party.get_form_options',
          data: {'company': widget.company ?? widget.profile?.company});
      if (result is! Map) throw StateError('گزینه‌های فرم دریافت نشد.');
      if (mounted) {
        setState(() {
          options = Map<String, dynamic>.from(result);
          optionsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            optionsError = 'فهرست‌های فرم دریافت نشدند؛ برای تلاش مجدد بزنید.');
      }
    }
  }

  Future<void> _existingPerson() async {
    if (saving) return;
    final query = fields['national']!.text.trim();
    if (query.isEmpty) {
      setState(() => error =
          'برای جست‌وجوی پرونده موجود، کد ملی یا شناسه ملی را وارد کنید.');
      return;
    }
    try {
      final rows = await context.read<PartyRepository>().list(
          company: widget.company ?? widget.profile?.company,
          search: toLatinDigits(query));
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(
            () => error = 'پرونده‌ای با این مشخصات در دفتر فعال پیدا نشد.');
        return;
      }
      final id = await showAppOptionSheet(context,
          title: 'استفاده از شخص موجود',
          options: [
            for (final person in rows)
              if (person.id != null) AppOption(person.id!, person.displayName)
          ]);
      if (!mounted || id == null) return;
      final person = rows.where((p) => p.id == id).first;
      final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
              builder: (_) => PartyFormPage(
                  initialRole: widget.initialRole,
                  company: person.company,
                  profile: person,
                  pageTitle: 'افزودن ارتباط به پرونده موجود')));
      if (mounted && saved == true) _leave(true);
    } catch (failure) {
      if (mounted) setState(() => error = failureMessage(failure));
    }
  }

  Future<void> _confirmLeave() async {
    if (saving || confirmingLeave) return;
    confirmingLeave = true;
    final discard = !dirty ||
        await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                        title: const Text('تغییرات ذخیره نشده‌اند'),
                        content: const Text(
                            'از فرم خارج می‌شوید و تغییرات را کنار می‌گذارید؟'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('ادامه ویرایش')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('خروج بدون ذخیره')),
                        ])) ==
            true;
    confirmingLeave = false;
    if (discard && mounted) _leave(null);
  }

  void _leave(bool? result) {
    setState(() => allowLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _loadGroups() async {
    try {
      final result = await context.read<DetailGroupRepository>().getGroups();
      if (!mounted) return;
      final active = result.where((group) => !group.disabled).toList();
      final common = active.where((group) {
        final title = group.title.replaceAll('‌', '').replaceAll(' ', '');
        return title == 'اشخاصوشرکتها' || title == 'اشخاص';
      }).firstOrNull;
      final preferred = common ??
          active
              .where((group) => group.partyRole == _roleKey(widget.initialRole))
              .firstOrNull;
      setState(() {
        groups = active;
        if (selectedGroups.isEmpty) {
          selectedGroups = {if (preferred != null) preferred.id};
        }
        loadingGroups = false;
      });
      await _preview();
    } catch (_) {
      if (mounted) setState(() => loadingGroups = false);
    }
  }

  Future<void> _preview() async {
    if (widget.profile != null) {
      setState(() =>
          previewCode = widget.profile!.floatingDetails.firstOrNull?.code);
      return;
    }
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
    setState(() {
      roles = value;
      dirty = true;
      if (value.contains(PartyRole.employee)) kind = PartyKind.individual;
    });
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || saving) return;
    final birth = DateTime.tryParse(fields['birth']!.text);
    final today = DateUtils.dateOnly(DateTime.now());
    if (birth != null && birth.isAfter(today)) {
      setState(() => birthError = 'تاریخ تولد نباید در آینده باشد.');
      return;
    }
    birthError = null;
    if ((loadingGroups || selectedGroups.isEmpty) &&
        !(roles.length == 1 && roles.contains(PartyRole.employee))) {
      setState(() => error =
          'ابتدا گروه تفصیلی اشخاص و شرکت‌ها را در حسابداری تعریف کنید.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final displayName = kind == PartyKind.individual
          ? '${fields['firstName']!.text.trim()} ${fields['lastName']!.text.trim()}'
              .trim()
          : fields['name']!.text.trim();
      final saved = await context.read<PartyRepository>().save(
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
      if (mounted) {
        if (saved.pendingSync) await _queuedNotice();
        if (mounted) _leave(true);
      }
    } on QueuedOfflineException {
      await _queuedNotice();
      if (mounted) Navigator.of(context).pop(true);
    } catch (failure) {
      if (mounted) {
        setState(() => error = failureMessage(failure));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _queuedNotice() async {
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              content: const Text(
                  'ذخیره روی گوشی انجام شد و هنوز به سرور ارسال نشده است'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('باشه')),
              ],
            ));
  }

  String? _value(String key) {
    var value = fields[key]!.text.trim();
    if (const {
      'national',
      'postal',
      'account',
      'card',
      'birthCertificate',
      'registration',
      'economic',
      'mobile',
      'phone',
      'secondaryPhone'
    }.contains(key)) {
      value = toLatinDigits(value);
    }
    if (key == 'card') value = value.replaceAll(RegExp(r'[\\s-]'), '');
    if (key == 'iban') {
      value = toLatinDigits(value).replaceAll(' ', '').toUpperCase();
    }
    if (key == 'website' && value.isNotEmpty) {
      value = OfficeInputValidation.website(value) ?? value;
    }
    return value.isEmpty ? null : value;
  }

  double? _number(String key) => double.tryParse(
        toLatinDigits(fields[key]!.text.trim()).replaceAll(',', ''),
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
    final personnelLayout = _newPersonnel;
    return PopScope(
        canPop: allowLeave || (!dirty && !saving),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _confirmLeave();
        },
        child: AsoudFormPage(
          title: widget.pageTitle ??
              (widget.profile == null
                  ? 'ایجاد ${_roleLabel(widget.initialRole)}'
                  : 'ویرایش ${_roleLabel(widget.initialRole)}'),
          subtitle: 'فرم مشخصات و گروه تفصیلی',
          formKey: formKey,
          saving: saving,
          error: error,
          onSave: _save,
          children: [
            if (optionsError != null)
              TextButton(onPressed: _loadOptions, child: Text(optionsError!)),
            for (final warning in (options['warnings'] as List? ?? []))
              Text('$warning', style: const TextStyle(fontSize: 12)),
            _AutomaticDetailCode(
              code: previewCode,
              groups: groups,
              selected: selectedGroups,
              loading: loadingGroups,
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
                setState(() {
                  kind = value;
                  dirty = true;
                });
              },
            ),
            const SizedBox(height: 12),
            _PrimaryRoleGrid(value: roles, onChanged: _changeRoles),
            const SizedBox(height: 10),
            if (employee)
              _AdditionalRoleSelector(
                value: employeeRoles,
                onChanged: (value) => setState(() {
                  employeeRoles = value;
                  dirty = true;
                }),
              ),
            const SizedBox(height: 14),
            AsoudFormSection(
              title: personnelLayout ? 'اطلاعات اصلی و هویتی' : 'اطلاعات اصلی',
              fieldGap: 14,
              children: [
                if (personnelLayout)
                  _pair(_input('lastName', 'نام خانوادگی', required: true),
                    _input('firstName', 'نام', required: true))
                else if (kind == PartyKind.individual)
                  _pair(_input('firstName', 'نام', required: true),
                    _input('lastName', 'نام خانوادگی', required: true))
                else ...[
                  _input('name', 'نام شرکت *', required: true),
                  _input('manager', 'نام مدیر شرکت'),
                ],
                _input('alias',
                    kind == PartyKind.individual ? 'نام مستعار' : 'نام تجاری'),
                if (personnelLayout)
                  _input('national', 'کد ملی', hint: '۱۰ رقم')
                else _pair(_input('national',
                    kind == PartyKind.individual ? 'کد ملی' : 'شناسه ملی'),
                  _input('mobile', 'شماره موبایل')),
                if (widget.profile == null)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: fields['national']!,
                    builder: (_, entry, child) => employee && entry.text.trim().isEmpty
                      ? const SizedBox.shrink()
                      : TextButton.icon(
                          onPressed: saving ? null : _existingPerson,
                          icon: const Icon(Icons.person_search_outlined),
                          label: Text(employee
                              ? 'جست‌وجوی پروندهٔ ثبت‌شده با کد ملی'
                              : 'استفاده از شخص موجود در همین دفتر')),
                  ),
                if (kind == PartyKind.organization)
                  _pair(_input('registration', 'شماره ثبت'),
                    _input('economic', 'کد اقتصادی')),
                if (kind == PartyKind.organization)
                  _dateInput('founding', 'تاریخ تأسیس'),
                if (kind == PartyKind.individual) ...[
                  _choice('employeeGender', 'gender', 'جنسیت'),
                  _dateInput('birth', 'تاریخ تولد'),
                  if (personnelLayout)
                    _pair(_input('birthCertificate', 'شماره شناسنامه'),
                      _input('fatherName', 'نام پدر'))
                  else ...[
                    _input('fatherName', 'نام پدر'),
                    _input('birthCertificate', 'شماره شناسنامه'),
                  ],
                  _input('birthIssuePlace', 'محل صدور'),
                ],
              ],
            ),
            AsoudFormSection(
              title: 'راه‌های ارتباطی',
              fieldGap: 14,
              children: [
                _pair(_input('phone', 'تلفن ثابت'), _input('secondaryPhone', 'تلفن دوم')),
                _input('email', 'ایمیل اصلی'),
                _input('website', 'وب‌سایت'),
              ],
            ),
            AsoudFormSection(
              title: 'آدرس و موقعیت',
              fieldGap: 14,
              children: [
                _pair(_input('province', 'استان'), _input('city', 'شهر')),
                _input('address', 'نشانی کامل', lines: 2),
                _pair(_input('region', 'منطقه'), _input('neighborhood', 'محله')),
                _pair(_input('plaque', 'پلاک'), _input('unit', 'واحد')),
                _input('postal', 'کد پستی'),
                _pair(_input('latitude', 'عرض جغرافیایی'),
                  _input('longitude', 'طول جغرافیایی')),
              ],
            ),
            if (employee && kind == PartyKind.individual)
              AsoudFormSection(title: 'اطلاعات شغلی و سازمانی', fieldGap: 14, children: [
                _choice('employment', 'employment_type', 'نوع همکاری'),
                _dateInput('joiningDate', 'تاریخ شروع همکاری'),
                _choice('department', 'department', 'واحد سازمانی'),
                _choice('job', 'job_title', 'سمت شغلی'),
                const Text(
                    'سمت‌ها از ساختار سازمانی همین دفتر خوانده می‌شوند. پس از انتخاب واحد، فقط سمت‌های همان واحد دیده می‌شوند.',
                    style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
                const Text(
                    'با نام و نام خانوادگی می‌توانید پرونده را ثبت کنید. برای فعال‌شدن در عملیات منابع انسانی، جنسیت، تاریخ تولد و تاریخ شروع همکاری را تکمیل کنید. انتخاب سمت، انتساب به جایگاه یا دسترسی نرم‌افزاری ایجاد نمی‌کند.',
                    style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
              ]),
            if (canEditFinancial &&
                (personnelLayout || roles.contains(PartyRole.customer) ||
                    roles.contains(PartyRole.supplier) ||
                    (widget.profile?.openingBalance ?? 0) != 0 ||
                    (widget.profile?.creditLimit ?? 0) != 0))
              AsoudFormSection(title: 'اطلاعات مالی', fieldGap: 14, children: [
                _input('credit', 'سقف اعتبار (ریال)'),
                IgnorePointer(
                    child: _BalanceSection(
                  value: fields['balanceType']!.text,
                  amountController: fields['opening']!,
                  onChanged: (_) {},
                )),
                const Text(
                    'مانده قبلی حفظ می‌شود. ثبت یا اصلاح مانده اول دوره باید با دوره مالی و سند حسابداری از بخش حسابداری انجام شود.',
                    style: TextStyle(fontSize: 12, color: AsoudColors.muted)),
              ]),
            if (canEditFinancial)
              AsoudFormSection(title: 'اطلاعات بانکی', fieldGap: 14, children: [
                _choice('bank', 'bank', 'نام بانک'),
                _input('accountHolder', 'نام صاحب حساب'),
                _input('iban', 'شماره شبا', hint: personnelLayout ? 'IR و ۲۴ رقم' : null),
                _input('account', 'شماره حساب'),
                _input('card', 'شماره کارت', hint: personnelLayout ? '۱۶ رقم' : null),
              ]),
            AsoudFormSection(
                title: 'توضیحات',
                children: [_input('description',
                  personnelLayout ? 'توضیحات تکمیلی (اختیاری)' : 'توضیحات تکمیلی',
                  lines: 3)]),
          ],
        ));
  }

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (constraints.maxWidth < 248 * scale) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          first, const SizedBox(height: 14), second,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: first), const SizedBox(width: 12), Expanded(child: second),
      ]);
    },
  );

  Widget _input(String key, String label,
      {bool required = false, int lines = 1, String? hint}) {
    final identifier = const {
      'national',
      'postal',
      'account',
      'card',
      'birthCertificate',
      'registration',
      'economic',
      'plaque',
      'unit',
    }.contains(key);
    final phone = const {'mobile', 'phone', 'secondaryPhone'}.contains(key);
    final money = const {'credit', 'opening'}.contains(key);
    final latin = identifier ||
        phone ||
        money ||
        const {'iban', 'email', 'website', 'latitude', 'longitude'}
            .contains(key);
    final limit = switch (key) {
      'national' => kind == PartyKind.individual ? 10 : 11,
      'postal' => 10,
      'card' => 19,
      'iban' => 26,
      _ => null,
    };
    return AppTextField(
      controller: fields[key]!,
      label: label,
      hint: hint,
      labelOutside: true,
      inputMinHeight: AsoudFormStyle.uniformInputHeight,
      required: required,
      maxLines: lines,
      enabled: !saving && (!money || canEditFinancial),
      ltr: latin,
      maxLength: limit,
      counterText: limit == null ? null : '',
      hintLocales: latin ? const [Locale('en')] : const [Locale('fa')],
      keyboardType: phone
          ? TextInputType.phone
          : key == 'email' || key == 'website'
              ? TextInputType.emailAddress
              : identifier || money
                  ? TextInputType.number
                  : lines > 1
                      ? TextInputType.multiline
                      : TextInputType.text,
      inputFormatters: [
        if (key == 'iban')
          TextInputFormatter.withFunction((oldValue, value) {
            String clean(String text) => toLatinDigits(text)
                .replaceAll(RegExp(r'\\s'), '')
                .toUpperCase();
            final text = clean(value.text);
            final offset =
                value.selection.baseOffset.clamp(0, value.text.length);
            return value.copyWith(
                text: text,
                selection: TextSelection.collapsed(
                    offset: clean(value.text.substring(0, offset)).length),
                composing: TextRange.empty);
          }),
        if (identifier)
          TextInputFormatter.withFunction((oldValue, value) =>
              value.copyWith(text: toLatinDigits(value.text))),
        if (identifier) FilteringTextInputFormatter.digitsOnly,
        if (money) _AmountFormatter(),
        if (key == 'card') _CardFormatter(),
        if (limit != null) LengthLimitingTextInputFormatter(limit),
      ],
      validator: (value) {
        final text = (value ?? '').trim();
        if (required && text.isEmpty) return 'این فیلد الزامی است.';
        if (text.isEmpty) return null;
        if (key == 'national') {
          if (kind == widget.profile?.kind &&
              toLatinDigits(text) ==
                  toLatinDigits(widget.profile?.nationalId ?? '')) {
            return null;
          }
          return OfficeInputValidation.nationalId(text,
              legal: kind == PartyKind.organization);
        }
        if (key == 'iban' &&
            text != (widget.profile?.iban ?? '') &&
            !_validIban(text)) {
          return 'شماره شبا و رقم کنترل آن معتبر نیست.';
        }
        if (key == 'card' &&
            text.replaceAll(' ', '') != (widget.profile?.cardNumber ?? '') &&
            !_validCard(text)) {
          return 'شماره کارت ۱۶ رقمی معتبر وارد کنید.';
        }
        if (money && !_validAmount(text)) {
          return 'مبلغ معتبر و غیرمنفی وارد کنید.';
        }
        if (key == 'postal') return OfficeInputValidation.postalCode(text);
        if (key == 'mobile') return IdentityValidators.mobile(text);
        if (key == 'email') return IdentityValidators.email(text);
        if (key == 'website' &&
            text != (widget.profile?.website ?? '') &&
            OfficeInputValidation.website(text) == null) {
          return 'نشانی وب‌سایت معتبر نیست.';
        }
        return null;
      },
    );
  }

  Widget _dateInput(String key, String label, {bool required = false}) =>
      AsoudFormDateField(
          controller: fields[key]!,
          label: label,
          labelOutside: true,
          clearable: !required,
          required: required,
          enabled: !saving,
          errorText: key == 'birth' ? birthError : null);

  Widget _choice(String field, String source, String label,
      {bool required = false}) {
    final department = fields['department']!.text;
    final chart = (options['chart_jobs'] as List? ?? []).whereType<Map>();
    final choices = source == 'job_title'
        ? {
            for (final row in chart)
              if (row['title'] is String &&
                  (department.isEmpty || row['department'] == department))
                row['title'] as String,
          }.toList()
        : (options[source] as List? ?? []).map((v) => '$v').toList();
    final value = fields[field]!.text;
    String title(String id) {
      if (source == 'gender') return persianGenderLabel(id);
      if (source == 'department') {
        final labels = options['department_labels'];
        return organizationLabel(labels is Map ? '${labels[id] ?? id}' : id);
      }
      return source == 'job_title' ? organizationLabel(id) : id;
    }
    return AppSelectField(
        label: label,
        labelOutside: true,
        inputMinHeight: AsoudFormStyle.uniformInputHeight,
        enabled: !saving && (choices.isNotEmpty || value.isNotEmpty),
        value: value,
        required: required,
        displayValue: title(value),
        hint: choices.isEmpty ? 'گزینه‌ای در دسترس نیست' : 'انتخاب کنید',
        onPick: () =>
            showAppOptionSheet(context, title: label, current: value, options: [
              if (value.isNotEmpty) const AppOption('', 'پاک‌کردن انتخاب'),
              for (final id in choices) AppOption(id, title(id)),
            ]),
        onChanged: (value) => setState(() {
              fields[field]!.text = value;
              if (field == 'department' && value.isNotEmpty &&
                  !chart.any((row) => row['department'] == value &&
                      row['title'] == fields['job']!.text)) {
                fields['job']!.clear();
              }
              dirty = true;
            }),
        validator: required
            ? (value) => (value ?? '').isEmpty ? 'این فیلد الزامی است.' : null
            : null);
  }
}

bool _validIban(String value) {
  final code = toLatinDigits(value).replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (!RegExp(r'^IR[0-9]{24}$').hasMatch(code)) return false;
  return BigInt.parse('${code.substring(4)}1827${code.substring(2, 4)}') %
          BigInt.from(97) ==
      BigInt.one;
}

bool _validCard(String value) {
  final code = toLatinDigits(value).replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^[0-9]{16}$').hasMatch(code) ||
      code.split('').toSet().length == 1) {
    return false;
  }
  var sum = 0;
  for (var i = 0; i < code.length; i++) {
    var digit = int.parse(code[i]) * (i.isEven ? 2 : 1);
    if (digit > 9) digit -= 9;
    sum += digit;
  }
  return sum % 10 == 0;
}

bool _validAmount(String value) {
  final text = toLatinDigits(value)
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll('٫', '.');
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) return false;
  final parts = text.split('.');
  final cents = BigInt.parse(parts.first) * BigInt.from(100) +
      BigInt.parse((parts.length > 1 ? parts.last : '').padRight(2, '0'));
  return cents <= BigInt.from(1000000000000000) * BigInt.from(100);
}

/// Formatting only; no floating-point financial calculations are performed here.
class _AmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue value) {
    String clean(String text) => toLatinDigits(text)
        .replaceAll(RegExp(r'[,٬]'), '')
        .replaceAll('٫', '.');
    final raw = clean(value.text);
    if (!RegExp(r'^\d*(?:\.\d{0,2})?$').hasMatch(raw)) return oldValue;
    final parts = raw.split('.');
    final grouped = parts.first
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    final formatted = grouped + (parts.length > 1 ? '.${parts.last}' : '');
    final before = clean(value.text.substring(
            0, value.selection.baseOffset.clamp(0, value.text.length)))
        .length;
    var seen = 0, offset = 0;
    while (offset < formatted.length && seen < before) {
      if (formatted[offset] != ',') seen++;
      offset++;
    }
    return value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: offset),
        composing: TextRange.empty);
  }
}

class _CardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue value) {
    final digits = toLatinDigits(value.text).replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) return oldValue;
    final grouped = [
      for (var i = 0; i < digits.length; i += 4)
        digits.substring(i, (i + 4).clamp(0, digits.length))
    ].join(' ');
    final before = toLatinDigits(value.text.substring(
            0, value.selection.baseOffset.clamp(0, value.text.length)))
        .replaceAll(RegExp(r'\D'), '')
        .length;
    return value.copyWith(
        text: grouped,
        selection: TextSelection.collapsed(
            offset: (before + (before == 0 ? 0 : (before - 1) ~/ 4))
                .clamp(0, grouped.length)),
        composing: TextRange.empty);
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
  const _AutomaticDetailCode(
      {required this.code,
      required this.groups,
      required this.selected,
      required this.loading});
  final String? code;
  final List<DetailGroup> groups;
  final Set<String> selected;
  final bool loading;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const AsoudIconBox(
                  icon: Icons.tag_rounded,
                  color: AsoudColors.primary,
                  size: 38),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('کد تفصیلی',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (loading)
                      const LinearProgressIndicator()
                    else
                      Text(
                          code ??
                              (selected.isEmpty
                                  ? 'ابتدا گروه تفصیلی را تعریف کنید'
                                  : 'دریافت کد ممکن نشد'),
                          textDirection: code == null
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AsoudColors.primary)),
                    Text(
                        groups
                            .where((g) => selected.contains(g.id))
                            .map((g) => g.title)
                            .join(' • '),
                        style: const TextStyle(
                            fontSize: 10, color: AsoudColors.muted)),
                  ])),
              const Icon(Icons.lock_outline_rounded,
                  size: 18, color: AsoudColors.muted),
            ])),
      );
}

class _AdditionalRoleSelector extends StatelessWidget {
  const _AdditionalRoleSelector({required this.value, required this.onChanged});
  final Set<String> value;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    const roles = [
      ('بازاریاب', Icons.campaign_outlined, AsoudColors.primary),
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
          mainAxisExtent: 94,
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
      (PartyRole.employee, 'پرسنل', Icons.badge_outlined, AsoudColors.primary),
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
            ? AsoudColors.primary
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
              color: AsoudColors.primary,
              onTap: onChanged),
        ]),
        const SizedBox(height: 8),
        AppTextField(
          controller: amountController,
          label: 'مبلغ',
          readOnly: true,
          enabled: type != 'None',
          ltr: true,
          keyboardType: TextInputType.number,
          suffixIcon: const Center(
            widthFactor: 1,
            child: Text('ریال',
                style: TextStyle(fontSize: 13, color: AsoudColors.muted)),
          ),
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
