import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import 'party_form_page.dart';

/// Accounting's complete person record. HR must use its allowlisted API instead.
class PartyDetailsPage extends StatefulWidget {
  const PartyDetailsPage({required this.profile, super.key});
  final PartyProfile profile;

  @override
  State<PartyDetailsPage> createState() => _PartyDetailsPageState();
}

class _PartyDetailsPageState extends State<PartyDetailsPage> {
  late PartyProfile profile = widget.profile;
  bool loading = false;
  String? error;

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => PartyFormPage(
                company: profile.company,
                profile: profile,
                initialKind: profile.kind,
                initialRole: profile.roles.firstOrNull ?? PartyRole.other,
                pageTitle: 'ویرایش اطلاعات شخص',
              )),
    );
    if (changed != true || !mounted) return;
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final items =
          await context.read<PartyRepository>().list(company: profile.company);
      final updated = items.where((p) => p.id == profile.id).firstOrNull;
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          profile = updated;
        } else {
          error = 'پرونده در فهرست این دفتر پیدا نشد.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'به‌روزرسانی نمایش پرونده انجام نشد. دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(
              title: 'پرونده شخص و شرکت', subtitle: 'اطلاعات ثبت‌شده'),
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      AsoudIconBox(
                          icon: profile.kind == PartyKind.organization
                              ? Icons.apartment_rounded
                              : Icons.person_outline_rounded,
                          color: AsoudColors.primary,
                          size: 56),
                      const SizedBox(height: 12),
                      Text(profile.displayName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(profile.kind == PartyKind.organization
                          ? 'حقوقی'
                          : 'حقیقی'),
                      Chip(label: Text(profile.disabled ? 'غیرفعال' : 'فعال')),
                      for (final detail in profile.floatingDetails)
                        Text(
                            '${detail.groupTitle ?? detail.groupId}: ${detail.code}'),
                    ]))),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!),
              TextButton(
                  onPressed: loading ? null : _reload,
                  child: const Text('تلاش دوباره')),
            ],
            _section(
                'اطلاعات اصلی',
                Icons.person_outline,
                {
                  'نام': profile.displayName,
                  'نام مستعار': profile.aliasName,
                  'کد ملی / شناسه ملی': profile.nationalId,
                  'نام مدیر': profile.managerName,
                  'شماره ثبت': profile.registrationNumber,
                  'کد اقتصادی': profile.economicCode,
                  'تاریخ تأسیس': profile.foundingDate,
                  'تاریخ تولد': profile.birthDate,
                  'جنسیت': profile.employeeGender,
                  'نام پدر': profile.fatherName,
                  'شماره شناسنامه': profile.birthCertificateNumber,
                  'محل صدور': profile.birthCertificateIssuePlace,
                },
                expanded: true),
            _section('راه‌های ارتباطی', Icons.call_outlined, {
              'موبایل': profile.mobile,
              'تلفن': profile.phone,
              'تلفن دیگر': profile.secondaryPhone,
              'ایمیل': profile.email,
              'وب‌سایت': profile.website,
            }),
            _section('نشانی و موقعیت', Icons.location_on_outlined, {
              'استان': profile.province,
              'شهر': profile.city,
              'نشانی': profile.address,
              'کد پستی': profile.postalCode,
              'منطقه': profile.region,
              'محله': profile.neighborhood,
              'پلاک': profile.plaque,
              'واحد': profile.unit,
              'عرض جغرافیایی': profile.latitude,
              'طول جغرافیایی': profile.longitude,
            }),
            if (profile.roles.contains(PartyRole.employee))
              _section('اطلاعات پرسنلی مشترک', Icons.badge_outlined, {
                'سمت': profile.jobTitle,
                'واحد سازمانی': profile.department,
                'نوع همکاری': profile.employmentType,
                'تاریخ استخدام': profile.dateOfJoining,
                'نقش‌های پرسنلی': profile.employeeRoles.join('، '),
              }),
            _section('اطلاعات مالی و بانکی', Icons.account_balance_outlined, {
              'نام بانک': profile.bankName,
              'شماره شبا': profile.iban,
              'شماره حساب': profile.accountNumber,
              'شماره کارت': profile.cardNumber,
              'صاحب حساب': profile.accountHolder,
              'سقف اعتبار': profile.creditLimit,
              'مانده اولیه': profile.openingBalance,
              'نوع مانده': profile.balanceType,
            }),
            _section('توضیحات', Icons.notes_outlined,
                {'توضیحات': profile.description}),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: loading ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('ویرایش اطلاعات')),
          ])),
        ),
      );

  Widget _section(String title, IconData icon, Map<String, Object?> fields,
          {bool expanded = false}) =>
      Card(
        child: ExpansionTile(
          key: PageStorageKey(title),
          initiallyExpanded: expanded,
          leading: AsoudIconBox(icon: icon, color: AsoudColors.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            for (final field in fields.entries)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Text(field.key,
                                style:
                                    const TextStyle(color: AsoudColors.muted))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: SelectableText(field.value == null ||
                                    '${field.value}'.trim().isEmpty
                                ? 'ثبت نشده'
                                : '${field.value}')),
                      ])),
          ],
        ),
      );
}
