import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../accounting/domain/entities/detail_group.dart';
import '../../../accounting/domain/repositories/detail_group_repository.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';

class PartyFormPage extends StatefulWidget {
  const PartyFormPage(
      {required this.initialRole, this.company, this.profile, super.key});
  final PartyRole initialRole;
  final String? company;
  final PartyProfile? profile;
  @override
  State<PartyFormPage> createState() => _PartyFormPageState();
}

class _PartyFormPageState extends State<PartyFormPage> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late PartyKind kind;
  late Set<PartyRole> roles;
  List<DetailGroup> groups = const [];
  String? groupId, previewCode, error;
  bool saving = false, loadingGroups = true;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    kind = p?.kind ?? PartyKind.individual;
    roles = {...?p?.roles, widget.initialRole};
    for (final entry in {
      'name': p?.displayName,
      'national': p?.nationalId,
      'mobile': p?.mobile,
      'phone': p?.phone,
      'email': p?.email,
      'website': p?.website,
      'province': p?.province ?? 'تهران',
      'city': p?.city ?? 'تهران',
      'address': p?.address,
      'postal': p?.postalCode,
      'bank': p?.bankName,
      'iban': p?.iban,
      'account': p?.accountNumber,
      'birth': p?.birthDate,
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
      final preferred = widget.initialRole == PartyRole.employee
          ? '30000'
          : widget.initialRole == PartyRole.supplier
              ? '20000'
              : '10000';
      setState(() {
        groups = result;
        groupId = result.any((g) => g.id == preferred)
            ? preferred
            : result.firstOrNull?.id;
        loadingGroups = false;
      });
      await _preview();
    } catch (_) {
      if (mounted) setState(() => loadingGroups = false);
    }
  }

  Future<void> _preview() async {
    if (groupId == null) return;
    try {
      final code =
          await context.read<PartyRepository>().previewNextCode(groupId!);
      if (mounted) setState(() => previewCode = code);
    } catch (_) {
      if (mounted) setState(() => previewCode = null);
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await context.read<PartyRepository>().save(
          PartyProfile(
            id: widget.profile?.id,
            company: widget.company,
            kind: kind,
            displayName: fields['name']!.text.trim(),
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
            employmentType: _value('employment'),
            jobTitle: _value('job'),
            department: _value('department'),
            description: _value('description'),
          ),
          primaryRole: widget.initialRole,
          detailGroup: groupId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'ذخیره در ERPNext انجام نشد؛ اطلاعات یا اتصال سرور را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? _value(String key) {
    final value = fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

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
        title: employee ? 'ایجاد پرسنل' : 'ایجاد تأمین‌کننده',
        subtitle: 'فرم مشخصات و گروه تفصیلی',
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _CodeBanner(code: previewCode, loading: loadingGroups),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(groupId),
                initialValue: groupId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'گروه تفصیلی',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: groups
                    .map((group) => DropdownMenuItem(
                          value: group.id,
                          child: Text('${group.title} (${group.code})'),
                        ))
                    .toList(growable: false),
                onChanged: loadingGroups
                    ? null
                    : (value) async {
                        setState(() {
                          groupId = value;
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
                onChanged: (value) => setState(() => kind = value),
              ),
              const SizedBox(height: 12),
              _RoleGrid(
                  value: roles,
                  onChanged: (value) => setState(() => roles = value)),
              const SizedBox(height: 14),
              _FormSection(
                title: 'اطلاعات اصلی',
                children: [
                  _input('name', 'نام و نام خانوادگی / نام شرکت',
                      required: true),
                  Row(children: [
                    Expanded(child: _input('national', 'کد ملی / شناسه ملی')),
                    const SizedBox(width: 8),
                    Expanded(child: _input('mobile', 'شماره موبایل')),
                  ]),
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
                    Expanded(child: _input('email', 'ایمیل')),
                  ]),
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
                  _input('postal', 'کد پستی'),
                ],
              ),
              _FormSection(
                title: employee ? 'اطلاعات شغلی' : 'اطلاعات بانکی',
                children: employee
                    ? [
                        Row(children: [
                          Expanded(child: _input('birth', 'تاریخ تولد')),
                          const SizedBox(width: 8),
                          Expanded(child: _input('employment', 'نوع همکاری')),
                        ]),
                      ]
                    : [
                        _input('bank', 'نام بانک'),
                        _input('iban', 'شماره شبا'),
                        _input('account', 'شماره حساب'),
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
}

class _CodeBanner extends StatelessWidget {
  const _CodeBanner({required this.code, required this.loading});
  final String? code;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          const Expanded(
              child: Text('کد تفصیلی توسط Backend و براساس گروه تولید می‌شود.',
                  style: TextStyle(fontSize: 9, color: AsoudColors.muted))),
          if (loading)
            const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text(code ?? 'پس از اتصال سرور',
                style: const TextStyle(
                    color: AsoudColors.primary, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _RoleGrid extends StatelessWidget {
  const _RoleGrid({required this.value, required this.onChanged});
  final Set<PartyRole> value;
  final ValueChanged<Set<PartyRole>> onChanged;
  @override
  Widget build(BuildContext context) {
    const options = [
      (PartyRole.customer, 'مشتری', Icons.person_outline_rounded),
      (PartyRole.supplier, 'تأمین‌کننده', Icons.inventory_2_outlined),
      (PartyRole.employee, 'پرسنل', Icons.badge_outlined),
      (PartyRole.shareholder, 'سهام‌دار', Icons.pie_chart_outline_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((item) {
        final selected = value.contains(item.$1);
        return FilterChip(
          selected: selected,
          avatar: Icon(item.$3, size: 17),
          label: Text(item.$2),
          onSelected: (enabled) {
            final next = {...value};
            enabled ? next.add(item.$1) : next.remove(item.$1);
            if (next.isNotEmpty) onChanged(next);
          },
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );
}
