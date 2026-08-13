import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/office.dart';

class OfficeDetailsPage extends StatelessWidget {
  const OfficeDetailsPage({required this.office, super.key});

  final Office office;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'مشاهده دفتر کار',
          subtitle: 'اطلاعات ثبت‌شده دفتر',
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Detail('نام دفتر', office.name),
              _Detail('نوع دفتر',
                  office.type == OfficeType.legal ? 'حقوقی' : 'حقیقی'),
              _Detail('نام صاحب دفتر', office.ownerFullName),
              _Detail('شناسه ملی', office.nationalId),
              _Detail('شماره ثبت', office.registrationNumber),
              _Detail('نوع فعالیت', office.activityType),
              _Detail('استان', office.province),
              _Detail('شهر', office.city),
              _Detail('تلفن', office.phone),
              _Detail('ایمیل', office.email),
              _Detail('نشانی', office.address),
              _Detail('کد پستی', office.postalCode),
              _Detail('سال مالی', office.fiscalYear),
              _Detail('الگوی سرفصل', office.chartTemplate),
            ],
          ),
        ),
      );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Text(label,
              style: const TextStyle(color: AsoudColors.muted, fontSize: 10)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value?.trim().isNotEmpty == true ? value! : 'ثبت نشده',
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      );
}
