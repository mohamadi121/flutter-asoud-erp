import 'package:flutter/material.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/office.dart';
import 'office_form_page.dart';

class OfficeDetailsPage extends StatefulWidget {
  const OfficeDetailsPage(
      {required this.office, this.isActive = false, super.key});
  final Office office;
  final bool isActive;
  @override
  State<OfficeDetailsPage> createState() => _OfficeDetailsPageState();
}

class _OfficeDetailsPageState extends State<OfficeDetailsPage> {
  late Office office = widget.office;
  String value(String? text) =>
      text?.trim().isNotEmpty == true ? text! : 'ثبت نشده';
  String get type => office.type == OfficeType.legal ? 'حقوقی' : 'حقیقی';

  Future<void> edit() async {
    final result = await Navigator.of(context).push<Office>(MaterialPageRoute(
        builder: (_) =>
            OfficeFormPage(officeType: office.type, office: office)));
    if (mounted && result != null) setState(() => office = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AsoudHeader(
            title: 'مشاهده دفتر کار',
            subtitle: 'اطلاعات ثبت‌شده دفتر',
            action: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  edit();
                } else {
                  Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'edit', child: Text('ویرایش اطلاعات دفتر')),
                PopupMenuItem(value: 'switch', child: Text('تغییر دفتر')),
              ],
            )),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
              card(
                  Column(children: [
                    Row(children: [
                      const AsoudIconBox(
                          icon: Icons.domain_rounded,
                          color: AsoudColors.primary,
                          size: 72),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(office.name,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(value(office.ownerFullName),
                                style:
                                    const TextStyle(color: AsoudColors.muted)),
                            const SizedBox(height: 6),
                            Text(
                                [office.province, office.city]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join('، '),
                                style:
                                    const TextStyle(color: AsoudColors.muted)),
                          ])),
                    ]),
                    const SizedBox(height: 18),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (widget.isActive)
                        badge('دفتر فعال', Icons.check_circle_outline,
                            AsoudColors.success),
                      badge(type, Icons.person_outline, AsoudColors.primary),
                      badge('سال مالی ${value(office.fiscalYear)}',
                          Icons.calendar_month_outlined, AsoudColors.warning),
                    ]),
                  ]),
                  tinted: true),
              section('اطلاعات پایه', Icons.info_outline, AsoudColors.primary, [
                row([
                  ('نام دفتر', office.name),
                  ('نوع دفتر', type),
                  ('نام صاحب دفتر', office.ownerFullName)
                ]),
                const Divider(height: 24),
                row([
                  ('شناسه ملی', office.nationalId),
                  (
                    'الگوی سرفصل',
                    office.chartTemplate == 'Iran Standard'
                        ? 'استاندارد ایران'
                        : office.chartTemplate
                  ),
                  ('سال مالی', office.fiscalYear)
                ]),
              ]),
              section('وضعیت و فعالیت', Icons.monitor_heart_outlined,
                  AsoudColors.purple, [
                row([
                  ('شماره ثبت', office.registrationNumber),
                  ('ماهیت', office.activityType)
                ]),
              ]),
              section(
                  'موقعیت و تماس', Icons.phone_outlined, AsoudColors.success, [
                row([('استان', office.province), ('شهر', office.city)]),
                const Divider(height: 24),
                row([('تلفن', office.phone), ('ایمیل', office.email)]),
              ]),
              section(
                  'نشانی', Icons.location_on_outlined, AsoudColors.warning, [
                row([
                  ('نشانی', office.address),
                  ('کد پستی', office.postalCode)
                ]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                        onPressed: edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('ویرایش اطلاعات دفتر',
                            textAlign: TextAlign.center))),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.domain_outlined, size: 18),
                        label: const Text('تغییر دفتر',
                            textAlign: TextAlign.center))),
              ]),
            ])),
      );

  Widget badge(String text, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ]),
      );
  Widget card(Widget child, {bool tinted = false}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: tinted ? const Color(0xFFF5F8FF) : Colors.white,
            border: Border.all(color: AsoudColors.border),
            borderRadius: BorderRadius.circular(18)),
        child: child,
      );
  Widget section(
          String title, IconData icon, Color color, List<Widget> children) =>
      card(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            AsoudIconBox(icon: icon, color: color, size: 30),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)))
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ));
  Widget row(List<(String, String?)> fields) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final field in fields)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(field.$1,
                            style: const TextStyle(
                                fontSize: 10, color: AsoudColors.muted)),
                        const SizedBox(height: 6),
                        Text(value(field.$2),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ]))),
      ]);
}
