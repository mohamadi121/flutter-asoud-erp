import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../office_setup/presentation/pages/office_type_page.dart';

class FirstOfficeCard extends StatelessWidget {
  const FirstOfficeCard({this.onCreated, super.key});
  final VoidCallback? onCreated;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 22),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 6, children: [
            Chip(
                label: const Text('تنظیم اولیه'),
                backgroundColor: AsoudColors.primary,
                labelStyle: const TextStyle(color: Colors.white)),
            const Chip(label: Text('مرحله ۱ از ۲')),
          ]),
          const SizedBox(height: 16),
          Container(
            height: 210,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [Color(0xFFDCEAFF), Color(0xFFF8FAFF)]),
            ),
            child: const Stack(alignment: Alignment.center, children: [
              Icon(Icons.assignment_rounded,
                  size: 150, color: Color(0xFF95BBFF)),
              Positioned(
                  left: 12,
                  bottom: 12,
                  child: Icon(Icons.domain_rounded,
                      size: 104, color: Color(0xFF5594F9))),
              Positioned(
                  right: 8,
                  bottom: 4,
                  child: Icon(Icons.business_center_rounded,
                      size: 100, color: AsoudColors.primary)),
              Positioned(
                  top: 46,
                  right: 58,
                  child: Icon(Icons.check_circle,
                      size: 28, color: AsoudColors.success)),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('بیایید دفتر کار شما\nرا برای اولین بار راه‌اندازی کنیم',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22, height: 1.7, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          const Text(
              'این کار فقط یک‌بار انجام می‌شود.\nبعد از تکمیل، دفتر شما آماده استفاده خواهد بود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, height: 1.9, color: AsoudColors.muted)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const OfficeTypePage()));
              if (context.mounted) onCreated?.call();
            },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('شروع ایجاد دفتر'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('راهنمای ایجاد دفتر'),
                      content: const Text(
                          '۱. نوع دفتر (حقیقی یا حقوقی) را انتخاب کنید.\n\n۲. مشخصات دفتر را تکمیل و ذخیره کنید. سپس تنظیمات پایه حسابداری را انجام دهید.\n\nدر نبود اتصال، اطلاعات روی همین گوشی نگهداری می‌شود.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('متوجه شدم'))
                      ],
                    )),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('مشاهده راهنما'),
          ),
        ]),
      );
}
