import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import 'party_form_page.dart';
import 'party_links_page.dart';

class PartyDetailPage extends StatelessWidget {
  const PartyDetailPage({required this.profile, super.key});
  final PartyProfile profile;

  @override
  Widget build(BuildContext context) {
    final employee = profile.roles.contains(PartyRole.employee);
    return Scaffold(
      appBar: AsoudHeader(
          title: employee ? 'مشخصات پرسنل' : 'مشخصات تأمین‌کننده',
          subtitle: profile.displayName),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AsoudColors.primary.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                AsoudIconBox(
                    icon: employee
                        ? Icons.badge_outlined
                        : Icons.inventory_2_outlined,
                    color: AsoudColors.primary,
                    size: 48),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                        Text(employee ? 'پرسنل' : 'تأمین‌کننده',
                            style: const TextStyle(
                                fontSize: 9, color: AsoudColors.muted)),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'اطلاعات هویتی',
              color: AsoudColors.primary,
              rows: [
                (
                  'نوع شخصیت',
                  profile.kind == PartyKind.individual ? 'حقیقی' : 'حقوقی'
                ),
                ('کد ملی / شناسه ملی', profile.nationalId ?? 'ثبت نشده'),
                if (employee) ('سمت', profile.jobTitle ?? 'ثبت نشده'),
                if (employee) ('واحد', profile.department ?? 'ثبت نشده'),
              ],
            ),
            _DetailCard(
              title: 'راه‌های ارتباطی',
              color: AsoudColors.success,
              rows: [
                ('موبایل', profile.mobile ?? 'ثبت نشده'),
                ('تلفن', profile.phone ?? 'ثبت نشده'),
                ('ایمیل', profile.email ?? 'ثبت نشده'),
                ('وب‌سایت', profile.website ?? 'ثبت نشده'),
              ],
            ),
            _DetailCard(
              title: 'آدرس و موقعیت',
              color: AsoudColors.purple,
              rows: [
                ('استان', profile.province ?? 'ثبت نشده'),
                ('شهر', profile.city ?? 'ثبت نشده'),
                ('نشانی', profile.address ?? 'ثبت نشده'),
                ('کد پستی', profile.postalCode ?? 'ثبت نشده'),
              ],
            ),
            if (!employee)
              _DetailCard(
                title: 'اطلاعات بانکی',
                color: AsoudColors.warning,
                rows: [
                  ('بانک', profile.bankName ?? 'ثبت نشده'),
                  ('شماره شبا', profile.iban ?? 'ثبت نشده'),
                  ('شماره حساب', profile.accountNumber ?? 'ثبت نشده'),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: AsoudBottomActions(
        primaryLabel: 'ویرایش اطلاعات',
        onPrimary: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PartyFormPage(
            company: profile.company,
            initialRole: employee ? PartyRole.employee : PartyRole.supplier,
            profile: profile,
          ),
        )),
        secondaryLabel: 'تفصیلی‌ها',
        onSecondary: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PartyLinksPage(
            profile: profile,
            repository: context.read<PartyRepository>(),
          ),
        )),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard(
      {required this.title, required this.color, required this.rows});
  final String title;
  final Color color;
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text(row.$1,
                      style: const TextStyle(
                          fontSize: 9, color: AsoudColors.muted)),
                  const Spacer(),
                  Flexible(
                    child: Text(row.$2,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
          ]),
        ),
      );
}
