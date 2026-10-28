import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_jalali_picker.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../auth/presentation/pages/sign_out.dart';
import '../../../base_setup/data/repositories/frappe_base_setup_repository.dart';
import '../../../base_setup/domain/repositories/base_setup_repository.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../data/repositories/first_office_bootstrap_repository.dart';
import 'first_hr_lead_form.dart';

/// Server-backed fiscal year, first HR account and final confirmation.
class FirstOfficeSetupPage extends StatefulWidget {
  const FirstOfficeSetupPage({required this.company, super.key});
  final String company;
  @override
  State<FirstOfficeSetupPage> createState() => _FirstOfficeSetupPageState();
}

class _FirstOfficeSetupPageState extends State<FirstOfficeSetupPage> {
  late final repository =
      FrappeBaseSetupRepository(context.read<FrappeApiClient>());
  late int year = JalaliDate.fromDateTime(DateTime.now()).year;
  late DateTime start = parseJalaliDate('$year/01/01')!;
  FiscalYearInfo? saved;
  bool loading = true, saving = false, expanded = true, needsReload = false;
  String? error;
  late final bootstrapRepository =
      FirstOfficeBootstrapRepository(context.read<FrappeApiClient>());
  FirstOfficeBootstrapStatus? bootstrap;
  bool hrLoading = true, hrBusy = false, hrNeedsReload = false;
  String? hrError;
  bool hrDeferred = false;
  static const canvas = Color(0xfff6f8fc);
  static const ink = Color(0xff203650);

  DateTime? get end {
    final date = JalaliDate.fromDateTime(start);
    final next = parseJalaliDate('${date.year + 1}/${date.month}/${date.day}');
    return next == null
        ? null
        : DateTime.utc(next.year, next.month, next.day)
            .subtract(const Duration(days: 1));
  }

  String display(DateTime date) =>
      toPersianDigits(JalaliDate.fromDateTime(date).format());

  @override
  void initState() {
    super.initState();
    load();
    loadBootstrap();
  }

  Future<void> loadBootstrap() async {
    setState(() {
      hrLoading = true;
      hrError = null;
    });
    try {
      final result = await bootstrapRepository.status(widget.company);
      if (mounted) {
        setState(() {
          bootstrap = result;
          hrNeedsReload = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hrError = failureDetail(e);
          hrNeedsReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => hrLoading = false);
    }
  }

  Future<bool> createLead(String fullName, String username, String contact,
      String password) async {
    if (hrBusy || hrLoading || hrNeedsReload || saved == null) return false;
    setState(() {
      hrBusy = true;
      hrError = null;
    });
    try {
      final result = await bootstrapRepository.create(
          company: widget.company,
          fullName: fullName,
          username: username,
          contact: contact,
          temporaryPassword: password);
      if (!mounted) return false;
      setState(() {
        bootstrap = result;
        hrDeferred = false;
        if (!result.hrReady) {
          hrError = 'حساب ثبت شده، اما دسترسی آن نیاز به بررسی مدیر سیستم دارد.';
        }
      });
      return result.fullName != null;
    } catch (e) {
      if (mounted) {
        setState(() {
          hrError = failureDetail(e);
          hrNeedsReload = !(e is ApiException &&
              e.kind == ApiFailureKind.validation && e.statusCode == 417);
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => hrBusy = false);
    }
  }

  Future<void> finish() async {
    if (loading || saving || hrBusy ||
        hrLoading ||
        hrNeedsReload ||
        saved == null ||
        (bootstrap?.hrReady != true && !hrDeferred)) {
      return;
    }
    setState(() {
      hrBusy = true;
      hrError = null;
    });
    try {
      final result = await bootstrapRepository.complete(widget.company);
      if (!mounted) return;
      setState(() => bootstrap = result);
      if (!result.completed) {
        throw const FormatException('تأیید نهایی در سرور ثبت نشد.');
      }
      await Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (_) => const DashboardLandingPage()),
          (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          hrError = failureDetail(e);
          hrNeedsReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => hrBusy = false);
    }
  }

  Future<void> continueLater() async {
    final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('ادامه در ورود بعدی'),
                content: const Text(
                    'اطلاعات ثبت‌شده روی سرور باقی می‌ماند؛ اطلاعات ذخیره‌نشده و رمز واردشده پاک می‌شود. از حساب خارج می‌شوید؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ماندن')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('خروج و ادامه بعداً'))
                ]));
    if (leave == true && mounted) await signOutToLogin(context);
  }

  Widget reviewLine(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
            child: Text(value,
                style:
                    const TextStyle(color: ink, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                textAlign: TextAlign.end,
                style: const TextStyle(color: AsoudColors.muted))),
      ]));

  Widget reviewNotice(String title, String message, {bool success = false}) =>
      Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color:
                  success ? const Color(0xffedf9f5) : const Color(0xffeaf1ff),
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(success ? Icons.check_circle_outline : Icons.key_outlined,
                  size: 20,
                  color: success ? AsoudColors.success : AsoudColors.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: success
                              ? AsoudColors.success
                              : AsoudColors.primary)))
            ]),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 12, height: 1.6, color: AsoudColors.muted)),
          ]));

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await repository.getFiscalYears(widget.company);
      if (!mounted) return;
      final active = rows.where((r) => !r.disabled).firstOrNull;
      final savedStart =
          active == null ? null : DateTime.tryParse(active.startDate);
      final savedEnd =
          active == null ? null : DateTime.tryParse(active.endDate);
      if (active != null &&
          (savedStart == null ||
              savedEnd == null ||
              savedEnd.isBefore(savedStart))) {
        throw const FormatException('تاریخ سال مالی دریافتی معتبر نیست.');
      }
      setState(() {
        saved = active;
        needsReload = false;
        if (active != null) {
          start = savedStart!;
          year = JalaliDate.fromDateTime(start).year;
          expanded = false;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = failureMessage(e);
          needsReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (saving || loading || saved != null || needsReload) return;
    if (end == null || JalaliDate.fromDateTime(start).year != year) {
      setState(() => error =
          'تاریخ شروع باید در سال انتخاب‌شده و دوره مالی یک‌ساله معتبر باشد.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final date = JalaliDate.fromDateTime(start);
      await repository.createFiscalYear(
          widget.company, year, date.month, date.day);
      if (!mounted) return;
      setState(() => needsReload = true);
      await load();
      if (mounted && saved == null && error == null) {
        setState(() => error =
            'سال مالی فعال در سرور تأیید نشد؛ وضعیت را دوباره دریافت کنید.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = failureMessage(e);
          needsReload = true;
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickStart() async {
    final value = await showAsoudJalaliPicker(context,
        initialDate: start, title: 'تاریخ شروع سال مالی');
    if (value == null || !mounted) return;
    final date = JalaliDate.fromDateTime(value);
    if (date.year != year) {
      setState(
          () => error = 'تاریخ شروع را در سال مالی انتخاب‌شده تعیین کنید.');
      return;
    }
    setState(() {
      start = value;
      error = null;
    });
  }

  Widget card(List<Widget> children, {bool selected = false}) => Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: selected ? const Color(0xff83aaff) : AsoudColors.border)),
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)));

  Widget heading(String title, String subtitle, IconData icon,
          {bool completed = false, Color color = AsoudColors.primary}) =>
      Row(children: [
        AsoudIconBox(icon: icon, color: color, size: 46),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 10, color: AsoudColors.muted)),
        ])),
        const SizedBox(width: 6),
        Icon(
            completed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 18,
            color: completed ? AsoudColors.success : AsoudColors.muted),
      ]);

  @override
  Widget build(BuildContext context) {
    final busy = loading || saving || hrBusy;
    final completed = bootstrap?.completed == true
        ? 3
        : saved == null
            ? 0
            : bootstrap?.hrReady == true || hrDeferred ? 2 : 1;
    final last = saved == null ? end : DateTime.tryParse(saved!.endDate);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
            canPop: !busy,
            child: Scaffold(
              backgroundColor: canvas,
              body: SafeArea(
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  const AsoudIconBox(
                      icon: Icons.tune_rounded,
                      color: AsoudColors.primary,
                      size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('راه‌اندازی دفتر کار',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: ink)),
                        const Text('تنظیمات اولیه مدیر سیستم',
                            style: TextStyle(
                                color: AsoudColors.muted, fontSize: 12)),
                        Text(widget.company,
                            style: const TextStyle(
                                color: AsoudColors.muted, fontSize: 10)),
                      ])),
                ]),
                const SizedBox(height: 16),
                card([
                  heading(
                      'دفتر کار ایجاد شده است',
                      'اکنون تنظیمات راه‌اندازی را تکمیل کنید.',
                      Icons.check_circle_outline,
                      completed: true,
                      color: AsoudColors.success),
                  const Divider(height: 32),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${toPersianDigits((completed * 100 / 3).round())}٪',
                            style: const TextStyle(
                                color: AsoudColors.primary,
                                fontWeight: FontWeight.bold)),
                        const Flexible(
                          child: Text(
                            'پیشرفت راه‌اندازی',
                            style: TextStyle(color: ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                          child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                  end: i < 2 ? 6 : 0),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                      value: i < completed ? 1 : 0,
                                      minHeight: 7,
                                      color: AsoudColors.primary,
                                      backgroundColor:
                                          const Color(0xffe6edfa)))))
                  ]),
                ]),
                card([
                  InkWell(
                      onTap: busy
                          ? null
                          : () => setState(() => expanded = !expanded),
                      child: heading(
                          '۱. تنظیمات سال مالی',
                          'سال مالی و تاریخ شروع و پایان',
                          Icons.account_balance_outlined,
                          completed: saved != null)),
                  if (busy)
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator()),
                  if (error != null) ...[
                    Text(error!,
                        style: const TextStyle(color: AsoudColors.danger)),
                    TextButton(
                        onPressed: busy ? null : load,
                        child: const Text('دریافت دوباره وضعیت')),
                  ],
                  if (expanded) ...[
                    const Divider(height: 32),
                    const Text('۱. سال مالی',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: ink)),
                    const SizedBox(height: 18),
                    AppSelectField(
                        label: 'سال مالی',
                        rounded: true,
                        required: true,
                        value: '$year',
                        displayValue: toPersianDigits(year),
                        enabled: !busy && saved == null,
                        onPick: () => showAppOptionSheet(context,
                                title: 'انتخاب سال مالی',
                                current: '$year',
                                options: [
                                  for (var y = 1300; y <= 1500; y++)
                                    AppOption('$y', toPersianDigits(y))
                                ]),
                        onChanged: (v) => setState(() {
                              year = int.parse(v);
                              start = parseJalaliDate('$year/01/01')!;
                              error = null;
                            })),
                    const SizedBox(height: 14),
                    AppSelectField(
                        label: 'تاریخ شروع سال مالی',
                        rounded: true,
                        value: start.toIso8601String(),
                        suffixIcon: const SizedBox.shrink(),
                        required: true,
                        displayValue: display(start),
                        enabled: !busy && saved == null,
                        onPick: () async {
                          await pickStart();
                          return null;
                        }),
                    const SizedBox(height: 14),
                    AppSelectField(
                        label: 'تاریخ پایان سال مالی',
                        rounded: true,
                        value: last?.toIso8601String() ?? 'invalid',
                        suffixIcon: const SizedBox.shrink(),
                        required: true,
                        displayValue: last == null
                            ? 'تاریخ شروع را اصلاح کنید'
                            : display(last),
                        enabled: false,
                        helperText:
                            'پایان دورهٔ یک‌ساله خودکار محاسبه می‌شود.'),
                    const SizedBox(height: 14),
                    const Text('ⓘ تاریخ‌ها بر اساس تقویم هجری شمسی هستند.',
                        style:
                            TextStyle(color: AsoudColors.muted, fontSize: 12)),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed:
                            busy || saved != null || needsReload ? null : save,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff111111),
                            minimumSize: const Size.fromHeight(44),
                            shape: const StadiumBorder()),
                        child: Text(saving
                            ? 'در حال ذخیره…'
                            : saved != null
                                ? 'سال مالی ثبت شده است'
                                : 'ذخیره و ادامه  ←')),
                  ],
                ], selected: expanded),
                card([
                  heading('۲. معرفی اولین مسئول منابع انسانی',
                      'ایجاد حساب اولیه مسئول منابع انسانی', Icons.people_outline,
                      completed: bootstrap?.hrReady == true,
                      color: AsoudColors.success),
                  if (hrLoading)
                    const Padding(padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator()),
                  if (hrError != null) ...[
                    const SizedBox(height: 12),
                    Text(hrError!, style: const TextStyle(color: AsoudColors.danger)),
                    TextButton(onPressed: busy || hrLoading ? null : loadBootstrap,
                        child: const Text('دریافت دوباره وضعیت راه‌اندازی')),
                  ],
                  if (saved == null)
                    const Text('ابتدا سال مالی را ثبت کنید.'),
                  if (saved != null && bootstrap != null &&
                      bootstrap!.fullName == null)
                    FirstHrLeadForm(
                        busy: hrBusy,
                        enabled: !loading && !saving && !hrLoading && !hrNeedsReload,
                        onSubmit: createLead),
                  if (bootstrap?.fullName != null)
                    reviewLine('مسئول منابع انسانی', bootstrap!.fullName!),
                  if (saved != null && bootstrap != null)
                    TextButton(
                        onPressed: busy || hrLoading || hrNeedsReload ? null
                            : () => setState(() => hrDeferred = true),
                        child: const Text('بعداً؛ ادامه به بررسی نهایی')),
                ], selected: saved != null && bootstrap?.hrReady != true),
                card([
                  heading('۳. بررسی نهایی', 'کنترل تنظیمات و ورود به آسود',
                      Icons.assignment_turned_in_outlined,
                      completed: bootstrap?.completed == true,
                      color: AsoudColors.warning),
                  if (saved == null ||
                      (bootstrap?.hrReady != true && !hrDeferred))
                    const Text('پس از ثبت سال مالی، مسئول منابع انسانی را معرفی کنید یا «بعداً» را انتخاب کنید.'),
                  if (saved != null &&
                      (bootstrap?.hrReady == true || hrDeferred)) ...[
                    const Divider(height: 32),
                    Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xfff7f9fc),
                            borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          reviewLine('سال مالی', toPersianDigits(saved!.year)),
                          reviewLine('تاریخ شروع', display(start)),
                          reviewLine('تاریخ پایان',
                              last == null ? '—' : display(last)),
                          if (bootstrap?.fullName != null)
                            reviewLine('مسئول منابع انسانی', bootstrap!.fullName!),
                        ])),
                    reviewNotice('مراحل اولیه آمادهٔ تأیید هستند',
                        'سال مالی ثبت شده است. معرفی مسئول منابع انسانی در این مرحله الزامی نیست؛ کاربران، نقش‌ها، ساختار سازمانی و گردش کار بعد از ورود به خانهٔ آسود تنظیم می‌شوند.',
                        success: true),
                    const SizedBox(height: 14),
                    FilledButton(
                        onPressed:
                            busy || hrLoading || hrNeedsReload ? null : finish,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff111111),
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder()),
                        child: Text(hrBusy
                            ? 'در حال انتقال…'
                            : 'تأیید نهایی و ورود به خانه  ←')),
                    const SizedBox(height: 10),
                    const Text(
                        'با ورود به خانه، مراحل اولیهٔ راه‌اندازی دفتر در سرور نهایی می‌شود.',
                        style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                        onPressed: busy || hrLoading || hrNeedsReload ? null : finish,
                        child: const Text('ثبت تأیید نهایی در سرور و ورود به خانه')),
                  ],
                ], selected: saved != null),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xffeaf1ff),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ⓘ ادامه تنظیمات در آسود',
                              style: TextStyle(
                                  color: AsoudColors.primary,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          Text(
                              'تعریف سایر نقش‌ها و کاربران، ساختار سازمانی، انواع درخواست‌ها و گردش کار جزو مراحل اجباری راه‌اندازی نیستند.',
                              style: TextStyle(
                                  color: AsoudColors.muted, fontSize: 12)),
                        ])),
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: busy ? null : continueLater,
                    style:
                        OutlinedButton.styleFrom(shape: const StadiumBorder()),
                    child: const Text('بعداً ادامه می‌دهم')),
              ])),
            )));
  }
}
