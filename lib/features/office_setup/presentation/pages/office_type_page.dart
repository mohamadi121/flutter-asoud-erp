import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../domain/entities/office.dart';
import 'office_form_page.dart';

class OfficeTypePage extends StatelessWidget {
  const OfficeTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ایجاد دفتر کار')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('نوع دفتر را انتخاب کنید', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('بعداً می‌توانید اطلاعات دفتر را ویرایش کنید.', style: TextStyle(color: AsoudColors.muted)),
              const SizedBox(height: 28),
              _OfficeTypeCard(
                color: AsoudColors.personalOffice,
                icon: Icons.person_rounded,
                title: 'دفتر حقیقی',
                subtitle: 'برای اشخاص و کسب‌وکارهای حقیقی',
                onTap: () => _openForm(context, OfficeType.personal),
              ),
              const SizedBox(height: 16),
              _OfficeTypeCard(
                color: AsoudColors.legalOffice,
                icon: Icons.apartment_rounded,
                title: 'دفتر حقوقی',
                subtitle: 'برای شرکت‌ها و مؤسسات ثبت‌شده',
                onTap: () => _openForm(context, OfficeType.legal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, OfficeType type) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OfficeFormPage(officeType: type)));
  }
}

class _OfficeTypeCard extends StatelessWidget {
  const _OfficeTypeCard({required this.color, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(side: const BorderSide(color: AsoudColors.border), borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: AsoudColors.muted))])),
            const Icon(Icons.chevron_left_rounded),
          ]),
        ),
      ),
    );
  }
}

