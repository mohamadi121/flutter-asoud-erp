import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../auth/domain/identity_validators.dart';

/// Controllers belong to this form, are never persisted, and are cleared after
/// server acknowledgement. Personnel information is intentionally absent.
class FirstHrLeadForm extends StatefulWidget {
  const FirstHrLeadForm(
      {required this.busy, required this.onSubmit, this.enabled = true, super.key});
  final bool busy;
  final bool enabled;
  final Future<bool> Function(
          String fullName, String username, String contact, String password)
      onSubmit;

  @override
  State<FirstHrLeadForm> createState() => _FirstHrLeadFormState();
}

class _FirstHrLeadFormState extends State<FirstHrLeadForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), username = TextEditingController();
  final contact = TextEditingController(), password = TextEditingController();
  bool hidden = true;
  bool get disabled => widget.busy || !widget.enabled;

  @override
  void dispose() {
    for (final controller in [name, username, contact, password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (disabled || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final accepted = await widget.onSubmit(
        name.text.trim(),
        username.text.trim().toLowerCase(),
        contact.text.contains('@')
            ? contact.text.trim()
            : IdentityValidators.normalizeMobile(contact.text)!,
        password.text);
    if (mounted && accepted) password.clear();
  }

  Widget notice(String title, String message, Color color, Color background,
          IconData icon) =>
      Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: background, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold)))
            ]),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(fontSize: 12, height: 1.7, color: color)),
          ]));

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(height: 32),
        notice(
            'حساب مدیر سیستم از قبل وجود دارد',
            'در این مرحله فقط اولین مسئول منابع انسانی معرفی می‌شود؛ نیازی به تعریف سایر نقش‌ها و کاربران نیست.',
            const Color(0xff25816f),
            const Color(0xffedf9f5),
            Icons.verified_user_outlined),
        const SizedBox(height: 12),
        const Row(children: [
          AsoudIconBox(
              icon: Icons.person_add_alt, color: AsoudColors.success, size: 36),
          SizedBox(width: 8),
          Expanded(
              child: Text('اطلاعات مسئول منابع انسانی',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xff203650))))
        ]),
        const SizedBox(height: 16),
        AppTextField(
            controller: name,
            label: 'نام و نام خانوادگی',
            required: true,
            rounded: true,
            enabled: !disabled,
            hintLocales: const [Locale('fa')],
            textInputAction: TextInputAction.next,
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'نام و نام خانوادگی را وارد کنید.';
              if (text.length > 60 ||
                  RegExp(r'[<>{}\[\]\\/@#$%^*=+|~`0-9۰-۹٠-٩]').hasMatch(text)) {
                return 'نام و نام خانوادگی معتبر وارد کنید.';
              }
              return null;
            }),
        const SizedBox(height: 16),
        AppTextField(
            controller: username,
            label: 'نام کاربری',
            required: true,
            rounded: true,
            enabled: !disabled,
            ltr: true,
            hintLocales: const [Locale('en')],
            textInputAction: TextInputAction.next,
            helperText: '۳ تا ۴۰ حرف انگلیسی، عدد یا زیرخط؛ شروع با حرف',
            validator: (v) {
              final text = (v ?? '').trim().toLowerCase();
              return RegExp(r'^[a-z][a-z0-9_]{2,39}$').hasMatch(text) &&
                      !['admin', 'administrator', 'guest'].contains(text)
                  ? null
                  : 'نام کاربری معتبر و غیرسیستمی وارد کنید.';
            }),
        const SizedBox(height: 16),
        AppTextField(
            controller: contact,
            label: 'شماره موبایل یا ایمیل',
            required: true,
            rounded: true,
            enabled: !disabled,
            ltr: true,
            keyboardType: TextInputType.emailAddress,
            hintLocales: const [Locale('en')],
            textInputAction: TextInputAction.next,
            helperText: 'یکی کافی است؛ ایمیل الزامی نیست.',
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'شماره موبایل یا ایمیل را وارد کنید.';
              if (text.contains('@')) {
                return text.length <= 140 &&
                        RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$')
                            .hasMatch(text) &&
                        !text.toLowerCase().endsWith('@users.asoud.invalid')
                    ? null
                    : 'ایمیل معتبر وارد کنید.';
              }
              return IdentityValidators.mobile(text);
            }),
        const SizedBox(height: 16),
        AppTextField(
            controller: password,
            label: 'رمز عبور موقت',
            required: true,
            rounded: true,
            enabled: !disabled,
            ltr: true,
            obscureText: hidden,
            hint: 'حداقل ۸ کاراکتر',
            keyboardType: TextInputType.visiblePassword,
            hintLocales: const [Locale('en')],
            suffixIcon: IconButton(
                tooltip: hidden ? 'نمایش رمز' : 'پنهان کردن رمز',
                onPressed:
                    disabled ? null : () => setState(() => hidden = !hidden),
                icon: Icon(hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined)),
            validator: (v) =>
                (v ?? '').runes.length >= 8 && (v ?? '').runes.length <= 128
                    ? null
                    : 'رمز موقت باید بین ۸ تا ۱۲۸ کاراکتر باشد.'),
        const SizedBox(height: 8),
        notice(
            'نقش: مسئول منابع انسانی',
            'دسترسی مدیریت منابع انسانی برای این دفتر اختصاص داده می‌شود. تکمیل پروندهٔ پرسنلی و تنظیم سایر نقش‌ها بعداً انجام می‌شود.',
            const Color(0xff7552b5),
            const Color(0xfff4efff),
            Icons.verified_user_outlined),
        notice(
            'فعال‌سازی حساب',
            'ورود با نام کاربری و رمز موقت است. رمز را امن و مستقیم تحویل دهید؛ تا ۷۲ ساعت معتبر است و در اولین ورود باید تغییر کند. در این مرحله پیامک یا ایمیل ارسال نمی‌شود.',
            const Color(0xff4d70a3),
            const Color(0xfff3f7fd),
            Icons.key_outlined),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: disabled ? null : submit,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff111111),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder()),
            child: Text(widget.busy
                ? 'در حال ثبت…'
                : 'ثبت مسئول منابع انسانی و ادامه  ←')),
      ]));
}
