import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/repositories/base_setup_repository.dart';
import '../bloc/fiscal_years_cubit.dart';

class FiscalYearsPage extends StatelessWidget {
  const FiscalYearsPage({
    required this.company,
    required this.repository,
    this.offlinePreview = false,
    super.key,
  });
  final String company;
  final BaseSetupRepository repository;
  final bool offlinePreview;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FiscalYearsCubit(
          company: company,
          repository: repository,
          offlinePreview: offlinePreview,
        )..load(),
        child: const _FiscalYearsView(),
      );
}

class _FiscalYearsView extends StatefulWidget {
  const _FiscalYearsView();
  @override
  State<_FiscalYearsView> createState() => _FiscalYearsViewState();
}

class _FiscalYearsViewState extends State<_FiscalYearsView> {
  int year = 1405;
  int month = 1;
  int day = 1;
  bool yearConfirmed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AsoudHeader(
          title: 'ایجاد سال مالی',
          subtitle: 'تاریخ شروع و دوره مالی دفتر را مشخص کنید',
        ),
        body: SafeArea(
          child: BlocBuilder<FiscalYearsCubit, FiscalYearsState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const AsoudSectionTitle(title: '۱. انتخاب سال مالی'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey('fiscal-year-selector'),
                  isExpanded: true,
                  initialValue: year,
                  decoration: const InputDecoration(
                    labelText: 'سال مالی چهاررقمی',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  items: List.generate(
                    8,
                    (index) => DropdownMenuItem(
                      value: 1403 + index,
                      child: Text(_persianDigits(1403 + index),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  onChanged: (value) => value == null
                      ? null
                      : setState(() {
                          year = value;
                          yearConfirmed = false;
                        }),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() => yearConfirmed = true),
                  icon: Icon(yearConfirmed
                      ? Icons.check_circle_rounded
                      : Icons.arrow_back_rounded),
                  label: Text(yearConfirmed
                      ? 'سال ${_persianDigits(year)} انتخاب شد'
                      : 'تأیید سال ${_persianDigits(year)}'),
                ),
                if (yearConfirmed) ...[
                  const SizedBox(height: 22),
                  const AsoudSectionTitle(title: '۲. شروع سال مالی'),
                  const SizedBox(height: 8),
                  _StartDateSelectors(
                    month: month,
                    day: day,
                    onMonth: (value) => setState(() => month = value),
                    onDay: (value) => setState(() => day = value),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AsoudColors.primary.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'سال مالی ${_persianDigits(year)} از روز ${_persianDigits(day)} ماه ${_months[month - 1]} آغاز می‌شود و پایان آن توسط Backend محاسبه خواهد شد.',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
                if (state.message != null) ...[
                  const SizedBox(height: 10),
                  Text(state.message!,
                      style: const TextStyle(
                          fontSize: 10, color: AsoudColors.warning)),
                ],
                const SizedBox(height: 22),
                const AsoudSectionTitle(title: 'سال‌های مالی موجود'),
                const SizedBox(height: 8),
                if (state.status == FiscalYearsStatus.loading ||
                    state.status == FiscalYearsStatus.saving)
                  const LinearProgressIndicator(),
                if (state.items.isEmpty &&
                    state.status != FiscalYearsStatus.loading)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('سال مالی ثبت‌شده‌ای برای نمایش وجود ندارد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10, color: AsoudColors.muted)),
                    ),
                  ),
                for (final item in state.items)
                  Card(
                    child: ListTile(
                      leading: const AsoudIconBox(
                          icon: Icons.calendar_month_rounded,
                          color: AsoudColors.success),
                      title: Text('سال مالی ${_persianDigits(item.year)}'),
                      subtitle: Text('${item.startDate} تا ${item.endDate}'),
                      trailing: item.disabled
                          ? const Text('غیرفعال')
                          : const Chip(label: Text('فعال')),
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BlocBuilder<FiscalYearsCubit, FiscalYearsState>(
          builder: (context, state) => AsoudBottomActions(
            primaryLabel: state.status == FiscalYearsStatus.saving
                ? 'در حال ایجاد...'
                : 'ایجاد سال مالی',
            onPrimary: state.status == FiscalYearsStatus.saving ||
                    !yearConfirmed
                ? null
                : () async {
                    final created = await context
                        .read<FiscalYearsCubit>()
                        .create(year, month, day);
                    if (created && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('سال مالی با موفقیت در ASOUD ERP ایجاد شد.'),
                        backgroundColor: AsoudColors.success,
                      ));
                    }
                  },
            secondaryLabel: 'بازگشت',
            onSecondary: () => Navigator.pop(context),
          ),
        ),
      );
}

class _StartDateSelectors extends StatelessWidget {
  const _StartDateSelectors({
    required this.month,
    required this.day,
    required this.onMonth,
    required this.onDay,
  });
  final int month, day;
  final ValueChanged<int> onMonth, onDay;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: day,
            decoration: const InputDecoration(labelText: 'روز'),
            items: List.generate(
                31,
                (index) => DropdownMenuItem(
                    value: index + 1, child: Text(_persianDigits(index + 1)))),
            onChanged: (value) => value == null ? null : onDay(value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: month,
            decoration: const InputDecoration(labelText: 'ماه'),
            items: List.generate(
                12,
                (index) => DropdownMenuItem(
                    value: index + 1, child: Text(_months[index]))),
            onChanged: (value) => value == null ? null : onMonth(value),
          ),
        ),
      ]);
}

const _months = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند'
];

String _persianDigits(Object value) {
  const digits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return value.toString().split('').map((character) {
    final digit = int.tryParse(character);
    return digit == null ? character : digits[digit];
  }).join();
}
