import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';

/// This screen remains visible before deployment, but intentionally prevents
/// both demo and real authentication until ERPNext is available.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: AsoudIconBox(
                          icon: Icons.account_balance_rounded,
                          color: AsoudColors.primary,
                          size: 54),
                    ),
                    const SizedBox(height: 28),
                    const Text('خوش آمدید',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: AsoudColors.text)),
                    const SizedBox(height: 7),
                    const Text(
                        'ورود به حساب کاربری پس از آماده‌شدن سرور ERPNext فعال می‌شود.',
                        style:
                            TextStyle(fontSize: 11, color: AsoudColors.muted)),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _username,
                      enabled: false,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'نام کاربری یا ایمیل',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      enabled: false,
                      obscureText: _obscurePassword,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'رمز عبور',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'نمایش رمز عبور'
                              : 'پنهان‌کردن رمز عبور',
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _LoginUnavailable(),
                    const SizedBox(height: 22),
                    const SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: null,
                        child: Text('ورود تا آماده‌شدن سرور غیرفعال است'),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      );
}

class _LoginUnavailable extends StatelessWidget {
  const _LoginUnavailable();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AsoudColors.warning.withValues(alpha: .08),
          border: Border.all(color: AsoudColors.warning.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(children: [
          Icon(Icons.cloud_off_rounded, color: AsoudColors.warning, size: 19),
          SizedBox(width: 8),
          Expanded(
            child: Text(
                'سرور ERPNext هنوز برای اتصال آماده نیست؛ ورود عمداً غیرفعال است.',
                style: TextStyle(fontSize: 9)),
          ),
        ]),
      );
}
